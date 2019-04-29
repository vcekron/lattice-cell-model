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

% Hardcode folder (mostly for debugging).
%folder = 'lambda_4-L_256-J_0.0000_1.0000_0.0000-numIters_2-22-initialDist_80_10_10-FBC';

% Declare global variables
global lambda L cellVisualisation linInt numIters mag gridOn fontSize criticalRegion export f c0 MCS n b x0 frame directory pauseTime nSave locsSave

% Various settings related to the visualisation of the data.
cellVisualisation = true; cD = 16; %cD is the colour-depth (8 for 8 bit, 12 for 12 bit etc).
linInt = false; mag = 2; %Applies linear interpolation to the frames; mag is the magnification (e.g. 20 times).
gridOn = false; %Overlays a grid representing the cells. Will be automatically disabled if linInt = true.
skipFrames = 2; %The number of .dat files to skip for each frame rendered in MATALB.
fontSize = 18; %The fontsize used in the frames.

% Some Fourier transform settings.
FourierTransform = false; stretchCS = false; FTMap = jet(2^cD); %disables gridOn an shows the fft2 image; stretchCS applies a stretched colour-space of type FTMap;
radialDist = true; %Shows the radial distribution of the fft2 data.
criticalRegion = true; critUp = 0; critDown = 8; %If ciritcalRegion is combined with radialDist, it shows the line profile.. otherwise it overlays the image (if on its own) or shows the fft critical region (if combined with FourierTransform). The critical region is specified using critUp and critLow (in terms of # of cells).

% Some settings for file exporting.
export = false; f = 'png'; %Turns on the frame export of type 'f' - supports pdf, png or gif!
pauseTime = 0.1; %The time between each frame in the GIF.
height = 838; width = 800; %The dimensions in pixels of the png/GIF. Note that the height should be increased to account for the title text. The PDFs export with a (preprogrammed) small size for space-conserving reasons.

% And finally some settings for the MATLAB presentation.
sequence = true; %true for whole the sequence (with skipFrames taken into account). Note that this is always true for exports.
once = false; %false for currently running simulations. This is austomatically set to 'true' if the last frame is older than 20 minutes.

% Run the folder selector if necessary and extract the parameters from the directory name.
if exist('folder') == 0
    folder = listDirs(prefix);
end
directory = [prefix folder];
[lambda, L, numIters] = findParamaters(directory,0);

% Runs the preChecks function which does some initial debugging.
[once, x0, rawMap, lowLim, go, tempPause, k] = preChecks(sequence);

% Applies a stretch to the colour-space according to https://se.mathworks.com/matlabcentral/answers/307318-does-matlab-have-a-nonlinear-colormap-how-do-i-make-one.
if stretchCS == true
    FTMap = stretchSpace(FTMap);
end

% If all checks pass, start the main loop.
while go
    % Query the folder to determine the number of .dat files and provide some basic feedback to the user.
    a = dir([directory '/*.dat']); b = numel(a); clc; k = k + 1;
    if k == 1
        fprintf(['Starting the main loop...\nThe number of .dat files in the directory is ' num2str(b) '.\n'])
    else
        fprintf(['The number of .dat files in the directory is ' num2str(b) '.\n'])
    end
    
    % The main part of the script. This is responsible for updating the frame, exporting if necessary, etc.
    for n = lowLim:skipFrames:b
        frameUpdated = false; %Reset boolean each run.
        % Import the raw data and break (silently) if it is incorrectly formatted (which usually means that the Fortran script is too slow).
        frame = importdata([directory '/frame-' num2str(n) '.dat']);
        if(size(frame,1) ~= size(frame,2))
            break;
        end

        % These quantities are the concentration of zeros (for the whole lattice) and the number of MCS.
        c0 = 1 - nnz(frame)/numel(frame); MCS = numIters*(n-1)/(size(frame,1)*size(frame,2));
        
        % For the cellVisualisation, the RGB data per cell is calculated and interpolation is applied when appropriate.
        if cellVisualisation == true
            [diffRGB, solventRGB, downRGB, upRGB] = cellCalc(frame, cD); %The 'raw' RGB data for the cells.
            im = cellMerge(solventRGB, diffRGB); %The combined and corrected image data.
            if linInt == true
                imInt = cellInt(im, mag); %Linear interpolation is applied to the cell data.
            end
        end

        % Determine the critical region and save the rows.
        critRows = []; %Clear the critical region every run.
        if criticalRegion == true && x0(n) > 0
            temp = sort(unique([floor(x0(n))-critUp:floor(x0(n)) floor(x0(n)):floor(x0(n))+critDown])); temp = temp(temp>0); temp = temp(temp <= (L/lambda));
            if cellVisualisation == true
                if linInt == true
                    critRows = [(temp(1)-1)*mag+1:1:temp(end)*mag];
                else
                    critRows = [temp];
                end
            else
                critRows = [(temp(1)-1)*lambda+1:1:temp(end)*lambda];
            end
        elseif criticalRegion == false
            if cellVisualisation == true
                if linInt == true
                    critRows = [1:size(imInt,1)];
                else
                    critRows = [1:size(im,1)];
                end
            else
                critRows = [1:size(frame,1)];
            end
        end
        
        % Apply the Fourier transform as required. Here I use the same variables for the FT data, since there is no need to save both copies.
        if FourierTransform == true
            if size(critRows,1) > 0
                if cellVisualisation == true
                    if linInt == true
                        imFT = FTImage(imInt(critRows,:,:));
                    else
                        imFT = FTImage(im(critRows,:,:));
                    end
                else
                    rawFT = FTRaw(frame(critRows,:));
                end

                % Perform various calculations to determine the dominating peak. Also renders the frame since the requirements are different.
                if radialDist == true
                    if exist('imFT') == 1
                        frameUpdated = radialPeaks(imFT);
                    else
                        frameUpdated = radialPeaks(rawFT);
                    end
                end
            elseif radialDist == true
                setDimensionsPeaks
            end
        end

        % Renders the frames and sets the dimensions.
        if frameUpdated ~= true %&& size(critRows,1) > 0
            if cellVisualisation == true
                if exist('imFT') == 1
                    colormap(FTMap);
                    imagesc(imFT);
                    setDimensions(height, width, (size(imFT,1)/size(imFT,2)))
                elseif linInt == true
                    imagesc(imInt);
                    setDimensions(height, width, 1)
                    if x0(n) ~= 0
                        drawBox(critRows, size(imInt,2), mag)
                    end
                else
                    imagesc(im);
                    setDimensions(height, width, 1)
                    if x0(n) ~= 0
                        drawBox(critRows, size(im,2), 1)
                    end
                end
            else
                if exist('rawFT') == 1
                    colormap(FTMap);
                    imagesc(rawFT);
                    setDimensions(height, width, (size(rawFT,1)/size(rawFT,2)))
                else
                    colormap(rawMap);
                    imagesc(frame);
                    setDimensions(height, width, 1)
                    if x0(n) ~= 0
                        drawBox(critRows, size(frame,2), lambda)
                    end
                end
            end
            set(gca,'FontSize',fontSize); title(['Concentration of zeros = ' num2str(round(c0,2)) '; MCS = ' num2str(MCS)]);
            frameUpdated = true;
        elseif frameUpdated ~= true
            if export == true && sum(f == 'pdf') == 3
                
            else
                set(gca,'FontSize',fontSize); title(['Concentration of zeros = ' num2str(round(c0,2)) '; MCS = ' num2str(MCS)]);
            end
        end
        pause(0.0333); % Adds a pause for the slow-ass interface to update properly.
        
        % Export the frame as png, pdf or gif.
        if export == true
            exportFrame
        end
    end
    sequence = false; %Once the sequence has been shown, it will only show new frames.
    
    % Adds the final frame the the GIF.
    if export == true && sum(f == 'gif') == 3
        exportFrame
    end
    
    % Provides some nice feeback to the user if export is used. If 'once' was true, the script silently breaks.
    if once == true
        if export == true
            clc; fprintf('Done exporting!\n')
            break;
        end
        break;
    elseif export == true
        clc; fprintf('Done exporting!\n')
        break;
    end
    
    % Just a simple counter to avoid querying the folder constantly. It automatically breaks after 15 minutes.
    numPause = 0;
    while tempPause
        pause(5)
        a = dir([directory '/*.dat']);
        if b < numel(a)
            break;
        end
        numPause = numPause + 1;
        if numPause > 180
            go = false;
            break;
        end
    end
end

% Plots the dominating peak vs MCS.
if FourierTransform == true && radialDist == true
    clf;
    nSave = nSave(nSave ~= 0); % Strip zeros.
    locsSave = locsSave(nSave ~= 0); % Strip zeros.
    
    plot(nSave,locsSave,'.k', 'MarkerSize',20)
    
    % Cosmetic plot stuff.
    set(gca,'FontSize',fontSize)
    xlabel('MCS (arb.\ units)')
    ylabel('$r$')
    box off
    
    xlim([min(nSave), max(nSave)]);
    ylim([1, 8]);
    yticks([1:8])
    xticks([])
    %     yticklabels({})
    %     xticklabels({})
    
    set(gcf,'Units','pixels');
    set(gcf,'Position', [0 0 550 400]*1.2)
    set(gcf,'color','w');
    tightfig;
    
    if export == true
        fig = gcf;
        filename = sprintf([directory '-domainCoarsening.' f]);
        if sum(f == 'png') == 3
            frame = getframe(fig);
            im = frame2im(frame);
            [imind,cm] = rgb2ind(im,256);
            imwrite(imind,cm,filename,f);
        else
            set(fig,'Units','Inches');
            pos = get(fig,'Position');
            set(fig,'PaperPositionMode','Auto','PaperUnits','Inches','PaperSize',[pos(3), pos(4)])
            print(fig,filename,'-dpdf','-r0')
        end
    end
end

%% Functions
% This function does some initial debugging to catch any obvious mistakes, such as the directory being empty.
function [once, x0, rawMap, lowLim, go, tempPause, k] = preChecks(sequence)
    global directory f export criticalRegion current
    a = dir([directory '/*.dat']);
    b = numel(a);
    if b == 0
        error('Empty directory...\nAborting!',class(b)) %Throws an error and aborts. Note that the class(b) is necessary for MATLAB to parse the /n for.. reasons.
    end
    fprintf(['\nThe number of .dat files in the directory is ' num2str(b) '.\n'])

    % This part determines how old the last frame is in comparison with the time it took to generate it. This is then used to set 'once' accordingy.
    if b > 1
        T = struct2table(a);
        sortedT = sortrows(T, 'date');
        sortedA = table2struct(sortedT);

        cTb1 = datetime - datetime(getfield(sortedA(b),'date'));
        cTb2 = datetime - datetime(getfield(sortedA(b-1),'date'));
        timeSinceLF1 = seconds(cTb1);
        timeSinceLF2 = seconds(cTb2);

        if timeSinceLF1 > 1.5*(timeSinceLF2-timeSinceLF1)
            once = true;
        else
            once = false;
        end
    else
        once = false;
    end

    % This loads the j_demix vector when appropriate.
    if criticalRegion == true
        x0 = load_x0([directory '-x0.mat'],1);
    else
        x0 = [];
    end
    
    % Sets the raw data map.
    rawMap = [1 1 0; 1 0 0; 0 0 1];

    % Sets the lower limit in the main loop.
    if sequence == true || export == true
        lowLim = 1;
    else
        lowLim = b;
    end
    k = 0;
    current = 1; %Maximum value to export.

    % Set initial conditionals for the main loop.
    if export == true
        fprintf(['\nWill export frames as a .' f '.\n']);
    else
        fprintf('\nWill NOT export frames.\n');
    end
    fprintf(['\nAll of the pre-checks passed!\n'])
    x = input('\nIs this correct? (y/n) ', 's');
    if x == 'y'
        go = true; tempPause = true; %Set initial conditionals and start the main function.
    elseif x == 'n'
        error('Please adjust settings accordingly...\nAborting!',class(x))
    else
        error('Invalid input...\nAborting!',class(x))
    end
end

% This function takes the current frame, the cell size and the size of the lattice and returns the RGB data (with correct mappings) of the +1, -1 and solvent sites on a per cell level.
function [diffRGB, solventRGB, downRGB, upRGB] = cellCalc(frame, cD)
    global lambda L
    % First a simple loop is carried out over all of the cells to determine the concentraions per cell.
    for i = 1:lambda:L
        for j = 1:lambda:L
            numDown = 0;
            numZero = 0;
            numUp = 0;
            for x2 = i:i+lambda-1
                for x1 = j:j+lambda-1
                    if frame(x2, x1) == -1
                        numDown = numDown + 1;
                    elseif frame(x2, x1) == 0
                        numZero = numZero + 1;
                    elseif frame(x2, x1) == 1
                        numUp = numUp + 1;
                    end
                end
            end
            cDown_cell((i+lambda-1)/lambda,(j+lambda-1)/lambda) = numDown/lambda^2;
            cZero_cell((i+lambda-1)/lambda,(j+lambda-1)/lambda) = numZero/lambda^2;
            cUp_cell((i+lambda-1)/lambda,(j+lambda-1)/lambda) = numUp/lambda^2;
        end
    end
    % The +1 and -1 species are combined into the black-and-white contrast.
    cDiff = cDown_cell - cUp_cell; %White <---> more down!

    % The different colourmaps are generated using the colour-depth.
    mapRed = [0:2^cD-1]'./(2^cD-1);
    mapGreen = [zeros(size(0:2^cD-1))]';
    mapBlue = [zeros(size(0:2^cD-1))]';
    solvMap = [mapRed mapGreen mapBlue];

    mapRed = [0:2^cD-1]'./(2^cD-1);
    mapGreen = [0:2^cD-1]'./(2^cD-1);
    mapBlue = [0:2^cD-1]'./(2^cD-1);
    diffMap = [mapRed mapGreen mapBlue];

    mapRed = [2^cD-1:-1:0]'./(2^cD-1);
    mapGreen = [2^cD-1:-1:0]'./(2^cD-1);
    mapBlue = [2^cD-1:-1:0]'./(2^cD-1);
    upMap = [mapRed mapGreen mapBlue];

    % Now we simply map the solvent to the Red channel.
    minv = 0;
    maxv = 1;
    ncol = size(solvMap,1);
    solv = round(1+(ncol-1)*(cZero_cell-minv)/(maxv-minv));
    solventRGB = ind2rgb(solv,solvMap);

    down = round(1+(ncol-1)*(cDown_cell-minv)/(maxv-minv));
    downRGB = ind2rgb(down,diffMap);

    up = round(1+(ncol-1)*(cUp_cell-minv)/(maxv-minv));
    upRGB = ind2rgb(up,upMap);

    % And the diff to all of the channels (black-and-white).
    minv = -1;
    maxv = 1;
    diff = round(1+(ncol-1)*(cDiff-minv)/(maxv-minv));
    diffRGB = ind2rgb(diff,diffMap);
end

% This function takes the RGB data of the solvent and the +1, -1 and merges and corrects it.
function im = cellMerge(solventRGB, diffRGB)
    % First the RGB data is simply added together.
    im = imadd(solventRGB,diffRGB);
    
    % The im data is converted to double.
    im = im2double(im);
    imSolv = im2double(solventRGB);

    % And transformed into the HSV colour-space.
    HSVim = rgb2hsv(im);
    HSVSolv = rgb2hsv(imSolv);

    % Then we correct the saturation of the merged images using the values from the solvent as the saturation in the combined image.
    HSVimSat = HSVim(:, :, 2);
    HSVSolvSat = HSVSolv(:, :, 3);

    % And finally we have the correct image with the propoer saturation values per cell.
    HSVimSat = HSVSolvSat;
    HSVim(:, :, 2) = HSVimSat;
    im = hsv2rgb(HSVim);
end

% This function takes the combined image RGB data for the cells and magnifies it in a linear fashion by 'mag' times.
function imInt = cellInt(im, mag)
    im = im2double(im); %First convert the image into double
    F = griddedInterpolant(im); %Then create 'a gridded interpolant object for the image'
    F.Method = 'linear'; %Select interpolation method (spline is the 'best' one)

    [sx,sy,sz] = size(im); %Record the sizes of the image data
    xq = (1:1/mag:sx)'; %Make the grid finer for the "x and y" data
    yq = (1:1/mag:sy)';
    zq = (1:sz)'; %Preserve the colour data
    imInt = F({xq,yq,zq}); %Apply the interpolation to the data
end

% This function takes image RGB data and Fourier transforms it.
function imFT = FTImage(imTemp)
    Y = fftshift(fft2(imTemp([1:size(imTemp,1)],:,1))) + fftshift(fft2(imTemp([1:size(imTemp,1)],:,2))) + fftshift(fft2(imTemp([1:size(imTemp,1)],:,3)));
    imFT = abs(Y);
end

% This function takes the raw data and Fourier transforms it.
function rawFT = FTRaw(rawTemp)
    Y = fftshift(fft2(rawTemp([1:size(rawTemp,1)],:)));
    rawFT = abs(Y);
end

% This function applies a stretch to the colour-space according to https://se.mathworks.com/matlabcentral/answers/307318-does-matlab-have-a-nonlinear-colormap-how-do-i-make-one.
function FTMap = stretchSpace(temp)
    dataMax = 2^4;
    dataMin = 2^1;
    centerPoint = 1;
    scalingIntensity = 5;
    y = 1:length(temp);
    y = y - (centerPoint-dataMin)*length(y)/(dataMax-dataMin);
    y = scalingIntensity * y/max(abs(y));
    y = sign(y).* exp(abs(y));
    y = y - min(y); y = y*511/max(y)+1;
    FTMap = interp1(y, temp, 1:512);
end

% This function takes the FT data, finds the radial average and plots the data, indicating the dominating peak.
function frameUpdated = radialPeaks(YTemp)
    global n x0 lambda L nSave locsSave
    %if criticalRegion ~= true
        r = [0:1:size(YTemp,1)/2];
        rAvg = radialAverage(YTemp, size(YTemp,1)/2+1, size(YTemp,1)/2+1, r);
        %[pks,locs] = findpeaks(rAvg(1:100),r(1:100)); % Find peaks within radius 100.
        [pks,locs] = findpeaks(rAvg(1:end),r(1:end)); % Find peaks.
%     else
%         [maxValue, linearIndexesOfMaxes] = max(YTemp(:));
%         [rowsOfMaxes colsOfMaxes] = find(YTemp == maxValue);
%         xData = YTemp(rowsOfMaxes,sort(unique([colsOfMaxes:colsOfMaxes+12])));
%         x = [1:size(xData,2)]-1;
%         [pks,locs] = findpeaks(xData,x); % Find peaks along critical x-axis.
%     end
    % Save largest peak
    if isempty(locs) ~= 1
        if exist('x0(n)') == 1 && x0(n) ~= 0 || exist('x0(n)') == 0
            [maxValue, linearIndexesOfMaxes] = max(pks);
            rowsOfMaxes = find(pks == maxValue);
            nSave(n) = n;
            locsSave(n) = locs(rowsOfMaxes);
        end
    end
    
    % Update frame (needs to be here to avoid massive confusion in the main script). Note that I pass the boolean 'frameUpdated' to avoid overwriting this update.
    clf;
    hold on
%     if criticalRegion ~= true
        plot(r,rAvg,'.-k', 'MarkerSize',20);
        %xlim([min(r), max(r)]); % CHANGE THE UPPER LIMIT WHEN EXPORTING!
%     else
%         plot(x,xData,'.-k', 'MarkerSize',20);
%         xlim([min(x), max(x)]); % CHANGE THE UPPER LIMIT WHEN EXPORTING!
%     end

%     xPrime = sort([1:(L/lambda)/8:L/lambda]-1);
%     xPrime = xPrime(xPrime ~= 0);
%     xticks(xPrime);
    if size(pks,2) ~= 0 && n > 1
        [maxValue, linearIndexesOfMaxes] = max(pks);
        rowsOfMaxes = find(pks == maxValue);
        plot([locs(rowsOfMaxes) locs(rowsOfMaxes)],[0 maxValue], '--', 'Color', [0 0 0] + 0.5) % dominatin peak
        plot(locs(rowsOfMaxes),maxValue,'.m', 'MarkerSize',20);
        xticks(sort(unique([xticks locs(rowsOfMaxes)])))
    end
    hold off
    frameUpdated = true;
    
    setDimensionsPeaks
end

% This function sets the dimensions of the MATLAB window when the radial peaks are requested.
function setDimensionsPeaks
    global lambda L fontSize c0 MCS f export n
    
    if n == 1
        xPrime = sort([1:(L/lambda)/8:L/lambda]-1);
        xPrime = xPrime(xPrime ~= 0);
        xticks(xPrime);
        xticks(sort(unique([xticks])));
    end
    
    xlim([0, 100])
    %ylim([0, 2000]*(4/lambda));
    
    yticks([])
    set(gcf,'Units','pixels');
    set(gcf,'Position', [0 0 550 400]*1.2)
    set(gcf,'color','w');
    xlabel('$r$')
    ylabel('Counts (arb.\ units)')
    set(gca,'FontSize',fontSize);
    if export == true && sum(f == 'pdf') == 3
        set(gca,'Position', [0.06 0.13 0.92 0.85])
    else
        title(['Concentration of zeros = ' num2str(round(c0,2)) '; MCS = ' num2str(MCS)]);
        set(gca,'Position', [0.06 0.13 0.92 0.8])
    end
    %tightfig;
end

% This function sets the dimensions of the MATLAB window (and thus also of the exported frame).
function setDimensions(height, width, scalefactor)
    global export gridOn f cellVisualisation L lambda frame linInt mag
    if export == true
        if sum(f == 'pdf') == 3
            height = 0.2*width; width = 0.2*width;
        else
            height = width;
        end
    end

    set(gcf,'color','w');
    set(gcf,'Units','pixels');
    set(gcf,'Position', [0 0 width width*scalefactor + (height-width)])
    ax = gca;
    if gridOn == true
        ax.GridAlpha = 0.8;
        ax.LineWidth = 1.0;
        if cellVisualisation == true
            if linInt == true
                xticks([0:1:L/lambda]*mag+0.5)
                yticks([0:1:L/lambda]*mag+0.5)
            else
                xticks([0:1:L/lambda]+0.5)
                yticks([0:1:L/lambda]+0.5)
            end
        else
            xticks([0:lambda:size(frame,1)]+0.5)
            yticks([0:lambda:size(frame,2)]+0.5)
        end
        grid on
        set(gca,'Position', [0.003 0.005 0.99 0.99])
    else
        ax.YAxis.Visible = 'off';
        ax.XAxis.Visible = 'off';
        set(gca,'Position', [0 0 1 width*scalefactor/(width*scalefactor + (height-width))])
    end
end

% This function draws the critical region on top of the pre-existing frame.
function drawBox(critRows, length, scalefactor)
    global export x0 n

    % The first one draws the whole region and the second one draws only j_demix.
    % Note that the commented out section is vital for debugging since it draws j_demix for the cell case from the raw data, and hence it is always correct.
    hold on;
    h = rectangle('Position',[0 critRows(1)-1/2 length+1 critRows(end)-critRows(1)+1], 'FaceColor', 'b'); h.FaceColor(4)=0.3; h.EdgeColor(4)=0.0;
    h = rectangle('Position',[0 critRows(1)-1/2 length+1 scalefactor], 'FaceColor', 'b'); h.FaceColor(4)=0.3; h.EdgeColor(4)=0.0;
%     if export == true && sum(f == 'pdf') == 3
%         h = rectangle('Position',[0 floor(x0(n)-1/2)*scalefactor length+1 1*scalefactor], 'FaceColor', 'b'); h.FaceColor(4)=0.305; h.EdgeColor(4)=0.0;
%     else
%         h = rectangle('Position',[0 (floor(x0(n))-1/2)*scalefactor length+1 1*scalefactor], 'FaceColor', 'b'); h.FaceColor(4)=0.3; h.EdgeColor(4)=0.0;
%     end
    hold off
end

% This function simply extract the frames as png, pdf or gif.
function exportFrame
    global c0 MCS f directory pauseTime n b current
    
    fig = gcf;
    if sum(f == 'gif') ~= 3
        for k = 1:9
            if c0 <= 0.1
                k = 0.1;
            end
            if round(c0,2) == k/10 && k/10 < current || n == b
                current = k/10;
                filename = sprintf([directory '_MCS_' num2str(round(MCS,0)) '_c0_0%d.' f],str2num(strrep(num2str(round(c0,2)),'.','')));
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
        filename = [directory '.gif'];
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