clear all; % Clears old variables.
clc; % Clears command window.
clf; % Clears figures.
%close all; % Closes any open windows.

%% LaTeX stuff.
set(groot, 'defaultAxesTickLabelInterpreter','latex');
set(groot, 'defaultTextInterpreter','latex');
set(groot, 'defaultLegendInterpreter','latex');

% Specify the 'prefix' folder, i.e. not the name generated by the Fortran program.
%prefix = '';
prefix = 'automatedRun/512/';
%prefix = 'debug/';
%prefix = 'J_str/';
%prefix = 'PBCvsFBC/';
%prefix = 'solventDistribution/';
%prefix = 'topView/';

% Declare global variables
global logLog fontSize export f allFiles folder

% Various settings related to the visualisation of the data.
allFiles = false;
logLog = true; %Shows the final graph on a loglog scale if true.
cutoff = 12; % The number of data points to exclude near the end.
cutoff = [15 30 30 40 30]; % The number of data points to exclude near the end in the allFiles case. Note that you need this vector to be the same length as the number of .mat files!
fontSize = 18; % 14 for 0.5\linewidth; 21 for 0.33\linewidth (for 1:1 scale - try 18 if it's too large)

% Some settings for file exporting.
export = false; f = 'pdf'; %Turns on the frame export of type 'f' - supports pdf or png!

% Run the folder selector if necessary and extract the parameters from the directory name.
if allFiles == false
    folder = listDirs(prefix);
    datFiles = [folder '-x0.mat']';
end

% Runs some pre-checks to catch any obvious mistakes.
preChecks

% Get a list of all of the .mat files in the directory.
if allFiles == true
    datFiles = listFiles(prefix);
end

% Loop over all of the .dat files and import the variables and add them to the plot.
clc; fprintf('Starting the main loop...\n')
for k = 1:size(datFiles,2)
    if allFiles == true
        currentFile = [prefix cell2mat(datFiles(k))];
    else
        currentFile = [prefix datFiles(:,k)'];
    end
    [x0, MCS] = load_x0(currentFile,2);
    [lambda, L] = findParamaters(currentFile,1);

    generatePlot(L, lambda, x0, MCS, cutoff(k), logLog, fontSize, allFiles, k, size(datFiles,2))
    setDimensions
end

% Export the final graph.
if export == true
   exportGraph(prefix)
end

%% Functions
% This function does some initial debugging to catch any obvious mistakes.
function preChecks
    global export f

    % Final confirmation.
    if export == true
        fprintf(['Will export graph as a .' f '.\n']);
    else
        fprintf('Will NOT export graph.\n');
    end
    fprintf('\nAll of the pre-checks passed!\n')
    x = input('\nIs this correct? (y/n) ', 's');
    if x == 'y'
        
    elseif x == 'n'
        error('Please adjust settings accordingly...\nAborting!',class(x))
    else
        error('Invalid input...\nAborting!',class(x))
    end
end

% This function lists all of the .mat files in a folder.
function relevantFiles = listFiles(temp)
    % Get a list of all files and folders in this folder.
    files = dir(temp);
    % Get a logical vector that tells which is a directory.
    dirFlags = [files.isdir];
    % Extract only those that are files.
    allFiles = files(dirFlags == 0);
    if size(allFiles,1) == 0
        error('There are no .mat files in that directory!\nPlease double-check the prefix and/or re-run solventDistribution.',class(files))
    end
    % Extract only the relevant (.mat) files.
    relevantFiles={};
    for k = 1:size(allFiles,1)
         if isempty(strfind(allFiles(k).name,'.mat')) == 0
             relevantFiles(end+1) = {allFiles(k).name};
         end
    end
    % Sort by name.
    relevantFiles = natsortfiles(relevantFiles);
end

% This function adds the current data to the plot.
function generatePlot(L, lambda, x0, MCS, cutoff, logLog, fontSize, allRuns, k, maxVal)
    global minX maxX minY maxY
    
    MCS = MCS(MCS~=0); x0 = x0(x0~=0); %Remove zeros.
    if logLog == false
        X = 0:0.1:MCS(end);
        fun = fit(MCS',x0','power1'); coeffs = coeffvalues(fun);

        % Plotting
        %figure
        set(gca,'FontSize',fontSize)
        hold on
        plot(MCS,x0,'.k', 'MarkerSize',20)
        ws = warning('off','all');  % Turn off warnings.
        plot(X,fun(X),'-m')
        warning(ws)  % Turn them back on.
        hold off

        % Cosmetic plot stuff.
        sf = ['Power law fit: $y = ' num2str(round(coeffs(1),2)) '\cdot x^{' num2str(round(coeffs(2),2)) '}$'];

        xlabel('MCS')
        ylabel('$j_{\textnormal{demix}}$')
        %title(['Concentration of zeros = ' num2str(round(sum(c0)/size(c0,2),2))])
        legend('Data points',sf,'Location','southeast')
        %legend('Data points','Exponential fit','Linear fit','Location','northwest')
        box on
        grid on

        xlim([0, max(MCS)]);
        ylim([1, size(frame,1)/lambda]);
        %yticks([0:size(c0,2)/4:size(c0,2)])
        xticks([0:max(MCS)/4:max(MCS)])
    else
        lMCS = log(MCS');
        lx0 = log(x0');
        fun = fit(lMCS(1:end-cutoff),lx0(1:end-cutoff),'poly1'); coeffs = coeffvalues(fun);
        if cutoff > 0
            fun2 = fit(lMCS(end-cutoff+1:end),lx0(end-cutoff+1:end),'poly1'); coeffs2 = coeffvalues(fun2);
            X2 = [min(lMCS(end-cutoff+1:end)):0.01:max(lMCS(end-cutoff+1:end))]';
        end
        X = [min(lMCS):0.01:max(lMCS)]';

        % Plotting
        set(gca,'FontSize',fontSize)
        hold on
        if allRuns == false
            if cutoff > 0
                plot(lMCS(1:end-cutoff),lx0(1:end-cutoff),'.k', 'MarkerSize',20)
                plot(lMCS(end-cutoff+1:end),lx0(end-cutoff+1:end),'.', 'MarkerSize',20, 'Color', [0 0 0] + 0.70)
            else
                plot(lMCS,lx0,'.k', 'MarkerSize',20)
            end
            ws = warning('off','all');  % Turn off warnings.
            plot(X,fun(X),'-m')
            if cutoff > 0
                plot(X2,fun2(X2),'-b')
            end
            warning(ws)  % Turn them back on.
        else
            plot(lMCS(1:end-cutoff),lx0(1:end-cutoff),'.', 'MarkerSize',20, 'Color', [0 0 0] + (1/maxVal)*(k-1), 'DisplayName',['$\lambda$ = ' num2str(lambda)]);
            plot(lMCS(end-cutoff+1:end),lx0(end-cutoff+1:end),'.', 'MarkerSize',20, 'Color', [0 0 1],'HandleVisibility','off');
            %plot(X,fun(X),'-m', 'DisplayName',['Fit: $y \propto x^{' num2str(round(coeffs(1),2)) '}$']);
            if cutoff > 0
                plot(X2,fun2(X2),'-g', 'DisplayName',['Fit: $y \propto x^{' num2str(round(coeffs2(1),2)) '}$']);
            end
            %plot(lMCS,lx0,'.', 'MarkerSize',20, 'Color', [0 0 0] + (1/maxVal)*(k-1), 'DisplayName',['$\lambda$ = ' num2str(lambda)]);
            if k == maxVal
                plot([0 2^10],0.5*[0 2^10]-0.57,'-m', 'DisplayName', 'Fickian: $y \propto x^{0.5}$')
            end
        end

        % Cosmetic plot stuff.
        sf = ['Fit: $y = ' num2str(round(exp(coeffs(2)),2)) '\cdot x^{' num2str(round(coeffs(1),2)) '}$'];

        if cutoff > 0
            sf2 = ['Fit: $y = ' num2str(round(exp(coeffs2(2)),2)) '\cdot x^{' num2str(round(coeffs2(1),2)) '}$'];
        end

        xlabel('MCS $[\ln]$')
        ylabel('$j_{\textnormal{demix}}$ $[\ln]$')
        %title(['Concentration of zeros = ' num2str(round(sum(c0)/size(c0,2),2))])
        if allRuns == false
            if cutoff > 0
                legend('Data points','Excluded data points', sf, sf2, 'Location','northwest')
            else
                legend('Data points',sf,'Location','northwest')
            end
        else
            legend('-DynamicLegend','Location','northwest')
        end
        box on

        if k == 1
            minX = min(lMCS); maxX = max(lMCS);
        else
            if min(lMCS) < minX
                minX = min(lMCS);
            end
            if max(lMCS) > maxX
                maxX = max(lMCS);
            end
        end
        if k == 1
            minY = min(lx0); maxY = max(lx0);
        else
            if min(lx0) < minY
                minY = min(lx0);
            end
            if max(lx0) > maxY
                maxY = max(lx0);
            end
        end
        
         xlim([minX, maxX]);
         ylim([minY, maxY]);
         xticks([]); yticks([]); yticklabels({}); xticklabels({});
    end
end

% This function sets the dimensions of the plot.
function setDimensions
    global fontSize export f

    set(gcf,'Units','pixels');
    if export == true && sum(f == 'pdf') == 3
        set(gcf,'Position', [0 0 550 400])
    else
        set(gcf,'Position', [0 0 550 400]*1.2)
    end
    set(gcf,'color','w');
    set(gca,'FontSize',fontSize);
    tightfig;
end

% This function exports the graph with the correct extension.
function exportGraph(prefix)
    global allFiles folder f

    fig = gcf;
    if allFiles == true
        filename = sprintf([prefix 'allFiles-timeDep.' f]);
    else
        filename = sprintf([prefix folder '-timeDep.' f]);
    end
    if sum(f == 'png') == 3
        frame = getframe(fig);
        im = frame2im(frame);
        [imind,cm] = rgb2ind(im,256);
        imwrite(imind,cm,filename,f);
    elseif sum(f == 'pdf') == 3
        set(fig,'Units','Inches');
        pos = get(fig,'Position');
        set(fig,'PaperPositionMode','Auto','PaperUnits','Inches','PaperSize',[pos(3), pos(4)])
        print(fig,filename,'-dpdf','-r0')
    end
end