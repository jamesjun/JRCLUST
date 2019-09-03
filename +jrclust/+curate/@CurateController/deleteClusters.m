function deleteClusters(obj, deleteMe)
    %DELETECLUSTERS Delete clusters either specified or selected
    if obj.isWorking
        jrclust.utils.qMsgBox('An operation is in progress.');
        return;
    end

    if nargin < 2 && numel(obj.selected) > 1
        return;
    elseif nargin < 2
        deleteMe = obj.selected(1);
    end

    obj.isWorking = 1;
    
    % speculatively delete clusters
    res = struct('spikeClusters', {}, 'metadata', {}); % empty struct array
    deleteMe = sort(deleteMe, 'desc');
    for iCluster = 1:numel(deleteMe) % go backwards to avoid deleting the wrong units after a reorder
        if isempty(res)
            args = {obj.hClust.spikeClusters, deleteMe(iCluster), struct()};
        else
            args = {res(end).spikeClusters, deleteMe(iCluster), res(end).metadata};
        end

        res_ = obj.hClust.deleteUnit(args{:});

        % operation found to be inconsistent
        if isempty(res_.metadata)
            warning('failed to delete unit %d', iCluster);
            continue;
        end

        res(end+1) = res_;
    end

    if ~isempty(res)
        msg = ['delete ' strjoin(arrayfun(@num2str, deleteMe, 'UniformOutput', 0), ',')];
        try
            obj.hClust.commit(res(end).spikeClusters, res(end).metadata, msg);
        catch ME
            warning('Failed to delete: %s', ME.message);
            jrclust.utils.qMsgBox('Operation failed.');
        end
        
        obj.isWorking = 0; % in case updateSelect needs to zoom

        if obj.selected > obj.hClust.nClusters
            obj.selected = obj.hClust.nClusters;
        end

        % replot
        obj.updateFigWav();
        obj.updateFigRD(); % centers changed, need replotting
        obj.updateFigSim();
        obj.updateSelect(obj.selected, 1);
    end

    obj.isWorking = 0;
end