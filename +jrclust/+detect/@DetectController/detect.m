function res = detect(obj)
    %DETECT Detect spikes in all recordings
    tDetect = tic();

    % get manually-set spike thresholds
    if ~isempty(obj.hCfg.threshFile)
        try
            S = load(obj.hCfg.threshFile);
            siteThresh = S.siteThresh;
            if obj.hCfg.verbose
                fprintf('Loaded %s\n', obj.hCfg.threshFile);
            end
        catch ME
            warning('Could not load threshFile %s: %s', obj.hCfg.threshFile, ME.message);
            siteThresh = [];
        end
    else
        siteThresh = [];
    end

    nRecs = numel(obj.hCfg.rawRecordings);
    hRecs = cell(nRecs, 1);

    res = struct('siteThresh', siteThresh, ...
                 'spikeTimes', [], ...
                 'spikeAmps', [], ...
                 'centerSites', [], ...
                 'spikesRaw', [], ...
                 'spikesFilt', [], ...
                 'spikesFilt2', [], ...
                 'spikesFilt3', [], ...
                 'spikeFeatures', []);

    recOffset = 0; % sample offset for each recording in sequence

    % load from files
    for iRec = 1:nRecs
        fn = obj.hCfg.rawRecordings{iRec};
        hRec = jrclust.models.recording.Recording(fn, obj.hCfg);

        if hRec.isError
            error(hRec.errMsg);
        end

        % subset imported samples in this recording interval
        [impTimes, impSites] = deal([]);
        if ~isempty(obj.importTimes)
            inInterval = (obj.importTimes > recOffset & obj.importTimes <= recOffset + hRec.nSamples);
            impTimes = obj.importTimes(inInterval) - recOffset; % shift spike timing

            % take sites assoc with times between limits
            if ~isempty(obj.importSites)
                impSites = obj.importSites(inInterval);
            end
        end

        obj.hCfg.updateLog('fileLoad', sprintf('Processing file %s (%d/%d)', hRec.binpath, iRec, nRecs), 1, 0);
        recData = obj.detectOneRecording(hRec, impTimes, impSites, siteThresh);
        try
            hRec.setDetections(recData);
        catch ME % maybe rethrow
            warning('error caught: %s', ME.message);
            continue;
        end

        obj.hCfg.updateLog('fileLoad', sprintf('Finished processing file %s (%d/%d)', hRec.binpath, iRec, nRecs), 0, 1);

        res.siteThresh = cat(2, res.siteThresh, recData.siteThresh);
        res.spikeTimes = cat(1, res.spikeTimes, recData.spikeTimes + recOffset);
        res.spikeAmps = cat(1, res.spikeAmps, recData.spikeAmps);
        res.centerSites = cat(1, res.centerSites, recData.centerSites);
        res.spikesRaw = cat(3, res.spikesRaw, recData.spikesRaw);
        res.spikesFilt = cat(3, res.spikesFilt, recData.spikesFilt);
        res.spikesFilt2 = cat(3, res.spikesFilt2, recData.spikesFilt2);
        res.spikesFilt3 = cat(3, res.spikesFilt3, recData.spikesFilt3);
        if isfield(recData, 'spikeFeatures')
            res.spikeFeatures = cat(3, res.spikeFeatures, recData.spikeFeatures);
        end

        recOffset = recOffset + hRec.nSamples;
        hRecs{iRec} = hRec;
    end % for

    % compute features from all spikes over all recordings
    if obj.hCfg.getOr('extractAfterDetect', 0) && strcmp(obj.hCfg.clusterFeature, 'gpca')
        res = obj.extractFeatures(res);
        res.spikeFeatures = jrclust.utils.tryGather(res.spikeFeatures);
    end

    res.siteThresh = mean(single(res.siteThresh), 1);

    % spike sites
    res.spikeSites = res.centerSites(:, 1);
    if size(res.centerSites, 2) > 1
        res.spikeSites2 = res.centerSites(:, 2);
    else
        res.spikeSites2 = [];
    end
    if size(res.centerSites, 2) > 2
        res.spikeSites3 = res.centerSites(:, 3);
    else
        res.spikeSites3 = [];
    end

    % spikes by site
    nSites = obj.hCfg.nSites;
    res.spikesBySite = arrayfun(@(iSite) find(res.centerSites(:, 1) == iSite), 1:nSites, 'UniformOutput', 0);
    if size(res.centerSites, 2) >= 2
        res.spikesBySite2 = arrayfun(@(iSite) find(res.centerSites(:, 2) == iSite), 1:nSites, 'UniformOutput', 0);
    else
        res.spikesBySite2 = [];
    end
    if size(res.centerSites, 2) == 3
        res.spikesBySite3 = arrayfun(@(iSite) find(res.centerSites(:, 3) == iSite), 1:nSites, 'UniformOutput', 0);
    else
        res.spikesBySite3 = [];
    end

    % detected spikes (raw and filtered), features
    res.rawShape = size(res.spikesRaw);
    res.filtShape = size(res.spikesFilt);
    res.featuresShape = size(res.spikeFeatures);

    % spike positions
    res.spikePositions = obj.spikePos(res.spikeSites, res.spikeFeatures);

    % recordings for inspection
    res.hRecs = hRecs;

    % summarize
    res.detectTime = toc(tDetect);
    res.detectedOn = now();
end