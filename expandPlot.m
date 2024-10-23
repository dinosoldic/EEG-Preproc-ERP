function expandPlot(axisTime, meanData, semData, colors, chanIdx, chanLabel, legendLabels, doPlotSem, lineStyles)
    % This function is called internally by eegPlotERP and is not intended for
    % standalone use.
    %
    % See also: eegPlotERP
    %

    %% check inputs
    if ~doPlotSem
        legendLabels = legendLabels(strlength(legendLabels) > 0);
    end

    if size(meanData, 1) == 1
        %% For cond or group only
        figure;
        hold on;

        % Loop through each group for plotting
        for plotResultIdx = 1:numel(meanData)
            % Plot SEM
            if doPlotSem
                fill([axisTime, fliplr(axisTime)], ...
                    [meanData{plotResultIdx}(chanIdx, :) + semData{plotResultIdx}(chanIdx, :), ...
                     fliplr(meanData{plotResultIdx}(chanIdx, :) - semData{plotResultIdx}(chanIdx, :))], ...
                    colors(plotResultIdx, :), 'FaceAlpha', .1, 'linestyle', 'none');
            end

            % Plot Mean
            plot(axisTime, meanData{plotResultIdx}(chanIdx, :), 'Color', colors(plotResultIdx, :), 'LineWidth', 1.5);
        end

        % Add labels and formatting
        xlim([axisTime(1) axisTime(end)]);
        xline(0, '--', 'Color', 'k', 'Alpha', 0.8);
        xlabel('Time (s)');

        yline(0, '--', 'Color', 'k', 'Alpha', 0.8);
        ylabel('Amplitude (\muV)');

        title(chanLabel);

        legend(legendLabels, "Location", "northeastoutside");

        hold off;
        datacursormode on;
    else
        %% For cond x group or more
        figure;
        hold on;

        % Loop through each group for plotting
        for plotResultIdxRow = 1:size(meanData, 1)

            for plotResultIdx = 1:size(meanData, 2)
                % Plot SEM
                if doPlotSem
                    fill([axisTime, fliplr(axisTime)], ...
                        [meanData{plotResultIdxRow, plotResultIdx}(chanIdx, :) + semData{plotResultIdxRow, plotResultIdx}(chanIdx, :), ...
                         fliplr(meanData{plotResultIdxRow, plotResultIdx}(chanIdx, :) - semData{plotResultIdxRow, plotResultIdx}(chanIdx, :))], ...
                        colors(plotResultIdxRow, :), 'FaceAlpha', .1, 'linestyle', 'none');
                end

                % Plot Mean
                plot(axisTime, meanData{plotResultIdxRow, plotResultIdx}(chanIdx, :), lineStyles{plotResultIdx}, 'Color', colors(plotResultIdxRow, :), 'LineWidth', 1.5);
            end

        end

        % Add labels and formatting
        xlim([axisTime(1) axisTime(end)]);
        xline(0, '--', 'Color', 'k', 'Alpha', 0.8);
        xlabel('Time (s)');

        yline(0, '--', 'Color', 'k', 'Alpha', 0.8);
        ylabel('Amplitude (\muV)');

        title(chanLabel);

        legend(legendLabels, "Location", "northeastoutside");

        hold off;
        datacursormode on;
    end

end
