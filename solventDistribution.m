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
%prefix = 'recreation/';
%prefix = 'J_str/';
%prefix = 'PBCvsFBC/';
%prefix = 'solventDistribution/';
%prefix = 'topView/';

% Hardcode folder (mostly for debugging).
%folder = 'lambda_4-L_256-J_0.0000_1.0000_0.0000-numIters_2-22-initialDist_80_10_10-FBC';

% Declare global variables
global lambda L numIters f directory frame lateralView fontSize allSpecies timeDep polDeg evapFront n export MCSTemp pauseTime saveMat x0Name fileExistsx0 skipFrames b

% Various settings related to the visualisation of the data.
skipFrames = 1; %The number of .dat files to skip for each frame rendered in MATALB.
evapFront = 0.25; %The 'arbitrary' critical concentration.
polDeg = 5; %The polynomial degree of the interpolation
lateralView = false; %Concentration per column, rather than per row. Not super useful, but it's here.
allSpecies = false; %Shows all of the species.
timeDep = true; saveMat = true; %Shows the time dependence after completion (and exports if export = true); the saveMat boolean controls the exporting of the j_demix data to a matrix.
fontSize = 18; % 18 for 0.5\linewidth; 24 for 0.33\linewidth (for 1:1 scale - try 18 if it's too large)

% Some settings for file exporting.
export = false; f = 'pdf'; %Turns on the frame export of type 'f' - supports pdf, png or gif!
pauseTime = 0.2; %The time between each frame in the GIF.

% Run the folder selector if necessary and extract the parameters from the directory name.
if exist('folder') == 0
    folder = listDirs(prefix);
end
directory = [prefix folder];
[lambda, L, numIters] = findParamaters(directory,0);

% Runs some pre-checks to catch any obvious mistakes.
preChecks

% Query the folder to determine the number of .dat files and provide some basic feedback to the user.
a = dir([directory '/*.dat']); b = numel(a); clc;
% Pre-allocate variables.
x0Exp = zeros(1, b); MCSExp = zeros(1, b);
fprintf(['Starting the main loop...\nThe number of .dat files in the directory is ' num2str(b) '.\n'])

for n = 1:skipFrames:b
    frame = importdata([directory '/frame-' num2str(n) '.dat']);
    MCSTemp = numIters*(n-1)/(size(frame,1)*size(frame,2));
    
    % First we need to find the concentrations per row (or column) of the cells.
    calcConc;
    
    % Next we interpolate the data and determine if there exists a root near the critical concentration.
    [x0ExpTemp, MCSExpTemp] = findRoots; x0Exp(n) = x0ExpTemp; MCSExp(n) = MCSExpTemp;
    
    % Now we plot the data.
    generatePlot; setDimensions
    pause(0.0333); % Adds a pause for the slow-ass interface to update properly.
    
    % Export the frame as png, pdf or gif.
    if export == true
        exportFrame
    end
end

% Adds the final frame the the GIF and provides some feedback to the user.
if export == true
    clc; fprintf('Done exporting!\n')
    if sum(f == 'gif') == 3
        exportFrame
    end
end

% Saves the j_demix matrix to a .mat file.
if timeDep == true && saveMat == true && fileExistsx0 ~= 2
    save(x0Name,'x0Exp','MCSExp');
end

%% Functions
% This function does some initial debugging to catch any obvious mistakes, such as the directory being empty.
function preChecks
    global directory f export fileExistsx0 timeDep saveMat x0Name skipFrames current allSpecies
    a = dir([directory '/*.dat']);
    b = numel(a);
    x0Name = [directory '-x0.mat'];
    fileExistsx0 = exist(x0Name, 'file');
    if b == 0
        error('Empty directory...\nAborting!',class(b)) %Throws an error and aborts. Note that the class(b) is necessary for MATLAB to parse the /n for.. reasons.
    end
    fprintf(['\nThe number of .dat files in the directory is ' num2str(b) '.\n'])
    
    current = 1; %Maximum value to export.
    
    % Check compatibality of settings.
    if allSpecies == true && timeDep == true
        allSpecies = false;
        fprintf('\n')
        error('Incompatible settings: allSpecies & timeDep cannot both be true.',class(a))
    end

    % Check if the .mat file exists and warn the user if it does.
    if timeDep == true && saveMat == true
        if fileExistsx0 == 2
            fprintf('\n')
            warning('The .mat file already exists. It will NOT be overwritten!',class(a))
        else
            if skipFrames ~= 1
                fprintf('\n')
                warning('skipFrames has been set to 1.',class(a))
                skipFrames = 1;
            end
            fprintf('\n')
            warning('Will export j_demix as a .mat file.',class(a))
        end
    else
        fprintf('\nWill NOT export j_demix.\n');
    end

    % Final confirmation.
    if export == true
        if skipFrames ~= 1
            fprintf('\n')
            warning('skipFrames has been set to 1.',class(a))
            skipFrames = 1;
        end
        fprintf('\n')
        warning(['Will export frames as .' f '.'],class(a))
    else
        fprintf('\nWill NOT export frames.\n');
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

% This function calculates the concentration per row (or column) of the cells.
function calcConc
    global lambda frame lateralView c0 c1 c2
    k = 1; %Reset counter every iteration.
    if lateralView == false
        for i = 1:lambda:size(frame,1)
            cTemp = 0;cTemp1 = 0;cTemp2 = 0;
            for x1 = i:1:i+lambda-1
                cTemp = cTemp + size(frame,1) - nnz(frame(x1,:));
                cTemp1 = cTemp1 + sum(frame(x1,:) == 1);
                cTemp2 = cTemp2 + sum(frame(x1,:) == -1);
            end
            cTemp = cTemp/(lambda^2 * size(frame,1)/lambda);
            cTemp1 = cTemp1/(lambda^2 * size(frame,1)/lambda);
            cTemp2 = cTemp2/(lambda^2 * size(frame,1)/lambda);
            c0(k) = cTemp;
            c1(k) = cTemp1;
            c2(k) = cTemp2;
            k = k+1;
        end
    else
        for j = 1:lambda:size(frame,2)
            cTemp = 0;cTemp1 = 0;cTemp2 = 0;
            for x2 = j:1:j+lambda-1
                cTemp = cTemp + size(frame,1) - nnz(frame(:,x2));
                cTemp1 = cTemp1 + sum(frame(:,x2) == 1);
                cTemp2 = cTemp2 + sum(frame(:,x2) == -1);
            end
            cTemp = cTemp/(lambda^2 * size(frame,1)/lambda);
            cTemp1 = cTemp1/(lambda^2 * size(frame,1)/lambda);
            cTemp2 = cTemp2/(lambda^2 * size(frame,1)/lambda);
            c0(k) = cTemp;
            c1(k) = cTemp1;
            c2(k) = cTemp2;
            k = k+1;
        end
    end
end

% This function finds and saves potential roots. If no root is found, the exported data is counted as a zero, which is later discarded in theanimation script.
function [x0ExpTemp, MCSExpTemp] = findRoots
    global frame lambda lateralView X F c0 polDeg evapFront rootExists x0 MCS numIters n
    
    if lateralView == false
        X = [1:1:size(frame,1)/lambda]';
        ws = warning('off','all');  %Turn off warnings
        F = polyfit(X,c0',polDeg); %Fit the data
        warning(ws)  %Turn them back on
        
        % Define the function to find a root for, and find said root.
        fun = @(x)polyval(F,x)-evapFront; rootExists = false;
        if fun(X(1)) < 0 && fun(X(end-1)) > 0
            x0(n) = fzero(fun,X([1,end-1])); rootExists = true; x0ExpTemp = x0(n);
            MCS(n) = numIters*(n-1)/(size(frame,1)*size(frame,2)); MCSExpTemp = MCS(n);
        elseif fun(X(end-1)) < 0 && fun(X(1)) > 0
            x0(n) = fzero(fun,X([1,end-1])); rootExists = true; x0ExpTemp = x0(n);
            MCS(n) = numIters*(n-1)/(size(frame,1)*size(frame,2)); MCSExpTemp = MCS(n);
        else
            x0ExpTemp = 0;
            MCSExpTemp = 0;
        end
    else
        X = [1:1:size(frame,2)/lambda]';
        ws = warning('off','all');  %Turn off warnings
        F = polyfit(X,c0',polDeg); %Fit the data
        warning(ws)  %Turn them back on
        
        % Define the function to find a root for, and find said root.
        fun = @(x)polyval(F,x)-evapFront; rootExists = false;
        if fun(X(1)) < 0 && fun(X(end-1)) > 0
            x0(n) = fzero(fun,X([1,end-1])); rootExists = true; x0ExpTemp = x0(n);
            MCS(n) = numIters*(n-1)/(size(frame,1)*size(frame,2)); MCSExpTemp = MCS(n);
        elseif fun(X(end-1)) < 0 && fun(X(1)) > 0
            x0(n) = fzero(fun,X([1,end-1])); rootExists = true; x0ExpTemp = x0(n);
            MCS(n) = numIters*(n-1)/(size(frame,1)*size(frame,2)); MCSExpTemp = MCS(n);
        else
            x0ExpTemp = 0;
            MCSExpTemp = 0;
        end
    end
end

% This function generates the plot based on the data.
function generatePlot
    global fontSize timeDep X lateralView F rootExists c0 c1 c2 x0 evapFront n frame lambda allSpecies

    clf; % Clear the figure.
    h1 = axes;
    set(gca,'FontSize',fontSize)
    hold on
    if timeDep == false
        if allSpecies == true
            plot(X,c2,'ok', 'MarkerSize',5)
            plot(X,c0,'.r', 'MarkerSize',20)
            plot(X,c1,'.k', 'MarkerSize',20)
        else
            plot(X,c0,'.r', 'MarkerSize',20)
        end
    else
        plot(X,c0,'.r', 'MarkerSize',20)
    end
    if timeDep == true
        if lateralView == false
            plot(X,polyval(F,X),'-k')
            if rootExists == true
                plot(x0(n),evapFront,'d', 'MarkerSize',10, 'MarkerEdgeColor','k', 'MarkerFaceColor','k')
                plot([x0(n) x0(n)],[0 evapFront], '--', 'Color', [0 0 0] + 0.5) % x = x0
                plot([0 x0(n)],[evapFront evapFront], '--', 'Color', [0 0 0] + 0.5) % y = evapFront
                plot(x0(n),evapFront,'d', 'MarkerSize',10, 'MarkerEdgeColor','k', 'MarkerFaceColor','k')
            end
        end
    end
    hold off
    
    % Cosmetic plot stuff.
    if lateralView == false
        xlabel('$j$')
    else
        xlabel('$i$')
    end
    if timeDep == false
        ylabel('Concentration')
        if allSpecies == true
            legend('$c_{-1}$','$c_{0}$','$c_{+1}$','Location','northwest')
        else
            legend('$c_{0}$','Location','northwest')
        end
    else
        ylabel('Concentration')
        legend('$c_{0}$','Polynomial fit','Location','northwest')
    end
    box on
    grid on
    
    xlim([1, size(frame,1)/lambda]);
    %ylim([0 1.0-kLim*n]);
    ylim([0 1.0]);
    xticks([0:size(c0,2)/8:size(c0,2)])
    yticks([0:1/5:1.0])
    %tightfig;
end

% This function sets the dimensions of the plot.
function setDimensions
    global fontSize c0 MCSTemp f export

    set(gcf,'Units','pixels');
    set(gcf,'Position', [0 0 550 400]*1.2)
    set(gcf,'color','w');
    set(gca,'FontSize',fontSize);
    if export == true && sum(f == 'pdf') == 3
        set(gcf,'Position', [0 0 550 400])
    else
        title(['Concentration of zeros = ' num2str(round(sum(c0)/size(c0,2),2)) '; MCS = ' num2str(round(MCSTemp,0))])
        %set(gca,'Position', [0.06 0.13 0.92 0.8])
    end
    tightfig;
end

% This function simply extract the frames as png, pdf or gif.
function exportFrame
    global c0 MCSTemp f directory pauseTime n b timeDep current allSpecies lateralView
    
    fig = gcf;
    if sum(f == 'gif') ~= 3
        for k = 1:9
            if sum(c0)/size(c0,2) < 0.1
                k = 0.1;
            end
            if round(sum(c0)/size(c0,2),2) == k/10 && k/10 < current || n == b || n == 1
                current = k/10;
                if timeDep == true
                    filename = sprintf([directory '_MCS_' num2str(round(MCSTemp,0)) '_c0_0%d-solventDistribution-timeDep.' f],str2num(strrep(num2str(round(sum(c0)/size(c0,2),2)),'.','')));
                elseif allSpecies == true
                    if lateralView == true
                        filename = sprintf([directory '_MCS_' num2str(round(MCSTemp,0)) '_c0_0%d-solventDistribution-lateralView-allSpecies.' f],str2num(strrep(num2str(round(sum(c0)/size(c0,2),2)),'.','')));
                    else
                        filename = sprintf([directory '_MCS_' num2str(round(MCSTemp,0)) '_c0_0%d-solventDistribution-allSpecies.' f],str2num(strrep(num2str(round(sum(c0)/size(c0,2),2)),'.','')));
                    end
                else
                    filename = sprintf([directory '_MCS_' num2str(round(MCSTemp,0)) '_c0_0%d-solventDistribution.' f],str2num(strrep(num2str(round(sum(c0)/size(c0,2),2)),'.','')));
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
        end
    else
        if timeDep == true
            filename = [directory '-solventDistribution-timeDep.gif'];
        else
            filename = [directory '-solventDistribution.gif'];
        end
        frame = getframe(fig);
        im = frame2im(frame);
        [imind,cm] = rgb2ind(im,256);
        if n == 1
            imwrite(imind,cm,filename,'gif', 'Loopcount',inf);
            imwrite(imind,cm,filename,'gif','WriteMode','append','DelayTime',2);
        elseif n == b
            imwrite(imind,cm,filename,'gif','WriteMode','append','DelayTime',5);
        else
            imwrite(imind,cm,filename,'gif','WriteMode','append','DelayTime',pauseTime);
        end
    end
end