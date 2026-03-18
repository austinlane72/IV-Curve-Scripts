function subFolders = getSubFolders(folderPath)
    % getSubFolders Returns a struct array of subfolders in folderPath
    contents = dir(folderPath);
    isDir = [contents.isdir];
    isNotDot = ~ismember({contents.name}, {'.', '..'});
    subFolders = contents(isDir & isNotDot);
end