function IV_Curve_Plot_Saver()
    % IV_Curve_Plot_Saver: Generates and saves plots from a .mat table.
    
    % 1) Load data
    % Prompt the user to select the .mat file containing the data
    [file, path] = uigetfile('*.mat', 'Select a MAT file to process');
    if file == 0, disp('Canceled by user.'); return; end
    [~, dataFileName] = fileparts(file);
    fprintf('Loading data from %s...\n', file);
    
    % Load only the 'masterTable' variable to save memory
    load(fullfile(path, file), 'masterTable');
    
    % 2) Setup save directory
    % Prompt the user to select a base folder for saving the plots
    savePath = uigetdir('', 'Select a folder to save all plots');
    if savePath == 0, disp('Canceled by user.'); return; end
    
    % Create a dedicated subfolder for this specific data file's plots
    mainSavePath = fullfile(savePath, [dataFileName '_Plots']);
    if ~exist(mainSavePath, 'dir')
        mkdir(mainSavePath); 
    end
    fprintf('Plots will be saved to: %s\n', mainSavePath);
    
    % 3) Pre-Calculate plot data
    % We calculate these values once here for the entire table.
    fprintf('Pre-calculating math columns for plotting...\n');
    masterTable.IG_nA   = masterTable.IG * 1e3;
    masterTable.IDS     = masterTable.ID + masterTable.IG;
    masterTable.ID_log  = abs(masterTable.ID);
    masterTable.IG_log  = abs(masterTable.IG_nA);
    masterTable.IDS_log = abs(masterTable.IDS);
    
    % 4) Initialize figure & configurations
    % Create a single hidden figure. We reuse this figure for every plot
    % to prevent the massive overhead of opening/closing figure windows.
    mainFig = figure('Visible', 'off', 'Units', 'Inches', 'Position', [1 1 8 6]);
    mainAx = axes(mainFig);
    
    % Define Plot Configurations.
    % {Data Column, Y-Axis Label, Plot Title Y-Var, Filename Suffix, Y-Scale}
    baseConfigs = {
        'ID',    '\itI\rm_{D} (\rm\muA)',  '\itI\rm_{D}',  'ID',  'linear';
        'IG_nA', '\itI\rm_{G} (\rmnA)',    '\itI\rm_{G}',  'IG',  'linear';
        'IDS',   '\itI\rm_{DS} (\rm\muA)', '\itI\rm_{DS}', 'IDS', 'linear'
    };

    % Comparison configurations add the logarithmic plots
    compareConfigs = [baseConfigs; {
        'ID_log',  '|\itI\rm_{D}| (\rm\muA)',  '|\itI\rm_{D}|',  'ID_log',  'log';
        'IG_log',  '|\itI\rm_{G}| (\rmnA)',    '|\itI\rm_{G}|',  'IG_log',  'log';
        'IDS_log', '|\itI\rm_{DS}| (\rm\muA)', '|\itI\rm_{DS}|', 'IDS_log', 'log'
    }];

    % Define the test types we want to extract from the data
    testTypes = {'Output', 'Transfer'};
    xLabels   = {'\itV\rm_{DS} (V)', '\itV\rm_{GS} (V)'};
    
    % 5) Main loop
    for t = 1:numel(testTypes)
        tType = testTypes{t};
        xLbl  = xLabels{t};
        
        fprintf('\nExtracting %s Data\n', tType);
        
        % Filter the master table for only the current test type
        tData = masterTable(masterTable.TestType == string(tType), :);
        if isempty(tData)
            fprintf('No data found for %s test. Skipping...\n', tType);
            continue; 
        end
        
        % Generate Plots by Device
        fprintf('\nGrouping by DeviceName...\n');
        devDir = fullfile(mainSavePath, 'Plots_by_Device');
        % Call helper function: Groups by DeviceName, plots separate lines for Parameters
        generatePlotBatch(mainAx, tData, 'DeviceName', 'Parameter', baseConfigs, ...
                          tType, xLbl, devDir, '(%s - %s)', '%s_%s');
        
        % Generate Comparison Plots
        fprintf('\nGrouping by Parameter (Comparisons)...\n');
        compDir = fullfile(mainSavePath, 'Comparisons', tType);
        % Call helper function: Groups by Parameter, plots separate lines for DeviceNames
        generatePlotBatch(mainAx, tData, 'Parameter', 'DeviceName', compareConfigs, ...
                          tType, xLbl, compDir, '(Compare %s @ %s)', 'Compare_%s_%s');
    end

    % Clean up by closing the hidden figure
    close(mainFig);
    fprintf(' Batch plot generation complete\n');
    fprintf(' All plots successfully saved inside:\n %s\n', mainSavePath);
end

% =========================================================
% HELPER FUNCTION: generatePlotBatch
% =========================================================
% This function handles the repetitive work: identifying groups, creating 
% folders, formatting titles/filenames, looping through configs, and saving.
function generatePlotBatch(ax, data, mainGroupCol, subGroupCol, configs, tType, xLbl, baseDir, titleFmt, fileFmt)
    
    % Find all unique items in the main grouping column (e.g., all Devices)
    mainGroups = unique(data.(mainGroupCol));
    totalGroups = numel(mainGroups);
    
    for i = 1:totalGroups
        mainVal = string(mainGroups(i));
        
        % Filter the data for just this specific group item
        groupData = data(data.(mainGroupCol) == mainVal, :);
        if isempty(groupData), continue; end
        
        fprintf('  -> Processing Group [%d/%d]: %s\n', i, totalGroups, mainVal);
        
        % Clean the name so Windows/Mac doesn't crash on invalid folder characters
        safeName = matlab.lang.makeValidName(replace(replace(mainVal, '+', 'p'), '-', 'm'));
        
        % Create the specific subfolder for this group
        saveDir = fullfile(baseDir, safeName);
        if ~exist(saveDir, 'dir')
            mkdir(saveDir); 
        end
        
        % Format the base title and filename
        titleSuffix = sprintf(titleFmt, tType, mainVal);
        baseFileName = sprintf(fileFmt, safeName, tType);
        
        % Find all unique sub-items to draw as separate lines (e.g., Parameters)
        subGroups = unique(groupData.(subGroupCol));
        
        % Iterate through each plot configuration (ID, IG, IDS, etc.)
        for c = 1:size(configs, 1)
            [yCol, yLbl, titleY, fileY, yScale] = configs{c, :};
            
            % Clear the axes (faster than closing/opening figures) and hold
            cla(ax); 
            hold(ax, 'on');
            
            % Draw a separate line for each sub-group item
            for k = 1:numel(subGroups)
                subVal = string(subGroups(k));
                lineData = groupData(groupData.(subGroupCol) == subVal, :);
                if ~isempty(lineData)
                    % Plot using the pre-calculated column name defined in the config
                    plot(ax, lineData.V, lineData.(yCol), 'DisplayName', char(subVal), 'LineWidth', 2.0);
                end
            end
            
            hold(ax, 'off');
            set(ax, 'YScale', yScale);
            
            % Apply Text and Formatting Styles
            title(ax, sprintf('%s vs %s %s', titleY, xLbl(1:12), titleSuffix), ...
                'FontWeight', 'normal', 'FontSize', 20, 'FontName', 'Arial');
            xlabel(ax, xLbl, 'FontSize', 20, 'FontName', 'Arial');
            ylabel(ax, yLbl, 'FontSize', 20, 'FontName', 'Arial');
            grid(ax, 'on');
            
            % Smart Legend: Turn off if there are too many lines to prevent clutter
            if numel(subGroups) > 15
                legend(ax, 'off');
            else
                lgd = legend(ax, 'Location', 'eastoutside');
                lgd.FontSize = 20; 
                lgd.FontName = 'Arial';
            end
            
            % Construct final filename and save to disk
            finalPath = fullfile(saveDir, sprintf('%s_%s.png', baseFileName, fileY));
            exportgraphics(ax, finalPath, 'Resolution', 300);
        end
    end
end