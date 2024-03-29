clear; % Clears old variables.
clc; % Clears command window.
clf; % Clears figures.
%close all; % Closes any open windows.

%% LaTeX stuff.
set(groot, 'defaultAxesTickLabelInterpreter','latex');
set(groot, 'defaultTextInterpreter','latex');
set(groot, 'defaultLegendInterpreter','latex');

%prefix = '';
%prefix = 'automatedRun/1024/';
%prefix = 'debug/';
%prefix = 'J_str/';
%prefix = 'PBCvsFBC/';
%prefix = 'solventDistribution/';
prefix = 'topView/';

%folder = 'lambda_4-L_256-J_0.0000_1.0000_0.0000-numIters_2-22-initialDist_80_10_10-FBC';

cellVisualisation = true; cD = 16; %cD is the colour-depth (8 for 8 bit, 12 for 12 bit etc).
linInt = false; mag = 20; %Applies linear interpolation to the frames; mag is the magnification (e.g. 20 times).
gridOn = false; %will be disabled if linInt = true.

FourierTransform = false; %disables gridOn an shows the fft image.
FTMap = parula(2^cD);

f = 'pdf'; %pdf or png!
export = false; %Turns on the frame export! For GIF exporting, use exporGIF below. DO NOT USE BOTH!
gcaOnly = false;
exportGIF = false;
pauseTime = 0.1; %The time between each frame in the GIF.

sequence = false; %true for whole sequence (always true for exports).
once = false; %false for currently running simulations.

if exist('folder') == 0
    % Get a list of all files and folders in this folder.
    files = dir(prefix);
    % Get a logical vector that tells which is a directory.
    dirFlags = [files.isdir];
    % Extract only those that are directories and remove '.' and '..'.
    subFolders = files(dirFlags);
    for k = 1 : length(subFolders)
        x(k) = sum(subFolders(k).name ~= '.') ~= 0;
    end
    subFolders = subFolders(x~=0);
    % Determine maxmum lenght.
    leng = [];
    for k = 1 : length(subFolders)
        leng = [leng size(subFolders(k).name,2)];
    end
    maxLeng = max(leng);
    % Sort by date modified.
    x = [1:length(subFolders)];
    [sortedDates order] = sort([subFolders(x).datenum],'Descend');
    % Print folder names to command window.
    for k = 1 : length(subFolders)
        fprintf('Folder #%d = %s%s', k, subFolders(order(k)).name, blanks(maxLeng-leng(order(k))));
        fprintf(['\tModified = ', char(datetime(sortedDates(k),'ConvertFrom','datenum','Format','dd/MM'' ''HH'':''mm')),'\n'])
    end
    prompt='\nPlease select a folder...\n';
    x = input(prompt);
    folder = subFolders(order(x)).name;
    clc;
end
directory = [prefix folder];

cutoffConc = 0.1;
fitType = 'exp2';

ipos = strfind(directory,'lambda_') + strlength("lambda_");
iposLim = strfind(directory,'-L_') - 1;
lambda = str2num(directory(ipos:iposLim));

ipos = strfind(directory,'numIters_2-') + strlength("numIters_2-");
iposLim = strfind(directory,'-initialDist_') - 1;
exponent = str2num(directory(ipos:iposLim));
numIters = 2^exponent;

go = true; tempPause = true;
while go
    a = dir([directory '/*.dat']);
    T = struct2table(a);
    sortedT = sortrows(T, 'date');
    sortedA = table2struct(sortedT);
    b = numel(a);
    
    frame = importdata([directory '/frame-' num2str(1) '.dat']);
    
    cT = datetime(getfield(sortedA(b),'date'))-datetime(getfield(sortedA(1),'date'));
    currentTime = seconds(cT);
    
    clc;
    fprintf(['Number of frames:              ' num2str(b)])
    
    for n = 1:1:b
        frame = importdata([directory '/frame-' num2str(n) '.dat']);
        c0(n) = 1 - nnz(frame)/numel(frame);
        MCS(n) = numIters*(n-1)/(size(frame,1)*size(frame,2));
        if mod(n, 10) == 0 || n == 2
            if n + 1 <= b
                m = n;
            else
                m = n - 1;
            end
        end
    end
    
    %% Fitting section - ONLY RERUN THIS tO CHANGE FIT TYPE!
    clc;
    clf;
    fprintf(['Number of frames:              ' num2str(b)])
    fprintf(['\nNumber of MCS:               ' num2str(MCS(end))])
    
    f = fit(c0',MCS',fitType);
    
    percCompActual = 100*(cutoffConc/c0(end));
    percComp = 100*MCS(end)/f(cutoffConc);
    percCompCalc = 100*MCS(m+1)/f(cutoffConc);
    timeLeft = datestr((currentTime/percCompCalc)*(100-percCompCalc)/(24*60*60), 'HH:MM:SS');
    
    fprintf(['\nActual percentage complete:     ' num2str(round(percCompActual,0)) '%%\n'])
    
    if percCompCalc <= 100
        fprintf(['\nEstimated percentage complete:  ' num2str(round(percComp,0)) '%%'])
        fprintf(['\nEstimated time left:            ' timeLeft '\n'])
    end
    
    % Plotting
    %figure
    h1 = axes;
    %set(gca,'FontSize',12)
    hold on
    plot(c0,MCS,'.k')
    plot([cutoffConc:0.01:max(c0)],f([cutoffConc:0.01:max(c0)]),'-m')
    %plot(MCS,y,'.k')
    %plot(xp,f(xp),'-m')
    % plot([0 1.4],[42 42], '-.', 'Color', [0 0 0] + 0.5) % y = 25
    % plot([0 1.4],[17 17], '-.', 'Color', [0 0 0] + 0.5) % y = 140
    % plot([0.27 0.27],[0 160], '-.', 'Color', [0 0 0] + 0.5) % x = 0.27
    % plot([0.73 0.73],[0 160], '-.', 'Color', [0 0 0] + 0.5) % x = 0.75
    hold off
    set(h1, 'Xdir', 'reverse')
    
    % Cosmetic plot stuff.
    xlabel('Concentration')
    ylabel('MCS')
    %title('Line profiles')
    if percCompCalc <= 100
        title(['Estimated time left: ' num2str(timeLeft)])
    end
    legend('Data points','Fit','Location','northwest')
    box on
    
    xlim([cutoffConc, max(c0)]);
    ylim([0 inf]);
    %
    %xticks([29.66,50,65,80])
    %xticklabels({'30','50','65','80'})
    % yticks([0, 23, 143])
    %yticklabels({'0.4','0.6','0.8','1.0','1.2','1.4','1.6','1.8'})
    
    %Rotate ylabel, taking into account its size/centre relation.
    % ylh = get(gca,'ylabel');
    % gyl = get(ylh);
    % ylp = get(ylh, 'Position');
    % set(ylh, 'Rotation',0, 'Position',ylp, 'VerticalAlignment','middle', 'HorizontalAlignment','right');
    %tightfig;
    set(gcf,'Units','pixels');
    set(gcf,'Position', [0 0 550 400]*1.5)
    set(gcf,'color','w');
    %set(gca,'Position', [0 0 1 1])
    %pbaspect([1.5 1 1])
    tightfig;
    
    numPause = 0;
    while tempPause
        pause(60)
        a = dir([directory '*.dat']);
        if b < numel(a)
            break;
        end
        numPause = numPause + 1;
        if numPause >= 2
            go = false;
            break;
        end
    end
end