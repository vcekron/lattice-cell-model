clear; % Clears old variables.
clc; % Clears command window.
clf; % Clears figures.
%close all; % Closes any open windows.

%% LaTeX stuff.
set(groot, 'defaultAxesTickLabelInterpreter','latex');
set(groot, 'defaultTextInterpreter','latex');
set(groot, 'defaultLegendInterpreter','latex');

x = [2, 4, 8, 16, 32, 64, 128]; 
leng = 1:size(x,2);
leng1 = 1:size(x,2)-1;
leng2 = 1:size(x,2)-2;
leng3 = 2:size(x,2);

yF = [1.08747876, 1.01214349, 1.14117622, 1.23938262, 1.97696221]; %FBC; L = 128

yF = [yF, 1.02918613, 0.935339808, 1.01214576, 1.20282924, 1.25657368, 1.97355664]; %FBC; L = 256
yP = [1.03040695, 0.900819004, 1.00411248, 1.17399967, 1.26286650, 1.97461593]; %PBC; L = 256

yF = [yF, 0.989822507, 0.859253883, 0.926216125, 1.00834835, 1.20077586, 1.25075674, 1.97766018]; %FBC; L = 512

yF = [yF, 0.812610090, 0.862490475, 0.927222311, 1.01454568, 1.19212115, 1.24526155]; %FBC; L = 1024

export = true;
bol = exist('yP');

%f=fit(x',y','linear')

%f = fit(log(x)',log(y)','poly1');
%c = coeffvalues(f);
%fprintf(['k = ' num2str(exp(c(2))) '*exp(' num2str(c(1)) '*lambda)\n']);

% Plotting
%figure
%h1 = axes;
set(gca,'FontSize',14)
grid on
hold on
if exist('yP') == 1
    plot(x(leng1), yF(leng1 + max(leng2)),'.k', 'MarkerSize',20) %FBC; L = 256
    plot(x(leng1), yP(leng1),'.m', 'MarkerSize',20) %PBC; L = 256
else
    plot(x(leng2), yF(leng2),'.-k', 'MarkerSize',20) % L = 128
    plot(x(leng1), yF(leng1 + max(leng2)),'.-m', 'MarkerSize',20) % L = 256
    plot(x(leng), yF(leng + max(leng2)-1 + size(x,2)),'.-b', 'MarkerSize',20) % L = 512
    plot(x(leng3), yF(leng3 -1 + max(leng2)-1 + 2*size(x,2)),'.-', 'Color', [1 0.5 0], 'MarkerSize',20) % L = 1024
end

hold off

% Cosmetic plot stuff.
xlabel('$\lambda$ [$\log_2$]')
ylabel('$\langle \mathcal{H}_{\textnormal{int}} \rangle$')
%title('Line profiles')
if exist('yP') == 1
    legend('FBC','PBC','Location','southeast')
else
    legend('$L = 128$','$L = 256$','$L = 512$','$L = 1024$','Location','southeast')
end
box on

if exist('yP') == 1
    xlim([min(x) - 1*min(x), max(x(leng1)) + 0.03*max(x(leng1))]);
    ylim([min(yF) - 0.01*min(yF(leng1 + max(leng2))), max(yF(leng1 + max(leng2))) + 0.05*max(yF(leng1 + max(leng2)))]);
else
    xlim([min(x) - 1*min(x), max(x) + 0.02*max(x)]);
    ylim([min(yF) - 0.2*min(yF), max(yF) + 0.05*max(yF)]);
end
%set(gca, 'YScale', 'log')
%set(gca, 'XScale', 'log')
%
%xticks(unique([sort(512./x) sort(1024./x)]))
%xticklabels(split(num2str(log2(unique([sort(512./x) sort(1024./x)])))))
xticks(unique([sort(x)]))
xticklabels(split(num2str(log2(unique([sort(x)])))))
yticks([0:0.2:100])
%yticklabels({'0.4','0.6','0.8','1.0','1.2','1.4','1.6','1.8'})

if export ~= true
    set(gcf,'Units','pixels');
    set(gcf,'Position', [0 0 550 400]*1.5)
    set(gcf,'color','w');
    tightfig;
else
    set(gcf,'Units','pixels');
    set(gcf,'Position', [0 0 550 400])
    set(gcf,'color','w');
    tightfig;
    fig = gcf;
    filename = 'energyPerSite';
    
    set(fig,'Units','Inches');
    pos = get(fig,'Position');
    set(fig,'PaperPositionMode','Auto','PaperUnits','Inches','PaperSize',[pos(3), pos(4)])
    print(fig,filename,'-dpdf','-r0')
end

%Rotate ylabel, taking into account its size/centre relation.
% ylh = get(gca,'ylabel');
% gyl = get(ylh);
% ylp = get(ylh, 'Position');
% set(ylh, 'Rotation',0, 'Position',ylp, 'VerticalAlignment','middle', 'HorizontalAlignment','right');
%tightfig;