function hFigCorr = doPlotFigCorr(hFigCorr, hClust, hCfg, selected)
    %DOPLOTFIGCORR Plot timestep cross correlation
    if numel(selected) == 1
        iCluster = selected(1);
        jCluster = iCluster;
    else
        iCluster = selected(1);
        jCluster = selected(2);
    end

    jitterMs = 0.5; % bin size for correlation plot
    nLagsMs = 25; % show 25 msec

    jitterSamp = round(jitterMs*hCfg.sampleRate/1000); % 0.5 ms
    nLags = round(nLagsMs/jitterMs);

    iTimes = int32(double(hClust.spikeTimes(hClust.spikesByCluster{iCluster}))/jitterSamp);

    if iCluster ~= jCluster
        iTimes = [iTimes, iTimes - 1, iTimes + 1]; % check for off-by-one
    end
    jTimes = int32(double(hClust.spikeTimes(hClust.spikesByCluster{jCluster}))/jitterSamp);

    % count agreements of jTimes + lag with iTimes
    lag = -nLags:nLags;
    intCount = zeros(size(lag));
    for iLag = 1:numel(lag)
        if iCluster == jCluster && lag(iLag)==0
            continue;
        end
        intCount(iLag) = numel(intersect(iTimes, jTimes + lag(iLag)));
    end

    timeLag = lag*jitterMs;

    % draw the plot
    if isempty(hFigCorr.figData)
        hFigCorr.axes();
        hFigCorr.addPlot('hBar', @bar, timeLag, intCount, 1);
        hFigCorr.axApply(@xlabel, 'Time (ms)');
        hFigCorr.axApply(@ylabel, 'Counts');
        hFigCorr.axApply(@grid, 'on');
        hFigCorr.axApply(@set, 'YScale', 'log');
    else
        hFigCorr.update('hBar', timeLag, intCount);
        %set(hFigCorr.figData.hBar, 'XData', timeLag, 'YData', intCount);
    end

    % title_(hFigCorr.figData.hAx, sprintf('Cluster %d vs. Cluster %d', iCluster, jCluster));
    hFigCorr.axApply(@title, sprintf('Cluster %d vs. Cluster %d', iCluster, jCluster), 'Interpreter', 'none', 'FontWeight', 'normal');

    % xlim_(hFigCorr.figData.hAx, [-nLags, nLags] * jitterMs);
    hFigCorr.axApply(@set, 'XLim', jitterMs*[-nLags, nLags]);
    %set(hFigCorr, 'UserData', hFigCorr.figData);
end
