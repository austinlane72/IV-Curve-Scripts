function IV_Curve_XLSX_Importer()
    % IV_Curve_XLSX_Importer: Imports IV curve data from .xlsx files.
    % Prompts the user to select either a single device folder or a top-level
    % folder containing multiple devices. The script extracts data from 'Output' 
    % and 'Transfer' subfolders and saves the combined data as a single '.mat' 
    % file in the current working directory.
    %
    % Requirements: MATLAB R2019a or newer (for readmatrix and string arrays).
    
    % 1) Ask the user what they want to do
    importMode = questdlg('What do you want to import?', ...
                          'XLSX Importer', ...
                          'All Devices (from top-level folder)', ...
                          'A Single Device', 'Cancel', ...
                          'All Devices (from top-level folder)');
    
    % 2) Execute based on user choice
    switch importMode
        case 'All Devices (from top-level folder)'
            parentFolder = uigetdir('', 'Select the Top-Level "Devices" Folder');
            if parentFolder == 0, disp('Import Canceled.'); return; end 
            
            [~, folderName] = fileparts(parentFolder);
            deviceFolders = getSubFolders(parentFolder);
            
            if isempty(deviceFolders)
                disp('No device subfolders found in the selected directory.');
                return;
            end
            
        case 'A Single Device'
            devicePath = uigetdir('', 'Select a Single Device Folder');
            if devicePath == 0, disp('Import Canceled.'); return; end 
            
            [parentFolder, deviceName] = fileparts(devicePath);
            deviceFolders = struct('name', deviceName);
            folderName = deviceName;

        case 'Cancel'
            disp('Import canceled.');
            return;
    end

    % Preallocate a cell array
    numDevices = length(deviceFolders);
    masterCell = cell(numDevices, 1);
    
    % Loop through each device folder
    for i = 1:numDevices
        deviceName = deviceFolders(i).name;
        devicePath = fullfile(parentFolder, deviceName);
        
        fprintf('--- Processing Device: %s ---\n', deviceName);
        
        try
            masterCell{i} = processDeviceXLSX(devicePath, deviceName);
        catch ME
            warning('Failed to process device %s: %s', deviceName, ME.message);
        end
    end
    
    % Remove any empty cells (in case a device failed or had no data)
    masterCell = masterCell(~cellfun('isempty', masterCell));
    
    % Combine all data and save
    if ~isempty(masterCell)
        masterTable = vertcat(masterCell{:}); % Combine into one table
        saveFileName = [matlab.lang.makeValidName(folderName), '_Data.mat'];
        save(saveFileName, 'masterTable');
        fprintf('\nSuccess! All data saved to %s (in current working directory).\n', saveFileName);
    else
        disp('No data was successfully processed.');
    end
end

function deviceTable = processDeviceXLSX(devicePath, deviceName)
    % processDeviceXLSX: Extracts data from 'Output' and 'Transfer' folders.
    %
    % Inputs:
    %   devicePath - Full directory path to the specific device folder
    %   deviceName - Name of the device (used for tagging data rows)
    %
    % Outputs:
    %   deviceTable - A consolidated table containing data from all valid tests
    
    % --- Configuration ---
    XLSX_DATA_START_RANGE = 'A120';
    testTypes = {'Output', 'Transfer'};
    
    % Track duplicate parameters (e.g., if there are two VG=5 tests)
    paramCounts = containers.Map('KeyType','char','ValueType','int32');
    
    % Format device name once to save computation time
    safeDeviceName = string(replace(deviceName, '_', ' ')); 
    
    % Preallocate cell array to hold data for each individual file
    collectedData = {}; 
    
    % --- Loop through Test Types (Output / Transfer) ---
    for j = 1:length(testTypes)
        testType = testTypes{j};
        testTypePath = fullfile(devicePath, testType);
        
        if ~isfolder(testTypePath)
            fprintf('  > Skipping Test Type (not found): %s\n', testType);
            continue; 
        end
        
        fprintf('  > Processing Test Type: %s\n', testType);
        
        % Get all valid .xlsx files (ignoring hidden temporary ~$ files)
        xlsxFiles = dir(fullfile(testTypePath, '*.xlsx'));
        xlsxFiles = xlsxFiles(~[xlsxFiles.isdir] & ~startsWith({xlsxFiles.name}, '~$')); 
        
        if isempty(xlsxFiles)
            fprintf('    - No valid .xlsx files found.\n');
            continue; 
        end

        if length(xlsxFiles) > 1
            % Extract just the file names for the list menu
            fileNames = {xlsxFiles.name};
            
            % Create a descriptive prompt so you know which device you are looking at
            promptStr = sprintf('Select %s files to import for %s:', testType, safeDeviceName);
            
            % Open the selection dialog
            [selectedIndices, isOk] = listdlg('ListString', fileNames, ...
                                              'SelectionMode', 'multiple', ...
                                              'Name', 'Select Files', ...
                                              'PromptString', promptStr, ...
                                              'ListSize', [300, 150]);
            
            % If the user clicks "Cancel" or closes the window
            if isOk == 0
                fprintf('    - User canceled file selection. Skipping %s.\n', testType);
                continue; 
            end
            
            % Overwrite the xlsxFiles array to ONLY include the selected ones
            xlsxFiles = xlsxFiles(selectedIndices);
        end

        % Loop through each selected file
        for k = 1:length(xlsxFiles)
            filePath = fullfile(testTypePath, xlsxFiles(k).name);
            fprintf('    - Reading file: %s\n', xlsxFiles(k).name);
            
            try
                rawMatrix = readmatrix(filePath, 'Range', XLSX_DATA_START_RANGE); 
                
                if size(rawMatrix, 2) < 4
                    warning('File %s has fewer than 4 columns. Skipping.', filePath);
                    continue;
                end
                
               % 1) Extract Raw Columns and Standardize Based on Test Type
                % Keysight dynamically puts the Sweep var in Col 1 and Step var in Col 4
                if strcmp(testType, 'Output')
                    % Output Curve: Sweep VDS (Col 1), Step VG (Col 4)
                    PrimaryV    = rawMatrix(:, 1); % VDS
                    rawID       = rawMatrix(:, 2);
                    rawIG       = rawMatrix(:, 3);
                    StepParam   = rawMatrix(:, 4); % VG
                    paramPrefix = "VG=";
                else 
                    % Transfer Curve: Sweep VG (Col 1), Step VDS (Col 4)
                    PrimaryV    = rawMatrix(:, 1); % VG
                    rawID       = rawMatrix(:, 2);
                    rawIG       = rawMatrix(:, 3);
                    StepParam   = rawMatrix(:, 4); % VDS
                    paramPrefix = "VD=";
                end
                
                % 2) Clean Data (Remove rows where currents are NaN)
                nanRows = isnan(rawID) | isnan(rawIG);
                if all(nanRows), continue; end % Skip file if totally empty
                
                PrimaryV(nanRows)  = []; 
                rawID(nanRows)     = []; 
                rawIG(nanRows)     = []; 
                StepParam(nanRows) = [];

                if isempty(PrimaryV), continue; end % Skip if cleaning emptied the arrays
                
                % Convert currents to microamps
                ID_uA = rawID * 1e6; 
                IG_uA = rawIG * 1e6; 
                
                % 3) Handle Duplicate Files / Parameters
                % Find the most common step value in this file to identify it
                validParams = StepParam(~isnan(StepParam));
                fileModeValue = 0;
                if ~isempty(validParams)
                    fileModeValue = mode(validParams);
                end
                
                % Create a base key (e.g., "VG=5")
                baseKey = sprintf('%s%g', paramPrefix, fileModeValue); 
                suffix = "";
                
                % If we've seen this key before, add a suffix (e.g., "_2")
                if isKey(paramCounts, baseKey)
                    paramCounts(baseKey) = paramCounts(baseKey) + 1;
                    suffix = sprintf("_%d", paramCounts(baseKey));
                else
                    paramCounts(baseKey) = 1;
                end
                
                % Generate the final parameter strings for every row
                Parameter = compose("%s%g%s", paramPrefix, StepParam, suffix);
                Parameter = replace(Parameter, '_', ' '); % Clean for readability
                
                % 4) Build the Output Table
                % Create a table with the dynamic numeric data first
                fileTable = table(PrimaryV, ID_uA, IG_uA, Parameter, ...
                                  'VariableNames', {'V', 'ID', 'IG', 'Parameter'});
                fileTable.DeviceName(:) = safeDeviceName;
                fileTable.TestType(:)   = string(testType);
                
                % Reorder columns to a logical final layout
                fileTable = fileTable(:, {'V', 'ID', 'IG', 'DeviceName', 'TestType', 'Parameter'});
                
                % Store the finished table in our cell array
                collectedData{end+1} = fileTable; %#ok<AGROW> 
                fprintf('      ... imported %d rows (Base: %s%s)\n', height(fileTable), baseKey, suffix);
                
            catch ME
                warning('Failed to parse file: %s. Error: %s', filePath, ME.message);
            end
        end
    end
    
    % Finalize Device Table
    if ~isempty(collectedData)
        deviceTable = vertcat(collectedData{:}); % Combine all files efficiently
    else
        deviceTable = table(); % Return empty table if nothing was found
    end
end