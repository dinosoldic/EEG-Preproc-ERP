%
% EEGPLOTERP Plot Event-Related Potentials (ERPs) from EEG data.
%
%   EEGPLOTERP plots ERPs from EEG data stored in the specified
%   study directory.
%
%   The directory should be organized as follows:
%
%     Study
%     ├── Group1
%     │   ├── Condition1
%     │   │   ├── data1
%     │   │   └── dataN
%     │   └── Condition2
%     │       ├── data1
%     │       └── dataN
%     ├── Group2
%     │   ├── Condition1
%     │   │   ├── data1
%     │   │   └── dataN
%     │   └── Condition2
%     │       ├── data1
%     │       └── dataN
%     └── Group3
%         ├── Condition1
%         │   ├── data1
%         │   └── dataN
%         └── Condition2
%             ├── data1
%             └── dataN
%
% Points to keep in mind:
%   - You can have as many groups or conditions as needed, as long as they
%     are organized according to the instructions.
%   - If you have only conditions without groups, create a "Group1" folder
%     and place all condition folders inside it.
%   - If you have only one condition per group, create multiple "Group" folders,
%     each containing a "Condition1" folder with the corresponding data files.
%   - EEG data must be in EEGLAB’s EEG structure format, exported after preprocessing.
%   - EEGLAB is required for topoplot generation.
%
% This script performs the following steps:
%   1. Prompts the user to select the directory where the study data is located.
%   2. Loads and organizes the EEG data from the specified directory.
%   3. Allows the user to select and plot different types of ERP comparisons:
%      - Group vs Group
%      - Condition vs Condition
%      - Groups vs Conditions
%      - Topoplot
%      - 2D Topoplot Movie
%      - 3D Topoplot Movie
%   4. Generates and displays the selected plots.
%   5. Provides options to save the animated plots or movies.
%   6. Provides option to export ERP data to SPSS.
%
% Author: Dino Soldic
% Email: dino.soldic@urjc.es
%   Date: 2025-10-06
%
% See also: eegPreproc, exportSPSS, EEGLAB

%% Clean and Prep data
clear; clc;

% Prep data
% Select study dir
studyFolder = uigetdir(pwd, 'Select folder where your study data processed data is located');

% Check folder input
if studyFolder == 0, fprintf("Operation canceled by user. Shutting down\n"); return, end

% Set try catch with error for improper folder organisation
try
    % Get subdirs for group names
    studyFolderDirs = dir(studyFolder);
    studyFolderDirs = studyFolderDirs(3:end);
    groupNames = cell(1, numel(studyFolderDirs));

    for groupNameIdx = 1:numel(studyFolderDirs)
        % Find chars to cut
        isSpaced = strfind(studyFolderDirs(groupNameIdx).name, '_');

        % Cut name
        if ~isempty(isSpaced)
            % Replace all underscores with spaces
            cutGroupName = strrep(studyFolderDirs(groupNameIdx).name, '_', ' ');
        else
            cutGroupName = studyFolderDirs(groupNameIdx).name;
        end

        % Capitalize
        groupNames{groupNameIdx} = strcat(upper(cutGroupName(1)), cutGroupName(2:end));
    end

    % Get subdirs for condition names
    groupFolderDirs = dir(fullfile(studyFolderDirs(1).folder, studyFolderDirs(1).name));
    groupFolderDirs = groupFolderDirs(3:end);
    conditionNames = cell(1, numel(groupFolderDirs));

    for conditionNameIdx = 1:numel(groupFolderDirs)
        % Find chars to cut
        isSpaced = strfind(groupFolderDirs(conditionNameIdx).name, '_');

        % Cut name
        if ~isempty(isSpaced)
            % Replace all underscores with spaces
            cutConditionName = strrep(groupFolderDirs(conditionNameIdx).name, '_', ' ');
        else
            cutConditionName = groupFolderDirs(conditionNameIdx).name;
        end

        % Capitalize
        conditionNames{conditionNameIdx} = strcat(upper(cutConditionName(1)), cutConditionName(2:end));
    end

    % Load data
    ALLEEGDATA = struct();

    % Set loading bar
    wb = waitbar(0, 'Loading Data...');
    wb.UserData = [0 numel(groupNames) * numel(conditionNames)];

    % Load groups
    for loadGroupIdx = 1:numel(groupNames)
        % Get path for each group
        loadGroupPath = fullfile(studyFolderDirs(loadGroupIdx).folder, studyFolderDirs(loadGroupIdx).name);

        % Check for existence of group struct
        loadGroupName = strrep(groupNames{loadGroupIdx}, ' ', '');
        if ~isfield(ALLEEGDATA, loadGroupName), ALLEEGDATA.(loadGroupName) = struct(); end

        % Load conds
        for loadConditionIdx = 1:numel(conditionNames)
            % Get path for each cond
            loadConditionPath = fullfile(loadGroupPath, groupFolderDirs(loadConditionIdx).name);

            % Get subdirs for files in each cond
            conditionFolderDirs = dir(loadConditionPath);
            conditionFolderDirs = conditionFolderDirs(3:end);

            % Check for existence of cond struct
            loadConditionName = strrep(conditionNames{loadConditionIdx}, ' ', '');
            if ~isfield(ALLEEGDATA.(loadGroupName), loadConditionName), ALLEEGDATA.(loadGroupName).(loadConditionName) = struct(); end

            % Load files
            for eegFileIdx = 1:numel(conditionFolderDirs)
                load(fullfile(conditionFolderDirs(eegFileIdx).folder, conditionFolderDirs(eegFileIdx).name))
                ALLEEGDATA.(loadGroupName).(loadConditionName)(eegFileIdx).data = EEG.data;
                ALLEEGDATA.(loadGroupName).(loadConditionName)(eegFileIdx).meanData = mean(EEG.data, 3);
                ALLEEGDATA.(loadGroupName).(loadConditionName)(eegFileIdx).stdData = std(EEG.data, 0, 3);
            end

            % Update waitbar
            iIncrementWaitbar(wb);
        end

    end

    % Close waitbar
    close(wb);
    fprintf("Data Loaded\n");

    % Extract labels from last EEG for plots
    chanLabels = {EEG.chanlocs.labels};
    axisTime = [EEG.times];
    numChan = numel(chanLabels);
    chanlocs = EEG.chanlocs;
    srate = EEG.srate;

    % Make sure EEG.times is in ms and not s
    if max(axisTime) < 100 && any(mod(axisTime, 1) ~= 0)
        axisTime = axisTime .* 1000;
    end

catch importError
    close(wb);
    error("Run script again after checking study folder's organization. ERROR: %s", importError.message);
end

%% Plot ERP data
while true
    % Select plots
    plotOptions = {'Group vs Group', 'Condition vs Condition', 'Groups vs Conditions', 'Topoplot', '2D Topoplot Movie', '3D Topoplot Movie'};
    [plotOptionsSelection, ~] = listdlg('ListString', plotOptions, 'PromptString', 'Select plots:', 'SelectionMode', 'multiple');

    % ask to plot sem
    if ~isempty(plotOptionsSelection) && any(ismember([1, 2, 3], plotOptionsSelection))
        plotSem = questdlg('Do you wish to plot SEM alongside mean?', 'Plot SEM', 'Yes', 'No', 'Yes');

        if strcmp(plotSem, 'Yes')
            plotSem = true;
        else
            plotSem = false;
        end

    end

    %% Check for group vs group
    if ismember(1, plotOptionsSelection)
        % Load msg
        fprintf("Loading Group vs Group plot...\n");

        % Transform data for plot
        if ~exist("groupDataMean", "var")
            % Loop through groups
            for groupPlotIdx = 1:numel(groupNames)
                displacement = 1;
                loadGroupName = strrep(groupNames{groupPlotIdx}, ' ', '');

                % Loop through conds
                for conditionPlotIdx = 1:numel(conditionNames)
                    loadConditionName = strrep(conditionNames{conditionPlotIdx}, ' ', '');

                    % Loop through data points
                    for groupDataIdx = 1:numel(ALLEEGDATA.(loadGroupName).(loadConditionName))
                        groupDataMean{displacement, groupPlotIdx} = ALLEEGDATA.(loadGroupName).(loadConditionName)(groupDataIdx).meanData;
                        displacement = displacement + 1;
                    end

                end

            end

        end

        % Get mean and SEM
        resultToPlotMean = cell(1, numel(groupNames));
        resultToPlotSEM = cell(1, numel(groupNames));

        for resultIdx = 1:numel(groupNames)
            % Get the indices of non-empty cells
            nonEmptyIndicesMean = ~cellfun(@isempty, groupDataMean(:, resultIdx));

            % Extract non-empty cells
            resultMean = groupDataMean(nonEmptyIndicesMean, resultIdx);

            % Average subjects
            resultMean = cat(3, resultMean{:});
            resultToPlotSEM{resultIdx} = std(resultMean, 0, 3) ./ sqrt(size(resultMean, 3));
            resultToPlotMean{resultIdx} = mean(resultMean, 3);
        end

        % Plot
        % Set subplots per fig
        numRows = 6;
        numCols = 6;
        chanFigure = numRows * numCols;

        % Set amount of colors
        colors = lines(numel(groupNames));

        % Define and fill legend
        legendLabels = strings(1, 2 * numel(groupNames));
        legendLabels(2:2:end) = groupNames;

        % Loop through chans
        for figIdx = 1:ceil(numChan / chanFigure)
            figure;
            hold on;
            chanStart = (figIdx - 1) * chanFigure + 1;
            chanEnd = min(figIdx * chanFigure, numChan);

            for chanIdx = chanStart:chanEnd
                % Make subplot
                subplot(numRows, numCols, chanIdx - chanStart + 1);
                hold on;

                for plotResultIdx = 1:numel(groupNames)

                    % Assign a color for the current plot
                    currentColor = colors(plotResultIdx, :);

                    % Assign results
                    plotMean = resultToPlotMean{plotResultIdx};
                    plotSEM = resultToPlotSEM{plotResultIdx};

                    % Plot SEM
                    if plotSem
                        fill([axisTime, fliplr(axisTime)], ...
                            [plotMean(chanIdx, :) + plotSEM(chanIdx, :), ...
                             fliplr(plotMean(chanIdx, :) - plotSEM(chanIdx, :))], ...
                            currentColor, 'FaceAlpha', .1, 'linestyle', 'none');
                    end

                    % Plot Mean
                    plot(axisTime, plotMean(chanIdx, :), 'Color', currentColor, 'LineWidth', 1.5);
                end

                % Add labels and format for subplots
                xlim([axisTime(1) axisTime(end)]);
                xlabel('Time (ms)');
                xline(0, '--', 'Color', 'k', 'Alpha', 0.8);

                ylabel('Amplitude (\muV)');
                yline(0, '--', 'Color', 'k', 'Alpha', 0.8);

                title(chanLabels{chanIdx});

                % Add func for bigger plot
                set(gca, 'ButtonDownFcn', @(src, event)expandPlot(axisTime, resultToPlotMean, resultToPlotSEM, colors, chanIdx, chanLabels{chanIdx}, legendLabels, plotSem));

                hold off;
            end

            % Add main title
            sgtitle('Group vs Group ERPs');
        end

    end

    %% Check for cond vs cond
    if ismember(2, plotOptionsSelection)
        % Load msg
        fprintf("Loading Condition vs Condition plot...\n");

        % Transform data for plot
        if ~exist("conditionDataMean", "var")
            % Loop through conds
            for conditionPlotIdx = 1:numel(conditionNames)
                loadConditionName = strrep(conditionNames{conditionPlotIdx}, ' ', '');
                displacement = 1;

                % Loop through groups
                for groupPlotIdx = 1:numel(groupNames)
                    loadGroupName = strrep(groupNames{groupPlotIdx}, ' ', '');

                    % Loop through data points
                    for groupDataIdx = 1:numel(ALLEEGDATA.(loadGroupName).(loadConditionName))
                        conditionDataMean{displacement, conditionPlotIdx} = ALLEEGDATA.(loadGroupName).(loadConditionName)(groupDataIdx).meanData;
                        displacement = displacement + 1;
                    end

                end

            end

        end

        % Get mean and SEM
        resultToPlotMean = cell(1, numel(conditionNames));
        resultToPlotSEM = cell(1, numel(conditionNames));

        for resultIdx = 1:numel(conditionNames)
            % Get the indices of non-empty cells
            nonEmptyIndicesMean = ~cellfun(@isempty, conditionDataMean(:, resultIdx));

            % Extract non-empty cells
            resultMean = conditionDataMean(nonEmptyIndicesMean, resultIdx);

            % Average subjects
            resultMean = cat(3, resultMean{:});
            resultToPlotSEM{resultIdx} = std(resultMean, 0, 3) ./ sqrt(size(resultMean, 3));
            resultToPlotMean{resultIdx} = mean(resultMean, 3);
        end

        % Plot
        % Set subplots per fig
        numRows = 6;
        numCols = 6;
        chanFigure = numRows * numCols;

        % Set amount of colors
        colors = lines(numel(conditionNames));

        % Define and fill legend
        legendLabels = strings(1, 2 * numel(conditionNames));
        legendLabels(2:2:end) = conditionNames;

        % Loop through chans
        for figIdx = 1:ceil(numChan / chanFigure)
            figure;
            hold on;
            chanStart = (figIdx - 1) * chanFigure + 1;
            chanEnd = min(figIdx * chanFigure, numChan);

            for chanIdx = chanStart:chanEnd
                % Make subplot
                subplot(numRows, numCols, chanIdx - chanStart + 1);
                hold on;

                for plotResultIdx = 1:numel(conditionNames)

                    % Assign a color for the current plot
                    currentColor = colors(plotResultIdx, :);

                    % Assign results
                    plotMean = resultToPlotMean{plotResultIdx};
                    plotSEM = resultToPlotSEM{plotResultIdx};

                    % Plot SEM
                    if plotSem
                        fill([axisTime, fliplr(axisTime)], ...
                            [plotMean(chanIdx, :) + plotSEM(chanIdx, :), ...
                             fliplr(plotMean(chanIdx, :) - plotSEM(chanIdx, :))], ...
                            currentColor, 'FaceAlpha', .1, 'linestyle', 'none');
                    end

                    % Plot Mean
                    plot(axisTime, plotMean(chanIdx, :), 'Color', currentColor, 'LineWidth', 1.5);
                end

                % Add labels and format for subplots
                xlim([axisTime(1) axisTime(end)]);
                xlabel('Time (ms)');
                xline(0, '--', 'Color', 'k', 'Alpha', 0.8);

                ylabel('Amplitude (\muV)');
                yline(0, '--', 'Color', 'k', 'Alpha', 0.8);

                title(chanLabels{chanIdx});

                % Add func for bigger plot
                set(gca, 'ButtonDownFcn', @(src, event)expandPlot(axisTime, resultToPlotMean, resultToPlotSEM, colors, chanIdx, chanLabels{chanIdx}, legendLabels, plotSem));
                hold off;
            end

            % Add main title
            sgtitle('Condition vs Condition ERPs');
        end

    end

    %% Check for group vs cond
    if ismember(3, plotOptionsSelection)
        % Load msg
        fprintf("Loading Group vs Condition plot...\n");

        % Transform data for plot
        if ~exist("groupConditionDataMean", "var")
            % Preallocate
            groupConditionDataMean = cell(numel(groupNames), numel(conditionNames));

            % Loop through conds
            for conditionPlotIdx = 1:numel(conditionNames)
                loadConditionName = strrep(conditionNames{conditionPlotIdx}, ' ', '');

                % Loop through groups
                for groupPlotIdx = 1:numel(groupNames)
                    loadGroupName = strrep(groupNames{groupPlotIdx}, ' ', '');

                    % Loop through data points
                    for groupDataIdx = 1:numel(ALLEEGDATA.(loadGroupName).(loadConditionName))
                        groupConditionDataMean{groupPlotIdx, conditionPlotIdx} = cat(3, groupConditionDataMean{groupPlotIdx, conditionPlotIdx}, ...
                            ALLEEGDATA.(loadGroupName).(loadConditionName)(groupDataIdx).meanData);
                    end

                end

            end

        end

        % Get mean and SEM
        resultToPlotMean = cell(numel(groupNames), numel(conditionNames));
        resultToPlotSEM = cell(numel(groupNames), numel(conditionNames));

        for resultIdxRow = 1:numel(groupNames)

            for resultIdx = 1:numel(conditionNames)

                % Extract non-empty cells
                resultMean = groupConditionDataMean{resultIdxRow, resultIdx};

                % Average subjects
                resultToPlotSEM{resultIdxRow, resultIdx} = std(resultMean, 0, 3) ./ sqrt(size(resultMean, 3));
                resultToPlotMean{resultIdxRow, resultIdx} = mean(resultMean, 3);
            end

        end

        % Plot
        % Set subplots per fig
        numRows = 6;
        numCols = 6;
        chanFigure = numRows * numCols;

        % Set amount of colors and line styles
        colors = lines(numel(groupNames));
        lineStyles = {'-', '--', ':', '-.', 'o-', '*-', 's-', '+-', 'x-', '^-', '>-', '<-', 'v-', 'p-', 'h-'};

        % Define and fill legend
        legendLabels = strings(1, 2 * numel(groupNames) * numel(conditionNames));
        legendIdx = 1;

        for groupIdx = 1:numel(groupNames)

            for condIdx = 1:numel(conditionNames)
                legendLabels(legendIdx * 2) = [groupNames{groupIdx}, ' - ', conditionNames{condIdx}];
                legendIdx = legendIdx + 1;
            end

        end

        % Loop through chans
        for figIdx = 1:ceil(numChan / chanFigure)
            figure;
            hold on;
            chanStart = (figIdx - 1) * chanFigure + 1;
            chanEnd = min(figIdx * chanFigure, numChan);

            for chanIdx = chanStart:chanEnd
                % Make subplot
                subplot(numRows, numCols, chanIdx - chanStart + 1);
                hold on;

                for plotResultIdxRow = 1:numel(groupNames)
                    % Assign a color for the current plot
                    currentColor = colors(plotResultIdxRow, :);

                    for plotResultIdx = 1:numel(conditionNames)

                        % Set line style
                        currentLine = lineStyles{plotResultIdx};

                        % Assign results
                        plotMean = resultToPlotMean{plotResultIdxRow, plotResultIdx};
                        plotSEM = resultToPlotSEM{plotResultIdxRow, plotResultIdx};

                        % Plot SEM
                        if plotSem
                            fill([axisTime, fliplr(axisTime)], ...
                                [plotMean(chanIdx, :) + plotSEM(chanIdx, :), ...
                                 fliplr(plotMean(chanIdx, :) - plotSEM(chanIdx, :))], ...
                                currentColor, 'FaceAlpha', .1, 'linestyle', 'none');
                        end

                        % Plot Mean
                        plot(axisTime, plotMean(chanIdx, :), currentLine, 'Color', currentColor, 'LineWidth', 1.5);
                    end

                end

                % Add labels and format for subplots
                xlim([axisTime(1) axisTime(end)]);
                xlabel('Time (ms)');
                xline(0, '--', 'Color', 'k', 'Alpha', 0.8);

                ylabel('Amplitude (\muV)');
                yline(0, '--', 'Color', 'k', 'Alpha', 0.8);

                title(chanLabels{chanIdx});

                % Add func for bigger plot
                set(gca, 'ButtonDownFcn', @(src, event)expandPlot(axisTime, resultToPlotMean, resultToPlotSEM, colors, chanIdx, ...
                    chanLabels{chanIdx}, legendLabels, plotSem, lineStyles));
                hold off;
            end

            % Add main title
            sgtitle('Group and Condition ERPs');
        end

    end

    %% Wait for user to finish inspecting ERP plots
    if ~isempty(findall(0, 'Type', 'figure', 'Visible', 'on')), uiwait(gcf); end

    %% Check for topoplot
    if ismember(4, plotOptionsSelection)
        % Transform data for plot
        if ~exist("groupConditionDataMean", "var")
            % Preallocate
            topoData = cell(numel(groupNames), numel(conditionNames));

            % Loop through conds
            for conditionPlotIdx = 1:numel(conditionNames)
                loadConditionName = strrep(conditionNames{conditionPlotIdx}, ' ', '');

                % Loop through groups
                for groupPlotIdx = 1:numel(groupNames)
                    loadGroupName = strrep(groupNames{groupPlotIdx}, ' ', '');

                    % Loop through data points
                    for groupDataIdx = 1:numel(ALLEEGDATA.(loadGroupName).(loadConditionName))
                        topoData{groupPlotIdx, conditionPlotIdx} = cat(3, topoData{groupPlotIdx, conditionPlotIdx}, ...
                            ALLEEGDATA.(loadGroupName).(loadConditionName)(groupDataIdx).meanData);
                    end

                end

            end

        else
            topoData = groupConditionDataMean;
        end

        % Fuse all data into one
        topoDataMean = mean(cat(3, topoData{:}), 3);

        % Ask for parameters
        while true
            topoParams = inputdlg({'Enter time window start in ms', 'Enter time window end in ms'}, 'Topoplot Parameters', 1, {'100', '200'});
            topoTimeWin = str2double(topoParams);
            if isempty(topoTimeWin) || any(isnan(topoTimeWin)), fprintf("Enter valid numeric value.\n"); else, break, end
        end

        % Find the closest indices
        [~, startTimeWin] = min(abs(axisTime - topoTimeWin(1)));
        [~, endTimeWin] = min(abs(axisTime - topoTimeWin(2)));

        % Extract time window from data
        resultToTopo = mean(topoDataMean(:, startTimeWin:endTimeWin), 2);

        % Make title
        topoTitle = sprintf('%d ms to %d ms time window', topoTimeWin(1), topoTimeWin(2));

        % Check if eeglab is initialized and plot
        if ~exist("ALLEEG", "var"), eeglab('nogui'); end
        figure;
        topoplot(resultToTopo, chanlocs, 'electrodes', 'labels');

        title(topoTitle);
        colorbar;
        set(gca, 'FontSize', 10);
        set(findall(gcf, 'type', 'text'), 'FontSize', 10);
    end

    %% Wait for user to finish inspecting topoplot
    if ~isempty(findall(0, 'Type', 'figure', 'Visible', 'on')), uiwait(gcf); end

    %% Check for animated topoplot
    if ismember(5, plotOptionsSelection)

        % Ask to save movie
        save2D = questdlg('Do you wish to save this 2D movie?', 'Save 2D Movie', 'Yes', 'No', 'No');

        if strcmpi(save2D, 'yes')
            save2Dpath = uigetdir(pwd, 'Select folder to save 2D movie');
        end

        % Transform data for plot
        if ~exist("groupConditionDataMean", "var")
            % Preallocate
            topoData = cell(numel(groupNames), numel(conditionNames));

            % Loop through conds
            for conditionPlotIdx = 1:numel(conditionNames)
                loadConditionName = strrep(conditionNames{conditionPlotIdx}, ' ', '');

                % Loop through groups
                for groupPlotIdx = 1:numel(groupNames)
                    loadGroupName = strrep(groupNames{groupPlotIdx}, ' ', '');

                    % Loop through data points
                    for groupDataIdx = 1:numel(ALLEEGDATA.(loadGroupName).(loadConditionName))
                        topoData{groupPlotIdx, conditionPlotIdx} = cat(3, topoData{groupPlotIdx, conditionPlotIdx}, ...
                            ALLEEGDATA.(loadGroupName).(loadConditionName)(groupDataIdx).meanData);
                    end

                end

            end

        else
            topoData = groupConditionDataMean;
        end

        % Fuse all data into one
        topoDataMean = cat(3, topoData{:});

        % Ask for parameters
        while true
            movie2DParams = inputdlg({'Enter time window start in ms', 'Enter time window end in ms'}, '2D Topoplot Movie Parameters', 1, {'-100', '600'});
            movie2DParams = str2double(movie2DParams);
            if isempty(movie2DParams) || any(isnan(movie2DParams)), fprintf("Enter valid numeric value.\n"); else, break, end
        end

        % Above, convert latencies in ms to data point indices
        pnts1 = round(eeg_lat2point(movie2DParams(1) / 1000, 1, srate, [min(axisTime) max(axisTime)]));
        pnts2 = round(eeg_lat2point(movie2DParams(2) / 1000, 1, srate, [min(axisTime) max(axisTime)]));
        scalpERP = mean(topoDataMean(:, pnts1:pnts2), 3);

        % Smooth data
        for iChan = 1:size(scalpERP, 1)
            scalpERP(iChan, :) = conv(scalpERP(iChan, :), ones(1, 5) / 5, 'same');
        end

        % Check if eeglab is initialized
        if ~exist("ALLEEG", "var"), eeglab('nogui'); end

        % 2-D movie
        figure;
        [Movie2D, Colormap] = eegmovie(scalpERP, srate, chanlocs, 'framenum', 'off', 'vert', 0, 'startsec', movie2DParams(1) / 1000, 'topoplotopt', {'numcontour' 0});
        seemovie(Movie2D, -5, Colormap);

        % Save movie
        if strcmpi(save2D, 'yes')
            movie2Dname = fullfile(save2Dpath, 'erpmovie2d.mp4');
            Movie2DObj = VideoWriter(movie2Dname, 'MPEG-4');
            open(Movie2DObj);
            writeVideo(Movie2DObj, Movie2D);
            close(Movie2DObj);
        end

        % Delete temp files
        delete('tmp_file.loc');
    end

    %% Check for 3D topoplot movie
    if ismember(6, plotOptionsSelection)

        % Ask to save movie
        save3D = questdlg('Do you wish to save this 3D movie?', 'Save 3D Movie', 'Yes', 'No', 'No');

        if strcmpi(save3D, 'yes')
            save3Dpath = uigetdir(pwd, 'Select folder to save 3D movie');
        end

        % Transform data for plot
        if ~exist("groupConditionDataMean", "var")
            % Preallocate
            topoData = cell(numel(groupNames), numel(conditionNames));

            % Loop through conds
            for conditionPlotIdx = 1:numel(conditionNames)
                loadConditionName = strrep(conditionNames{conditionPlotIdx}, ' ', '');

                % Loop through groups
                for groupPlotIdx = 1:numel(groupNames)
                    loadGroupName = strrep(groupNames{groupPlotIdx}, ' ', '');

                    % Loop through data points
                    for groupDataIdx = 1:numel(ALLEEGDATA.(loadGroupName).(loadConditionName))
                        topoData{groupPlotIdx, conditionPlotIdx} = cat(3, topoData{groupPlotIdx, conditionPlotIdx}, ...
                            ALLEEGDATA.(loadGroupName).(loadConditionName)(groupDataIdx).meanData);
                    end

                end

            end

        else
            topoData = groupConditionDataMean;
        end

        % Fuse all data into one
        topoDataMean = cat(3, topoData{:});

        % Ask for parameters
        while true
            movie3DParams = inputdlg({'Enter time window start in ms', 'Enter time window end in ms'}, '3D Topoplot Movie Parameters', 1, {'-100', '600'});
            movie3DParams = str2double(movie3DParams);
            if isempty(movie3DParams) || any(isnan(movie3DParams)), fprintf("Enter valid numeric value.\n"); else, break, end
        end

        % Use the graphic interface to coregister your head model with your electrode positions
        % Select one of two head models
        headplotparams = {'meshfile', 'mheadnew.mat', 'transform', [0.664455 -3.39403 -14.2521 -0.00241453 0.015519 -1.55584 11 10.1455 12]};
        % headplotparams = { 'meshfile', 'colin27headmesh.mat', 'transform', [0          -13            0          0.1            0        -1.57         11.7         12.5           12] };

        % set up the spline file
        headplot('setup', chanlocs, 'STUDY_headplot.spl', headplotparams{:});
        close;

        % Convert latencies in ms to data point indices
        pnts1 = round(eeg_lat2point(movie3DParams(1) / 1000, 1, srate, [min(axisTime) max(axisTime)]));
        pnts2 = round(eeg_lat2point(movie3DParams(2) / 1000, 1, srate, [min(axisTime) max(axisTime)]));
        scalpERP = mean(topoDataMean(:, pnts1:pnts2), 3);

        % Smooth data
        for iChan = 1:size(scalpERP, 1)
            scalpERP(iChan, :) = conv(scalpERP(iChan, :), ones(1, 5) / 5, 'same');
        end

        % Check if eeglab is initialized
        if ~exist("ALLEEG", "var"), eeglab('nogui'); end

        % 3-D movie
        figure('color', 'w');
        [Movie3D, Colormap] = eegmovie(scalpERP, srate, chanlocs, 'framenum', 'off', 'vert', 0, 'startsec', movie3DParams(1) / 1000, 'mode', '3d', 'headplotopt', {headplotparams{:}, 'material', 'metal'}, 'camerapath', [-127 2 30 0]);

        seemovie(Movie3D, -5, Colormap);

        % Save movie
        if strcmpi(save3D, 'yes')
            movie3Dname = fullfile(save3Dpath, 'erpmovie3d.mp4');
            Movie3DObj = VideoWriter(movie3Dname, 'MPEG-4');
            open(Movie3DObj);
            writeVideo(Movie3DObj, Movie3D);
            close(Movie3DObj);
        end

        % Delete temp files
        delete('STUDY_headplot.spl', 'tmp.spl', 'tmp_file.loc');
    end

    %% Ask to continue plotting
    plotMore = questdlg('Do you wish to make a different plot or continue?', 'Plot More', 'Plot', 'Continue', 'Continue');
    if strcmpi(plotMore, 'continue'), break, end
end

%% Ask to save current ALLEEG
saveALLEEG = questdlg('Do you wish to save current data?', 'Save Data', 'Yes', 'No', 'Yes');

if strcmp(saveALLEEG, 'Yes')
    saveALLEEGPath = uigetdir(pwd, 'Select folder to save current dataset');
    save(fullfile(saveALLEEGPath, "ALLEEGDATA"), "ALLEEGDATA");
end

%% Export to SPSS

% Ask to export
exportPrompt = questdlg('Do you wish to export data to SPSS/Excel?', 'Data Export', 'Yes', 'No', 'Yes');

if strcmp(exportPrompt, 'Yes')
    % Determine feature to export from data
    while true
        featureOptions = {'Average Amplitude', 'Latency', 'Peak Amplitude', 'Timepoints'};
        [featureSelection, ~] = listdlg('ListString', featureOptions, 'PromptString', 'Select feature extraction:', 'SelectionMode', 'multiple');

        if ~isempty(featureSelection), break, end
    end

    feature = featureOptions(featureSelection);

    % Ask for time win
    while true
        exportTimeWin = inputdlg({'Enter the start of the time window (ms) to export', 'Enter the end of the time window (ms) to export'}, 'Export Time Window', 1, {'100', '200'});
        exportTimeWin = str2double(exportTimeWin);
        if isempty(exportTimeWin) || any(isnan(exportTimeWin)), fprintf("Enter valid numeric value.\n"); else, break, end
    end

    % Get savepath
    saveTableSPSSPath = uigetdir(pwd, 'Select folder to save the exported dataset');
    if saveTableSPSSPath == 0, saveTableSPSSPath = pwd; end
    fprintf('Exported data will be saved to:\n %s\n', saveTableSPSSPath);

    % Call export func and pass params
    exportSPSS(ALLEEGDATA, exportTimeWin, axisTime, chanLabels, feature, saveTableSPSSPath);

else
    % Display completion
    fprintf("\n------- Process Completed -------\n");
    fprintf("All tasks have been successfully completed. You may now close the program.\n");
    fprintf("\n\t\t  /\\_/\\ \t  /\\_/\\ \n\t\t ( o.o )\t ( ^.^ )\n\t\t  > ^ <\t\t  > ^ <\n");
end
