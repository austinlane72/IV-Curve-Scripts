function IV_Curve_Plot_Saver_Par()
    % IV_Curve_Plot_Saver_Par: Generates and saves plots from a .mat table in parallel.
    % Automatically batches and saves all plot combinations (by device and 
    % by parameter) as .png files. Designed for processing
    % large datasets (>100 plots) using multiple CPU cores.
    %
    % Requirements: Parallel Computing Toolbox
    
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
        [status, msg] = mkdir(mainSavePath); 
        if ~status
            error('PlotSaver:DirectoryError', ['Failed to create main save ' ...
                'directory. Ensure you have write permissions.\nPath: %s\nReason: %s'], mainSavePath, msg);
        end
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

    masterTable.TestType = string(masterTable.TestType);
    
    % 4) Define Configurations
    % {Data Column, Y-Axis Label, Plot Title Y-Var, Filename Suffix, Y-Scale}
    baseConfigs = {
        'ID',    '\itI\rm_{D} (\rm\muA)',  '\itI\rm_{D}',  'ID',  'linear';
        'IG_nA', '\itI\rm_{G} (\rmnA)',    '\itI\rm_{G}',  'IG',  'linear';
        'IDS',   '\itI\rm_{DS} (\rm\muA)', '\itI\rm_{DS}', 'IDS', 'linear'
    };

    compareConfigs = [baseConfigs; {
        'ID_log',  '|\itI\rm_{D}| (\rm\muA)',  '|\itI\rm_{D}|',  'ID_log',  'log';
        'IG_log',  '|\itI\rm_{G}| (\rmnA)',    '|\itI\rm_{G}|',  'IG_log',  'log';
        'IDS_log', '|\itI\rm_{DS}| (\rm\muA)', '|\itI\rm_{DS}|', 'IDS_log', 'log'
    }];

    testTypes = {'Output', 'Transfer'};
    xLabels   = {'\itV\rm_{DS} (V)', '\itV\rm_{GS} (V)'};
    
    % 4.5) Start the parallel pool if it isn't running
    if isempty(gcp('nocreate'))
        fprintf('\nStarting parallel pool (this takes a few seconds)...\n');
        parpool;
    end
    
    % 5) Main loop
    for t = 1:numel(testTypes)
        tType = testTypes{t};
        xLbl  = xLabels{t};
        
        fprintf('\nExtracting %s Data\n', tType);
        
        tData = masterTable(masterTable.TestType == tType, :);
        if isempty(tData)
            fprintf('No data found for %s test. Skipping...\n', tType);
            continue; 
        end
        
        % Generate Plots by Device
        fprintf('\nGrouping by DeviceName...\n');
        devDir = fullfile(mainSavePath, 'Plots_by_Device');
        generatePlotBatch(tData, 'DeviceName', 'Parameter', baseConfigs, ...
                          tType, xLbl, devDir, '(%s - %s)', '%s_%s');
        
        % Generate Comparison Plots
        fprintf('\nGrouping by Parameter...\n');
        compDir = fullfile(mainSavePath, 'Comparisons', tType);
        generatePlotBatch(tData, 'Parameter', 'DeviceName', compareConfigs, ...
                          tType, xLbl, compDir, '(Compare %s @ %s)', 'Compare_%s_%s');
    end

    fprintf(' Batch plot generation complete\n');
    fprintf(' All plots successfully saved inside:\n %s\n', mainSavePath);
end

function generatePlotBatch(data, mainGroupCol, subGroupCol, configs, tType, xLbl, baseDir, titleFmt, fileFmt)
    % generatePlotBatch: Handles the repetitive work: identifying groups, creating 
    % folders, formatting titles/filenames, looping through configs, and saving images.
    %
    % Inputs:
    %   data         - Filtered table containing the data to plot
    %   mainGroupCol - Column name to group by for folders (e.g., 'DeviceName')
    %   subGroupCol  - Column name to group by for lines (e.g., 'Parameter')
    %   configs      - Cell array of plot configurations
    %   tType        - String specifying the test type ('Output' or 'Transfer')
    %   xLbl         - String for the X-axis label
    %   baseDir      - Directory path to save the generated folders/plots
    %   titleFmt     - Format string for the plot title
    %   fileFmt      - Format string for the saved filename

    % Find all unique items in the main grouping column (e.g., all Devices)
    mainGroups = unique(data.(mainGroupCol));
    totalGroups = numel(mainGroups);
    
    % Pre-slice the data into a cell array to prevent broadcasting the entire 
    % table to every parallel worker (resolves the 'data' broadcast warning).
    slicedData = cell(totalGroups, 1);
    for i = 1:totalGroups
        slicedData{i} = data(data.(mainGroupCol) == string(mainGroups(i)), :);
    end
    
    % Parfor Loop: Distributes the distinct groups across CPU cores
    parfor i = 1:totalGroups
        mainVal = string(mainGroups(i));
        
        groupData = slicedData{i};
        if isempty(groupData), continue; end
        
        % In a parfor loop, execution is asynchronous. We just print the name.
        fprintf('Worker rendering group: %s\n', mainVal);
        
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
        
        % Create figure inside worker
        workerFig = figure('Visible', 'off', 'Units', 'Inches', 'Position', [1 1 8 6]);
        workerAx = axes('Parent', workerFig);
        
        for c = 1:size(configs, 1)
            % Extract config variables specifically for parfor indexing rules
            configRow = configs(c, :);
            yCol   = configRow{1};
            yLbl   = configRow{2};
            titleY = configRow{3};
            fileY  = configRow{4};
            yScale = configRow{5};
            
            % Clear the axes (faster than closing/opening figures) and hold
            cla(workerAx); 
            hold(workerAx, 'on');
            
            % Draw a separate line for each sub-group item
            for k = 1:numel(subGroups)
                subVal = string(subGroups(k));
                lineData = groupData(groupData.(subGroupCol) == subVal, :);
                if ~isempty(lineData)
                    % Plot using the pre-calculated column name defined in the config
                    plot(workerAx, lineData.V, lineData.(yCol), 'DisplayName', char(subVal), 'LineWidth', 2.0);
                end
            end
            
            hold(workerAx, 'off');
            set(workerAx, 'YScale', yScale);
            
            % Apply Text and Formatting Styles
            title(workerAx, sprintf('%s vs %s %s', titleY, xLbl(1:12), titleSuffix), ...
                'FontWeight', 'normal', 'FontSize', 20, 'FontName', 'Arial');
            xlabel(workerAx, xLbl, 'FontSize', 20, 'FontName', 'Arial');
            ylabel(workerAx, yLbl, 'FontSize', 20, 'FontName', 'Arial');
            grid(workerAx, 'on');
            
            % Smart Legend: Turn off if there are too many lines to prevent clutter
            if numel(subGroups) > 15
                legend(workerAx, 'off');
            else
                lgd = legend(workerAx, 'Location', 'eastoutside');
                lgd.FontSize = 20; 
                lgd.FontName = 'Arial';
            end
            
            finalPath = fullfile(saveDir, sprintf('%s_%s.png', baseFileName, fileY));
            exportgraphics(workerAx, finalPath, 'Resolution', 300);
        end
        
        % Delete the worker figure
        % Free up memory before the next loop iteration starts
        delete(workerFig);
    end
end