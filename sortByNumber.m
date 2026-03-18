function sorted = sortByNumber(nameList)
    % sortByNumber  Sort filenames by the first integer they contain.
    nums = cellfun(@(s) sscanf(regexp(s,'\d+','match','once'),'%d'), nameList);
    [~, idx] = sort(nums);
    sorted = nameList(idx);
end