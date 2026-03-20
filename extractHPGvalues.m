function M = extractHPGvalues(folderPath)
    % extractHPGvalues: Extracts voltage and current values from .hpg files.
    % Reads lines 12–21 from each .hpg file in the specified folder, parses the 
    % three (<number><unit>) tokens per line, converts via unitFactors (to μA & V),
    % and returns a matrix with duplicates removed.
    %
    % Inputs:
    %   folderPath - Directory containing .hpg files (defaults to pwd if omitted)
    %
    % Outputs:
    %   M - A (10*nFiles)x3 numeric matrix where:
    %       M(:,1) = voltages [V]
    %       M(:,2) = currents [μA]
    %       M(:,3) = leak-currents [μA]

    % 0) If folderPath is omitted, uses pwd.
    if nargin<1, folderPath = pwd; end

    % 1) Discover & sort files numerically
    D = dir(fullfile(folderPath,'*.hpg'));
    if isempty(D)
        M = [];
        return;
    end
    names = sortByNumber({D.name});

    nFiles  = numel(names);
    nLines  = 10;    % lines 12–21
    allRows = nan(nFiles * nLines,3);

    % 2) unit → factor map (*A → μA, V stays V)
    unitFactors = struct(...
      'v',  1,   'a',  1e6, 'ma', 1e3, ...
      'ua', 1,   'na', 1e-3,'pa', 1e-6);

    % 3) One regex to pull all (<number><unit>) tokens
    tokenPattern = '([-+]?\s*\d*\.?\d+(?:[eE][-+]?\d+)?)([munpMUNP]?A|[vV])';

    % 4) Main loop: read 10 lines with needed values
    rowIdx = 0;
    tmp = cell(nLines,1);
    for fileIDx = 1:nFiles
        fn = fullfile(folderPath, names{fileIDx});
        fid = fopen(fn,'r');
        if fid == -1, warning('Could not open file: %s', fn); continue; end
        
        % Skip first 11 header lines
        for headerLineIdx = 1:11, fgetl(fid); end
        % Read lines 12-21
        for dataLineIdx = 1:nLines, tmp{dataLineIdx} = fgetl(fid); end
        fclose(fid);
        
        block = string(tmp);
        % Pull tokens for each of the 10 lines
        tokens = regexp(block, tokenPattern, 'tokens');

        for lineIdx = 1:nLines
            if lineIdx > numel(tokens) || isempty(tokens{lineIdx}), continue; end
            
            T = tokens{lineIdx};
            if numel(T)==3
                rowIdx = rowIdx + 1;
                for valIdx = 1:3
                    % Take out spaces between - and .
                    rawVal = regexprep(T{valIdx}{1}, '^\s*([-+])\s+', '$1');
                    val  = str2double(rawVal);
                    u    = lower(T{valIdx}{2});
                    if isfield(unitFactors, u)
                        allRows(rowIdx, valIdx) = val * unitFactors.(u);
                    else
                        warning('Unknown unit "%s" in %s',T{valIdx}{2},names{fileIDx});
                    end
                end
            else
                warning('%s line %d: expected 3 tokens, got %d', ...
                        names{fileIDx}, 11+lineIdx, numel(T));
            end
        end
    end
    
    % 5) Truncate & remove duplicate rows
    allRows = allRows(1:rowIdx,:);
    M = unique(allRows, 'rows', 'stable');
end