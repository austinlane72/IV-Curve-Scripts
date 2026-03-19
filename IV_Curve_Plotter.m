function IV_Curve_Plotter()
    % IV_Curve_Plotter: Interactively generates plots from a .mat table.
    % Allows the user to load a consolidated data file, select a test type 
    % (Output/Transfer), and visually compare specific devices or parameters
    % within the MATLAB figure window.
    
    % 1) Load Data
    [file, path] = uigetfile('*.mat', 'Select a MAT file to plot (e.g., device_data.mat)');
    if file == 0, disp('Canceled.'); return; end
    
    fprintf('Loading data from %s...\n', file);
    load(fullfile(path, file), 'masterTable');
    
    % 2) Ask for test type
    allTestTypes = unique(masterTable.TestType);
    [idx, ok] = listdlg('ListString', allTestTypes, 'SelectionMode', 'single', 'PromptString', 'Select a Test Type:');
    if ~ok, disp('Canceled.'); return; end
    targetTest = allTestTypes(idx);
    
    % Pre-filter data by test type
    data = masterTable(masterTable.TestType == targetTest, :);
    
    % Define all plot parameters in a struct array (DRY principle)
    plotParams(1) = struct('yFunc', @(d) d.ID, ...
                           'yLabel', '\itI\rm_{D} (\rm\muA)', ...
                           'yTitle', '\itI\rm_{D}');
                       
    plotParams(2) = struct('yFunc', @(d) d.IG * 1e3, ...
                           'yLabel', '\itI\rm_{G} (\rmnA)', ...
                           'yTitle', '\itI\rm_{G}');
                       
    plotParams(3) = struct('yFunc', @(d) d.ID + d.IG, ...
                           'yLabel', '\itI\rm_{DS} (\rm\muA)', ...
                           'yTitle', '\itI\rm_{DS}');
    
    % Set plot labels and title prefixes based on test type
    if strcmp(targetTest, 'Output') % Use 'char' for strcmp
        xLabelStr = '\itV\rm_{DS} (V)';
        xLabelShortStr = '\itV\rm_{DS}'; % For cleaner titles
        titlePrefix = 'Output';
    else % 'Transfer'
        xLabelStr = '\itV\rm_{GS} (V)';
        xLabelShortStr = '\itV\rm_{GS}'; % For cleaner titles
        titlePrefix = 'Transfer';
    end
    
    % 3) Check device count to determine plot mode
    availableDevices = unique(data.DeviceName);
    numDevices = numel(availableDevices);
    
    if numDevices == 0
        fprintf('No data found for test type: %s\n', targetTest);
        return;
    elseif numDevices == 1
        fprintf('Only one device found. Automatically selecting "Plot by Device" mode.\n');
        plotMode = 'Plot by Device (shows all parameters)';
    else % numDevices > 1
        plotMode = questdlg('How do you want to plot?', 'Plotting Mode', ...
                            'Plot by Device (shows all parameters)', ...
                            'Compare Devices (shows all devices for one parameter)', 'Cancel', ...
                            'Plot by Device (shows all parameters)');
    end
    
    % 4) Call the appropriate plotting logic
    % Set default y-scale
    yScale = 'linear';
    
    switch plotMode
        case 'Plot by Device (shows all parameters)'
            if numDevices == 1
                targetDevice = availableDevices(1);
            else
                [idx, ok] = listdlg('ListString', availableDevices, 'SelectionMode', 'single', 'PromptString', 'Select a Device:');
                if ~ok, disp('Canceled.'); return; end
                targetDevice = availableDevices(idx);
            end
            
            % Filter data and prepare plot-specific strings
            plotData = data(data.DeviceName == targetDevice, :);
            loopItems = unique(plotData.Parameter); % Loop over parameters
            dataSelector = @(item) plotData(plotData.Parameter == item, :);
            titleSuffix = sprintf('(%s - %s)', titlePrefix, targetDevice);
            
            % Y-scale is already 'linear' by default. No changes needed.
            
        case 'Compare Devices (shows all devices for one parameter)'
            availableParams = unique(data.Parameter);
            [idx, ok] = listdlg('ListString', availableParams, 'SelectionMode', 'single', 'PromptString', 'Select a Parameter to compare:');
            if ~ok, disp('Canceled.'); return; end
            targetParameter = availableParams(idx);
            
            % Filter data and prepare plot-specific strings
            plotData = data(data.Parameter == targetParameter, :);
            loopItems = unique(plotData.DeviceName); % Loop over devices
            dataSelector = @(item) plotData(plotData.DeviceName == item, :);
            titleSuffix = sprintf('(Comparison @ %s)', targetParameter);
            
            % Ask user for Y-axis scale
            scaleChoice = questdlg('Select Y-axis scale:', ...
                                   'Axis Scale', ...
                                   'Linear', 'Logarithmic', 'Cancel', ...
                                   'Linear');
            
            if strcmp(scaleChoice, 'Cancel'), disp('Plotting canceled.'); return; end
            
            % Modify parameters for Log scale
            if strcmp(scaleChoice, 'Logarithmic')
                yScale = 'log';
                % Loop over the params struct and modify it
                for i = 1:numel(plotParams)
                    % Wrap the existing function in abs()
                    plotParams(i).yFunc = @(d) abs(plotParams(i).yFunc(d)); 
                    % Add | | to labels and titles
                    plotParams(i).yLabel = sprintf('|%s|', plotParams(i).yLabel);
                    plotParams(i).yTitle = sprintf('|%s|', plotParams(i).yTitle);
                end
            end
            
        case 'Cancel'
            disp('Plotting canceled.');
            return;
    end
    
    % 5) Generate the three plots using a loop
    for i = 1:numel(plotParams)
        createPlot(loopItems, dataSelector, plotParams(i), ...
                   xLabelStr, xLabelShortStr, titleSuffix, yScale);
    end
end

function createPlot(loopItems, dataSelector, p, ...
                    xLabelStr, xLabelShortStr, titleSuffix, yScale)
    % createPlot: A generalized function to create a single plot with multiple lines.
    %
    % Inputs:
    %   loopItems      - Array of unique items (devices or params) to iterate over
    %   dataSelector   - Function handle to filter data for a specific item
    %   p              - Struct of plot configs (.yFunc, .yLabel, .yTitle)
    %   xLabelStr      - String for the full X-axis label
    %   xLabelShortStr - Shortened string for the X-axis variable in the title
    %   titleSuffix    - String appended to the end of the plot title
    %   yScale         - Scale of the Y-axis ('linear' or 'log')

    % Style settings
    plotFontSize = 20;
    plotLineWidth = 2.0;
    plotFontName = 'Arial';
    
    figure; 
    hold on;
    
    numItems = numel(loopItems);
    
    for i = 1:numItems
        item = loopItems(i);
        % Select the data for this specific item (device or parameter)
        itemData = dataSelector(item);
        
        if ~isempty(itemData)
            % Get the Y-values by applying the function handle from the struct
            yValues = p.yFunc(itemData);
            
            % Apply LineWidth setting to the plot
            plot(itemData.V, yValues, 'DisplayName', char(item), 'LineWidth', plotLineWidth);
        end
    end
    
    hold off;
    
    % Set Y-axis scale
    set(gca, 'YScale', yScale);
    
    % Use robust xLabelShortStr for the title
    title(sprintf('%s vs %s %s', p.yTitle, xLabelShortStr, titleSuffix), ...
          'FontWeight', 'normal', 'FontSize', plotFontSize, 'FontName', plotFontName);
    xlabel(xLabelStr, 'FontSize', plotFontSize, 'FontName', plotFontName);
    ylabel(p.yLabel, 'FontSize', plotFontSize, 'FontName', plotFontName);
    
    % Smart legend
    maxLegendItems = 15;
    if numItems > maxLegendItems
        legend('off');
        fprintf('Note: Legend hidden for "%s" plot (over %d items).\n', p.yTitle, maxLegendItems);
    else
        % Apply Font settings to the legend
        lgd = legend('Location','eastoutside');
        lgd.FontSize = plotFontSize;
        lgd.FontName = plotFontName;
    end
    
    grid on;
end