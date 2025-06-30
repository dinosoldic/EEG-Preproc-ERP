% 
% exportSPSS Export EEG data summary to SPSS-compatible CSV and label files.
%
%   exportSPSS(ALLEEGDATA, exportTimeWin, timeVector, chanLabels) exports
%   average amplitude or latency data from ALLEEGDATA into a CSV file formatted
%   for use in SPSS, JASP, JAMOVI, or any other statistical analysis software,
%   along with a text file containing variable label information.
%
%   Inputs:
%     ALLEEGDATA     - Struct containing EEG data organized by groups and conditions.
%     exportTimeWin  - 1x2 vector specifying the start and end (in milliseconds) 
%                      of the time window to average and export.
%     timeVector     - Vector of time points corresponding to the EEG data samples.
%     chanLabels     - Cell array of channel label strings.
%
%   Outputs:
%     - 'erpdataset_amplitude.csv': CSV file with exported amplitude data, suitable for SPSS import.
%     - 'erpdataset_latency.csv': CSV file with exported latency data, suitable for SPSS import.
%     - 'erpdatalabels.txt': Text file containing group codes, selected time window,
%                            and channel names.
%
%   If any input is omitted, the function will prompt the user to select or enter
%   the required data interactively.
%
%   Example usage:
%       exportSPSS(ALLEEGDATA);
%       exportSPSS(ALLEEGDATA, [100 200]);
%       exportSPSS(ALLEEGDATA, [100 200], EEG.times);
%       exportSPSS(ALLEEGDATA, [100 200], EEG.times, {EEG.chanlocs.labels});
%
%   Author: Dino Soldic
%   Email: dino.soldic@urjc.es
%   Date: 2025-06-30
%
%   See also: eegPreproc, eegPlotERP, EEGLAB

function exportSPSS(ALLEEGDATA, exportTimeWin, timeVector, chanLabels, feature, saveTableSPSSPath)
% Check for argins
if nargin < 1
    % Ask for dataset
    [ALLEEGFile, ALLEEGPath] = uigetfile('*.mat', 'Select file containing dataset');
    if ALLEEGFile == 0, error("Operation cancelled by user"); end
    load(fullfile(ALLEEGPath, ALLEEGFile));
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
    load(fullfile(timeVectorPath, timeVectorFile));

    % Extract time vector
    timeVector = EEG.times;
end
if nargin < 4
    if ~exist("EEG", "var")
        [chanLabelsFile, chanLabelsPath] = uigetfile('*.mat', 'Select file containing EEG.times or the time vector');
        if chanLabelsFile == 0, error("Operation cancelled by user"); end
        load(fullfile(chanLabelsPath, chanLabelsFile));
    end

    % Extract chanlabels
    chanLabels = {EEG.chanlocs.labels};
end
if nargin < 5
    feature = questdlg('Do you wish to export peak latency or average peak amplitude?', 'Feature to export', 'Latency', 'Amplitude', 'All', 'Amplitude');
    if isempty(feature), error('You need to select a feature to be extracted from the EEG data'); end
    if strcmp(feature, 'Latency'), feature = 1; elseif strcmp(feature, 'Amplitude'), feature = 2; else feature = 3; end
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
groupNum = 1 : numel(groupFields);

% Get amount of chans in data
numChan = size(ALLEEGDATA.(groupFields{1}).(conditionFields{1})(1).meanData, 1);

% Initialize vars
groupDisplacement = 0;
tableDataAmp = {};
tableDataLat = {};

% Transform to table
% Loop through groups
for groupFieldsIdx = 1 : numel(groupFields)
    groupField = groupFields{groupFieldsIdx};

    % Loop through conds
    for conditionFieldsIdx = 1 : numel(conditionFields)
        conditionField = conditionFields{conditionFieldsIdx};

        % Loop through subjs
        for dataIdx = 1 : numel(ALLEEGDATA.(groupField).(conditionField))

            % Get data from struct
            dataToTable = ALLEEGDATA.(groupField).(conditionField)(dataIdx).meanData;

            % Extract time win
            [~, exportStartTimeWin] = min(abs(timeVector - exportTimeWin(1))); % closest to 0 is the desired idx. Accounts for time(ms) not being in timeVector.
            [~, exportEndTimeWin] = min(abs(timeVector - exportTimeWin(2)));

            if feature == 1 || feature == 3
                % Set up displacement for each cond
                displacement = 3 + (conditionFieldsIdx - 1) * numChan;

                dataToTableAmp = mean(dataToTable(:, exportStartTimeWin : exportEndTimeWin), 2);

                % Populate subj code
                tableDataAmp{dataIdx + groupDisplacement, 1} = dataIdx + groupDisplacement;

                % Populate group code
                tableDataAmp{dataIdx + groupDisplacement, 2} = groupNum(groupFieldsIdx);

                % Populate voltages
                for dataPointIdx = 1 : numChan
                    tableDataAmp{dataIdx + groupDisplacement, displacement} = dataToTableAmp(dataPointIdx);

                    displacement = displacement + 1;
                end
            end
            if feature == 2 || feature == 3
                % Set up displacement for each cond
                displacement = 3 + (conditionFieldsIdx - 1) * numChan;

                % find timepoint with max voltage
                [~, maxIndices] = max(dataToTable(:, exportStartTimeWin : exportEndTimeWin), [], 2);
                timeVectorLat = timeVector(exportStartTimeWin : exportEndTimeWin);
                dataToTableLat = timeVectorLat(maxIndices);   

                % Populate subj code
                tableDataLat{dataIdx + groupDisplacement, 1} = dataIdx + groupDisplacement;

                % Populate group code
                tableDataLat{dataIdx + groupDisplacement, 2} = groupNum(groupFieldsIdx);

                % Populate voltages
                for dataPointIdx = 1 : numChan
                    tableDataLat{dataIdx + groupDisplacement, displacement} = dataToTableLat(dataPointIdx);

                    displacement = displacement + 1;
                end
            end

            
        end
    end
    % Refresh displacement for groups
    groupDisplacement = size(tableDataAmp, 1);
end

%% Make table 
% header
tableHeader = cell(1, 2 + numChan * numel(conditionFields));

tableHeader{1} = "Subject";
tableHeader{2} = "Group";
headerDisplacement = 1;

for tableHeaderIdx = 1 : numel(conditionFields)
    for chanLabelIdx = 1 : numChan
        tableHeader{2 + headerDisplacement} = [chanLabels{chanLabelIdx}, '_', conditionFields{tableHeaderIdx}];
        headerDisplacement = headerDisplacement + 1;
    end
end

% Data and save
if feature == 1 || feature == 3
    tableSPSSAmp = cell2table(tableDataAmp, 'VariableNames', string(tableHeader));
    writetable(tableSPSSAmp, fullfile(saveTableSPSSPath, 'erpdataset_amplitude.csv'));
end
if feature ==2 || feature == 3
    tableSPSSLat = cell2table(tableDataLat, 'VariableNames', string(tableHeader));
    writetable(tableSPSSLat, fullfile(saveTableSPSSPath, 'erpdataset_latency.csv'));
end

% Copy labels to txt
labelsFile = fullfile(saveTableSPSSPath, 'erpdatalabels.txt');

fid = fopen(labelsFile, 'w');
for groupLabelIdx = 1 : numel(groupFields)
    fprintf(fid, "Group %s : code %d\n", groupFields{groupLabelIdx}, groupLabelIdx);
end
fprintf(fid, "Selected time window (ms): %d-%d\n", exportTimeWin(1), exportTimeWin(2));
fprintf(fid, "Selected channels:\n");
for chanLabelIdx = 1 : numel(chanLabels)
    fprintf(fid, "%s\n", chanLabels{chanLabelIdx});
end
fclose(fid);

%% Display completion
fprintf("\n------- Process Completed -------\n");
fprintf("All tasks have been successfully completed. You may now close the program.\n");
fprintf("\n\t\t  /\\_/\\ \t  /\\_/\\ \n\t\t ( o.o )\t ( ^.^ )\n\t\t  > ^ <\t\t  > ^ <\n");
end