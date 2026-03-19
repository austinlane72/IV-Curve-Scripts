function IV_Curve_HPG_Importer()
    % IV_Curve_HPG_Importer: Imports IV curve data from .hpg files.
    % Requires: getSubFolders, extractHPGvalues
    % The final data is saved as a '.mat' file in the current working directory.
    
    % 1) Ask user for import mode
    % Create a dialog box to ask the user what they want to do.
    importMode = questdlg('What do you want to import?', ...
                          'HPG Importer', ...
                          'All Devices (from top-level folder)', ...
                          'A Single Device', 'Cancel', ...
                          'All Devices (from top-level folder)');
    
    % 2) Process based on user's choice
    switch importMode
        case 'All Devices (from top-level folder)'
            parentFolder = uigetdir('', 'Select the Top-Level "Devices" Folder');
            if parentFolder == 0, disp('Canceled.'); return; end % Exit if user hits cancel
            
            [~, folderName] = fileparts(parentFolder);
            deviceFolders = getSubFolders(parentFolder);

        case 'A Single Device'
            devicePath = uigetdir('', 'Select a Single Device Folder');
            if devicePath == 0, disp('Canceled.'); return; end % Exit if user hits cancel
            
            [parentFolder, deviceName] = fileparts(devicePath);
            deviceFolders = struct('name', deviceName);
            folderName = deviceName;

        case 'Cancel'
            disp('Import canceled.');
            return;
    end

    % Initialize an empty table to hold all combined data
    masterTable = table();
    
    % Loop through each device folder found
    for i = 1:length(deviceFolders)
        deviceName = deviceFolders(i).name;
        devicePath = fullfile(parentFolder, deviceName);
        fprintf('--- Processing Device: %s ---\n', deviceName);
        
        try
            deviceTable = processDevice(devicePath, deviceName);
            masterTable = [masterTable; deviceTable];
        catch ME
            warning('Failed to process device %s: %s', deviceName, ME.message);
        end
    end
    
    % After processing all devices, save the final master table
    if ~isempty(masterTable)
        safeName = matlab.lang.makeValidName(replace(folderName, ' ', '_'));
        saveFile = [safeName '_Data.mat'];
        save(saveFile, 'masterTable');
        fprintf('\nSuccess! All data saved to %s (in current working directory).\n', saveFile);
    else
        disp('No data was processed.');
    end
end

function deviceTable = processDevice(devicePath, deviceName)
    % processDevice: Parses all 'Output' and 'Transfer' .hpg data for a 
    % single device.
    %
    % Inputs:
    %   devicePath - Full path to the device folder (e.g., '.../Device_A')
    %   deviceName - Name of the device (e.g., 'Device_A')
    %
    % Output:
    %   deviceTable - A table containing all data (V, ID, IG) and metadata
    %                 (DeviceName, TestType, Parameter) for this one device.

    % Initialize an empty table for this specific device
    deviceTable = table();
    % Define the test types to look for
    testTypes = {'Output', 'Transfer'};
    
    % Loop through 'Output' and then 'Transfer'
    for j = 1:length(testTypes)
        testType = testTypes{j};
        testTypePath = fullfile(devicePath, testType);
        
        % Check if the folder (e.g., '.../Device_A/Output') exists
        if ~isfolder(testTypePath)
            % If not, print a message and skip to the next test type
            fprintf('  > Skipping Test Type (not found): %s\n', testType);
            continue; 
        end
        
        fprintf('  > Processing Test Type: %s\n', testType);
        
        % Get all parameter subfolders (e.g., 'VG=0', 'VG=-10')
        paramFolders = getSubFolders(testTypePath);
        
        % Loop through each parameter folder
        for k = 1:length(paramFolders)
            paramName = paramFolders(k).name;
            paramPath = fullfile(testTypePath, paramName);
            fprintf('    - Parameter: %s\n', paramName);
            
            % Robust Parsing Loop
            % Wrap the parsing call in a try/catch block.
            % This prevents one bad parameter folder (e.g., corrupt .hpg file)
            % from halting the import of the entire device.
            try
                % Call the external helper function to parse all .hpg files
                % in this single parameter folder.
                M = extractHPGvalues(paramPath); 
                
                % If data was successfully extracted (M is not empty)
                if ~isempty(M)
                    % Convert the n-by-3 matrix [V, ID, IG] to a table
                    fileData = table(M(:,1), M(:,2), M(:,3), 'VariableNames', {'V', 'ID', 'IG'});
                    
                    % Clean and Add Metadata
                    % Replace underscores with spaces for clean plot labels
                    safeDeviceName = replace(deviceName, '_', ' ');
                    safeParamName  = replace(paramName,  '_', ' ');
                    
                    % Add new columns to the table for identification
                    fileData.DeviceName = repmat(string(safeDeviceName), height(fileData), 1);
                    fileData.TestType = repmat(string(testType), height(fileData), 1);
                    fileData.Parameter = repmat(string(safeParamName), height(fileData), 1);
                    
                    % Append this parameter's data to the device's table
                    deviceTable = [deviceTable; fileData];
                end
            catch ME
                % If 'extractHPGvalues' failed for this folder, warn the user
                % and continue to the next parameter.
                warning('Failed to parse folder: %s. Error: %s', paramPath, ME.message);
                fprintf('    ...skipping this parameter and continuing.\n');
            end
        end
    end
end