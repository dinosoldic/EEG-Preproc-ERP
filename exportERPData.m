%
% exportERPData Export EEG data summary to SPSS-compatible CSV and label files.
%
%   exportERPData(ALLEEGDATA, exportTimeWin, timeVector, chanLabels, feature, saveTableSPSSPath)
%   exports selected EEG features from ALLEEGDATA into CSV files formatted
%   for use in SPSS, JASP, JAMOVI, or any other statistical analysis software,
%   along with a text file containing variable label information.
%
%   Supported feature types (passed in 'feature'):
%     - 'Average Amplitude' : mean voltage in the specified time window
%     - 'Latency'           : latency of the maximum voltage in the time window
%     - 'Peak Amplitude'    : absolute peak voltage (largest magnitude, positive or negative)
%     - 'Timepoints'        : full timecourse data within the selected time window
%
%   Inputs:
%     ALLEEGDATA     - Struct containing EEG data organized by groups and conditions.
%     exportTimeWin  - 1x2 vector specifying the start and end (in milliseconds)
%                      of the time window to average and export.
%     timeVector        - Vector of time points corresponding to the EEG data samples.
%     chanLabels        - Cell array of channel label strings.
%     feature           - Cell array or string array of features to extract (see supported types above)
%     saveTableSPSSPath - Path to folder where CSV and label files will be saved.
%
%   Outputs:
%     - 'erpdataset_avg_amplitude.csv' : CSV file with average amplitude data
%     - 'erpdataset_latency.csv'       : CSV file with latency data
%     - 'erpdataset_peak_amplitude.csv': CSV file with peak amplitude data
%     - 'erpdataset_timepoints.csv'    : CSV file with timecourse data
%     - 'erpdatalabels.txt'            : Text file containing group codes, time window, and channel names
%     - LORETA folder structure        : Folder containing .asc files with LORETA data
%
%   If any input is omitted, the function will prompt the user to select or enter
%   the required data interactively.
%
%   Example usage:
%       exportERPData(ALLEEGDATA);
%       exportERPData(ALLEEGDATA, [100 200]);
%       exportERPData(ALLEEGDATA, [100 200], EEG.times);
%       exportERPData(ALLEEGDATA, [100 200], EEG.times, {EEG.chanlocs.labels});
%       exportERPData(ALLEEGDATA, [100 200], EEG.times, {EEG.chanlocs.labels}, ["Latency", "Peak Amplitude"]);
%
%   Author: Dino Soldic
%   Email: dino.soldic@urjc.es
%   Date: 2025-10-06
%
%   See also: eegPreproc, eegPlotERP, EEGLAB

function exportERPData(ALLEEGDATA, exportTimeWin, timeVector, chanLabels, feature, saveTableSPSSPath)
    % Check for argins
    if nargin < 1
        % Ask for dataset
        [ALLEEGFile, ALLEEGPath] = uigetfile('*.mat', 'Select file containing dataset');
        if ALLEEGFile == 0, error("Operation cancelled by user"); end
        load(fullfile(ALLEEGPath, ALLEEGFile), "ALLEEGDATA");
    end

    if nargin < 2
        % Ask for time win
        while true
            exportTimeWin = inputdlg({'Enter the start of the time window (ms) to export', 'Enter the end of the time window (ms) to export'}, 'Export Time Window', 1, {'100', '200'});
            exportTimeWin = str2double(exportTimeWin);
            if isempty(exportTimeWin) || any(isnan(exportTimeWin)), fprintf("Enter valid numeric value.\n"); else, break, end
        end

    end

    if nargin < 3
        % Ask for EEG.times
        [timeVectorFile, timeVectorPath] = uigetfile('*.mat', 'Select file containing EEG.times or the time vector');
        if timeVectorFile == 0, error("Operation cancelled by user"); end
        load(fullfile(timeVectorPath, timeVectorFile), "EEG");

        % Extract time vector
        timeVector = EEG.times;
    end

    if nargin < 4

        if ~exist("EEG", "var")
            [chanLabelsFile, chanLabelsPath] = uigetfile('*.mat', 'Select file containing EEG.times or the time vector');
            if chanLabelsFile == 0, error("Operation cancelled by user"); end
            load(fullfile(chanLabelsPath, chanLabelsFile), "EEG");
        end

        % Extract chanlabels
        chanLabels = {EEG.chanlocs.labels};
    end

    if nargin < 5
        featureOptions = {'Average Amplitude', 'Latency', 'Peak Amplitude', 'Timepoints', 'LORETA'};
        [featureSelection, ~] = listdlg('ListString', featureOptions, 'PromptString', 'Select feature extraction:', 'SelectionMode', 'multiple');
        feature = featureOptions(featureSelection);

        if isempty(feature), error('You need to select a feature to be extracted from the EEG data'); end
    end

    if nargin < 6
        saveTableSPSSPath = uigetdir(pwd, 'Select folder to save the exported dataset');
        if saveTableSPSSPath == 0, saveTableSPSSPath = pwd; end
        fprintf('Exported data will be saved to:\n %s\n', saveTableSPSSPath);
    end

    %% Convert data to SPSS format
    % Get fieldnames and sub names
    groupFields = fieldnames(ALLEEGDATA);
    conditionFields = fieldnames(ALLEEGDATA.(groupFields{1}));

    % Set up group code
    groupNum = 1:numel(groupFields);

    % Get amount of chans in data
    numChan = size(ALLEEGDATA.(groupFields{1}).(conditionFields{1})(1).meanData, 1);

    % Initialize vars
    featuresToCheck = ["Latency", "Average Amplitude", "Peak Amplitude", "LORETA"];
    groupDisplacement = 0;
    groupDisplacementTmpts = 0;
    tableDataAmp = cell(1); % these init to remove MATLAB msg
    tableDataLat = cell(1);
    tableDataPeak = cell(1);
    tableDataTmpts = cell(1);

    if any(ismember("LORETA", feature)), isLORETAExp = true; else, isLORETAExp = false; end

    % Transform to table
    % Loop through groups
    for groupFieldsIdx = 1:numel(groupFields)
        groupField = groupFields{groupFieldsIdx};

        if isLORETAExp
            loretaPathGrp = fullfile(saveTableSPSSPath, "erp_LORETA", groupField);
            if ~isfolder(loretaPathGrp), mkdir(loretaPathGrp); end
        end

        % Loop through conds
        for conditionFieldsIdx = 1:numel(conditionFields)
            conditionField = conditionFields{conditionFieldsIdx};

            if isLORETAExp
                loretaPathCond = fullfile(loretaPathGrp, conditionField);
                if ~isfolder(loretaPathCond), mkdir(loretaPathCond); end
            end

            if any(ismember(featuresToCheck, feature))

                % Loop through subjs
                for dataIdx = 1:numel(ALLEEGDATA.(groupField).(conditionField))

                    % Get data from struct
                    if ~isLORETAExp, dataToTable = ALLEEGDATA.(groupField).(conditionField)(dataIdx).meanData; end

                    % Extract time win
                    [~, exportStartTimeWin] = min(abs(timeVector - exportTimeWin(1))); % closest to 0 is the desired idx. Accounts for time(ms) not being in timeVector.
                    [~, exportEndTimeWin] = min(abs(timeVector - exportTimeWin(2)));

                    % Latency
                    if ismember("Latency", feature)
                        % Set up displacement for each cond
                        displacement = 3 + (conditionFieldsIdx - 1) * numChan;

                        % find timepoint with max voltage
                        [~, maxIndices] = max(dataToTable(:, exportStartTimeWin:exportEndTimeWin), [], 2);
                        timeVectorLat = timeVector(exportStartTimeWin:exportEndTimeWin);
                        dataToTableLat = timeVectorLat(maxIndices);

                        % Populate subj code
                        tableDataLat{dataIdx + groupDisplacement, 1} = dataIdx + groupDisplacement;

                        % Populate group code
                        tableDataLat{dataIdx + groupDisplacement, 2} = groupNum(groupFieldsIdx);

                        % Populate
                        for dataPointIdx = 1:numChan
                            tableDataLat{dataIdx + groupDisplacement, displacement} = dataToTableLat(dataPointIdx);

                            displacement = displacement + 1;
                        end

                    end

                    % Avg Amplitude
                    if ismember("Average Amplitude", feature)
                        % Set up displacement for each cond
                        displacement = 3 + (conditionFieldsIdx - 1) * numChan;

                        dataToTableAmp = mean(dataToTable(:, exportStartTimeWin:exportEndTimeWin), 2);

                        % Populate subj code
                        tableDataAmp{dataIdx + groupDisplacement, 1} = dataIdx + groupDisplacement;

                        % Populate group code
                        tableDataAmp{dataIdx + groupDisplacement, 2} = groupNum(groupFieldsIdx);

                        % Populate
                        for dataPointIdx = 1:numChan
                            tableDataAmp{dataIdx + groupDisplacement, displacement} = dataToTableAmp(dataPointIdx);

                            displacement = displacement + 1;
                        end

                    end

                    % Peak Amplitude
                    if ismember("Peak Amplitude", feature)
                        % Set up displacement for each cond
                        displacement = 3 + (conditionFieldsIdx - 1) * numChan;

                        dataToTablePeakMax = max(dataToTable(:, exportStartTimeWin:exportEndTimeWin), [], 2);
                        dataToTablePeakMin = min(dataToTable(:, exportStartTimeWin:exportEndTimeWin), [], 2);

                        % pick the value with the larger absolute value
                        dataToTablePeak = dataToTablePeakMax;
                        idx = abs(dataToTablePeakMin) > abs(dataToTablePeakMax);
                        dataToTablePeak(idx) = dataToTablePeakMin(idx);
                        dataToTablePeak = single(dataToTablePeak);

                        % Populate subj code
                        tableDataPeak{dataIdx + groupDisplacement, 1} = dataIdx + groupDisplacement;

                        % Populate group code
                        tableDataPeak{dataIdx + groupDisplacement, 2} = groupNum(groupFieldsIdx);

                        % Populate
                        for dataPointIdx = 1:numChan
                            tableDataPeak{dataIdx + groupDisplacement, displacement} = dataToTablePeak(dataPointIdx);

                            displacement = displacement + 1;
                        end

                    end

                    % LORETA
                    if isLORETAExp

                        % Export sub
                        fileName = sprintf('%s\\S_%.2d.asc', loretaPathCond, dataIdx);
                        writematrix(ALLEEGDATA.(groupField).(conditionField)(dataIdx).meanData(:, exportStartTimeWin:exportEndTimeWin)', fileName, 'FileType', 'text', 'Delimiter', '\t');
                    end

                end

            end

            % Timepoints
            if ismember("Timepoints", feature)
                % Get data from struct
                dataToTable = ALLEEGDATA.(groupField).(conditionField)(dataIdx).meanData;

                % Extract time win
                [~, exportStartTimeWin] = min(abs(timeVector - exportTimeWin(1))); % closest to 0 is the desired idx. Accounts for time(ms) not being in timeVector.
                [~, exportEndTimeWin] = min(abs(timeVector - exportTimeWin(2)));

                % Set up displacement for each cond
                displacement = (conditionFieldsIdx - 1) * numChan;

                dataToTableTmpts = dataToTable(:, exportStartTimeWin:exportEndTimeWin);
                nTmpts = size(dataToTableTmpts, 2);

                % Populate
                for dataPointIdx = 1:numChan

                    for dataPointIdxTmpt = 1:nTmpts
                        tableDataTmpts{dataPointIdxTmpt, dataPointIdx + displacement + groupDisplacementTmpts} = dataToTableTmpts(dataPointIdx, dataPointIdxTmpt);
                    end

                end

            end

        end

        % Refresh displacement for groups
        groupDisplacement = size(tableDataAmp, 1);
        groupDisplacementTmpts = size(tableDataTmpts, 2);
    end

    %% Make table
    % header
    tableHeader = cell(1, 2 + numChan * numel(conditionFields));
    tableHeaderTmpts = cell(1, numChan * numel(groupFields) * numel(conditionFields));

    tableHeader{1} = "Subject";
    tableHeader{2} = "Group";
    headerDisplacement = 1;

    for tableHeaderIdx = 1:numel(conditionFields)

        for chanLabelIdx = 1:numChan
            tableHeader{2 + headerDisplacement} = [chanLabels{chanLabelIdx}, '_', conditionFields{tableHeaderIdx}];
            headerDisplacement = headerDisplacement + 1;
        end

    end

    if ismember("Timepoints", feature)
        headerDisplacement = 1;

        for tableHeaderGroupIdx = 1:numel(groupFields)

            for tableHeaderCondIdx = 1:numel(conditionFields)

                for chanLabelIdx = 1:numChan
                    tableHeaderTmpts{headerDisplacement} = [chanLabels{chanLabelIdx}, '_', groupFields{tableHeaderGroupIdx} '_', conditionFields{tableHeaderCondIdx}];
                    headerDisplacement = headerDisplacement + 1;
                end

            end

        end

    end

    % Data and save
    % Latency
    if ismember("Latency", feature)
        tableSPSSLat = cell2table(tableDataLat, 'VariableNames', string(tableHeader));
        writetable(tableSPSSLat, fullfile(saveTableSPSSPath, 'erpdataset_latency.csv'));
    end

    % Avg Amplitude
    if ismember("Average Amplitude", feature)
        tableSPSSAmp = cell2table(tableDataAmp, 'VariableNames', string(tableHeader));
        writetable(tableSPSSAmp, fullfile(saveTableSPSSPath, 'erpdataset_avg_amplitude.csv'));
    end

    % Peak Amplitude
    if ismember("Peak Amplitude", feature)
        tableSPSSPeak = cell2table(tableDataPeak, 'VariableNames', string(tableHeader));
        writetable(tableSPSSPeak, fullfile(saveTableSPSSPath, 'erpdataset_peak_amplitude.csv'));
    end

    % Timepoints
    if ismember("Timepoints", feature)
        tableSPSSTmpts = cell2table(tableDataTmpts, 'VariableNames', string(tableHeaderTmpts));
        writetable(tableSPSSTmpts, fullfile(saveTableSPSSPath, 'erpdataset_timepoints.csv'));
    end

    % Copy labels to txt
    labelsFile = fullfile(saveTableSPSSPath, 'erpdatalabels.txt');

    fid = fopen(labelsFile, 'w');

    for groupLabelIdx = 1:numel(groupFields)
        fprintf(fid, "Group %s : code %d\n", groupFields{groupLabelIdx}, groupLabelIdx);
    end

    fprintf(fid, "Selected time window (ms): %d-%d\n", exportTimeWin(1), exportTimeWin(2));
    fprintf(fid, "Selected channels:\n");

    for chanLabelIdx = 1:numel(chanLabels)
        fprintf(fid, "%s\n", chanLabels{chanLabelIdx});
    end

    fclose(fid);

    %% Display completion
    fprintf("\n------- Process Completed -------\n");
    fprintf("All tasks have been successfully completed. You may now close the program.\n");
    fprintf("\n\t\t  /\\_/\\ \t  /\\_/\\ \n\t\t ( o.o )\t ( ^.^ )\n\t\t  > ^ <\t\t  > ^ <\n");
end
