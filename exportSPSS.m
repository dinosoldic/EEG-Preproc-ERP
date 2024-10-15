function exportSPSS(ALLEEGDATA, exportTimeWin, timeVector, chanLabels)
% exportSPSS(ALLEEGDATA, exportTimeWin, timeVector, chanLabels) exports
% data from ALLEEGDATA to an SPSS-compatible CSV file.
%
% Inputs:
% - ALLEEGDATA: Struct containing EEG data organized by groups and conditions.
% - exportTimeWin: 1x2 vector specifying the start and end in millisencods (ms) of the time window to export.
% - timeVector: Time vector corresponding to the EEG data.
% - chanLabels: Cell array of channel labels.
%
% Output:
% - 'erpdataset.csv' file containing the exported data.
% - 'erpdatalabels.txt' file containing relevant label information.
%
% If any input argument is not provided, the user will be prompted to select
% the necessary file or enter the required information.
%
% Example usage:
%   exportSPSS(ALLEEGDATA);
%   exportSPSS(ALLEEGDATA, [start end]);
%   exportSPSS(ALLEEGDATA, [start end], EEG.times);
%   exportSPSS(ALLEEGDATA, [start end], EEG.times, {EEG.chanlocs.labels});
%
% See also: eegPreproc, eegPlotERP, EEGLAB
%

%% Check for argins
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
tableData = {};

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

            % Set up displacement for each cond
            displacement = 3 + (conditionFieldsIdx - 1) * numChan;

            % Extract time win
            [~, exportStartTimeWin] = min(abs(timeVector - exportTimeWin(1)));
            [~, exportEndTimeWin] = min(abs(timeVector - exportTimeWin(2)));

            dataToTable = mean(dataToTable(:, exportStartTimeWin : exportEndTimeWin), 2);

            % Populate subj code
            tableData{dataIdx + groupDisplacement, 1} = dataIdx + groupDisplacement;

            % Populate group code
            tableData{dataIdx + groupDisplacement, 2} = groupNum(groupFieldsIdx);

            % Populate voltages
            for dataPointIdx = 1 : numChan
                tableData{dataIdx + groupDisplacement, displacement} = dataToTable(dataPointIdx);

                displacement = displacement + 1;
            end
        end
    end
    % Refresh displacement for groups
    groupDisplacement = size(tableData, 1);
end

% Make table header
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

% Make table
tableSPSS = cell2table(tableData, 'VariableNames', string(tableHeader));

%% Save
saveTableSPSSPath = uigetdir(pwd, 'Select folder to save the exported dataset');
if saveTableSPSSPath == 0, saveTableSPSSPath = pwd; end

writetable(tableSPSS, fullfile(saveTableSPSSPath, 'erpdataset.csv'));

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