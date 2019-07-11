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
prefix = 'automatedRun/1024/';
%prefix = 'debug/';
%prefix = 'recreation/';
%prefix = 'J_str/';
%prefix = 'PBCvsFBC/';
%prefix = 'solventDistribution/';
%prefix = 'topView/';
%prefix = 'topView-Emilio/';

% Hardcode folder (mostly for debugging).
%folder = 'lambda_4-L_256-J_0.0000_1.0000_0.0000-numIters_2-22-initialDist_80_10_10-FBC';

% Declare global variables
global lambda L directory f export skipFrames skipFramesOverride

% Some settings for file exporting.
export = true; f = 'png'; %Turns on the frame export of type 'f' - supports pdf, png or gif!

% Various settings related to the visualisation of the data.
skipFrames = 1; skipFramesOverride = true; %The number of .dat files to skip (and thus also the number of data points).
fontSize = 18; % 14 for 0.5\linewidth; 21 for 0.33\linewidth (for 1:1 scale - try 18 if it's too large)

% Run the folder selector if necessary and extract the parameters from the directory name.
if exist('folder') == 0
    folder = listDirs(prefix);
end
directory = [prefix folder];
[lambda, L, numIters] = findParamaters(directory,0);

% Run the preChecks function which does some initial debugging.
preChecks;

% Query the folder to determine the number of .dat files.
a = dir([directory '/*.dat']); b = numel(a); clc;

for n = 1:skipFrames:b
    % Import the raw data.
    frame = importdata([directory '/frame-' num2str(n) '.dat']);
    
    % These quantities are the concentration of zeros (for the whole lattice) and the number of MCS.
    c0(n) = 1 - nnz(frame)/numel(frame); MCS(n) = numIters*(n-1)/(size(frame,1)*size(frame,2));
    
    % Provide basic feedback to the user
    if mod(n,10) == 0 || n == 1
        clc; fprintf(['Percentage complete: ' num2str(round((n/b)*100,0)) '%%\n'])
    end
end

%% Plotting
clc; clf; fprintf('Plotting...\n')
cutoff = 0;
%cutoff = 70;
%cutoff = 200;

fun = fit(MCS(cutoff+1:end)',c0(cutoff+1:end)','exp1'); coeffs = coeffvalues(fun);
if cutoff > 0
    fun2 = fit(MCS(1:cutoff+1)',c0(1:cutoff+1)','exp2'); coeffs2 = coeffvalues(fun2);
    X2 = [min(MCS(1:cutoff+1)):0.01:max(MCS(1:cutoff+1))]';
end
X = [min(MCS):0.01:max(MCS)]';
 
syms x
%eqn = coeffs(1)*x + coeffs(2) == 0;
%eqn = coeffs(1)*exp(coeffs(2)*x) + coeffs(3)*exp(coeffs(4)*x) == 0;
eqn = coeffs(1)*exp(coeffs(2)*x) == 0.001;
solx = vpasolve(eqn,x);
%X = [min(MCS):0.01:double(solx)]';

set(gca,'FontSize',fontSize)
%grid on
hold on
if cutoff > 0
    plot(MCS(cutoff:end),c0(cutoff:end),'.k', 'MarkerSize',20)
    plot(MCS(1:cutoff+1),c0(1:cutoff+1),'.', 'MarkerSize',20, 'Color', [0 0 0] + 0.70)
else
    plot(MCS,c0,'.k', 'MarkerSize',20)
end
ws = warning('off','all');  % Turn off warnings.
%plot(X,fun(X),'-m')
if cutoff > 0
    plot(X2,fun2(X2),'-b')
end
warning(ws)  % Turn them back on.
hold off

% Cosmetic plot stuff.
ylabel('$c_0$')
xlabel('MCS')
ylim([0 max(c0)])
xlim([min(MCS) max(X)])

if cutoff > 0
    legend('Data points', 'Excluded data points', 'Linear regression', 'Exponential fit', 'Location','northeast')
else
    legend('Data points', 'Exponential fit', 'Location','northeast')
end

if export ~= true
    set(gcf,'Units','pixels');
    set(gcf,'Position', [0 0 550 400])
    set(gcf,'color','w');
    tightfig;
else
    set(gcf,'Units','pixels');
    set(gcf,'Position', [0 0 550 400])
    set(gcf,'color','w');
    tightfig;
    fig = gcf;
    filename = [directory '-c0vsMCS.' f];
    
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

%% Functions
% This function does some initial debugging to catch any obvious mistakes, such as the directory being empty.
function preChecks
    global directory f export skipFrames skipFramesOverride
    a = dir([directory '/*.dat']);
    b = numel(a);
    if b == 0
        error('Empty directory...\nAborting!',class(b)) %Throws an error and aborts. Note that the class(b) is necessary for MATLAB to parse the /n for.. reasons.
    end
    fprintf(['\nThe number of .dat files in the directory is ' num2str(b) '.\n'])

    % Set initial conditionals for the main loop.
    if export == true
        if skipFrames ~= 1 && skipFramesOverride ~= true
            fprintf('\n')
            warning('skipFrames has been set to 1.',class(a))
            skipFrames = 1;
        elseif skipFrames ~= 1 && skipFramesOverride == true
            fprintf('\n')
            warning('Inadvisable setting: skipFrames ~= 1.\nConsider setting skipFramesOverride to false.',class(a))
        end
        fprintf('\n')
        warning(['Will export frames as .' f '.'],class(a))
    else
        fprintf('\nWill NOT export frames.\n');
    end
    fprintf(['\nAll of the pre-checks passed!\n'])
    x = input('\nIs this correct? (y/n) ', 's');
    if x == 'y'

    elseif x == 'n'
        error('Please adjust settings accordingly...\nAborting!',class(x))
    else
        error('Invalid input...\nAborting!',class(x))
    end
end