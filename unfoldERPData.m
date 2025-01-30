clear; clc;

%% Prep data
% Select data folder
folderpath = uigetdir(pwd, 'Select folder with files to load ');

if folderpath == 0
    fprintf("Operation canceled. Shutting down\n");
    return
end

% Get a list of files in the folder
vhdrFiles = dir(fullfile(folderpath, '*.vhdr'));
matFiles = dir(fullfile(folderpath, '*.mat'));
setFiles = dir(fullfile(folderpath, '*.set'));
filelist = [vhdrFiles, matFiles, setFiles];

% Ask user to select files from dir
selectoptions = {filelist.name};
[selected_files, ~] = listdlg('ListString', selectoptions, 'PromptString', 'Select file:', 'SelectionMode', 'multiple');

if isempty(selected_files)
    fprintf("Operation canceled. Shutting down\n");
    return
end

% Define savepath
savepath = uigetdir(pwd, 'Select path to save the data');

if savepath == 0
    fprintf("Operation canceled. Shutting down\n");
    return
end

% Enter save label
saveLabel = inputdlg('Enter label to use when saving clean data', 'Saved File Labels', 1);
saveLabel = char(saveLabel);

% Enter event labels that will be used
stimuliLabels = inputdlg({'Enter stimulus 1 labels (labels must be "," separated)', 'Enter stimulus 2 labels (labels must be "," separated)'}, 'Stimuli Labels', 1);

labelsStim1 = {};
labelsStim2 = {};

% split labels
if ~isempty(stimuliLabels) && ~any(cellfun(@isempty, stimuliLabels))

    for labelsMapIdx = 1:numel(stimuliLabels)

        % Split strings
        parts = strsplit(stimuliLabels{labelsMapIdx}, ',');

        % Trim spaces
        trimmedParts = cellfun(@(x) strrep(x, ' ', ''), parts, 'UniformOutput', false);

        % save
        if labelsMapIdx == 1
            labelsStim1 = trimmedParts;
        else
            labelsStim2 = trimmedParts;
        end

    end

end

% Select time window
while true
    epochSettings = inputdlg({'Enter epoch start point in seconds (s)', 'Enter epoch end point in seconds (s)'}, 'Epoch Limits', 1)';
    epochSettings = str2double(epochSettings);
    if isempty(epochSettings), fprintf("Operation canceled. Shutting down\n"); return, end
    if any(isnan(epochSettings)), warning("Epoch limits must be numeric"); else, break, end
end

% Select filter
while true
    filterSettings = inputdlg({'Enter low frequency cutoff', 'Enter high frequency cutoff'}, 'EEG Filter Settings', 1)';
    filterSettings = str2double(filterSettings);
    if isempty(filterSettings), fprintf("Operation canceled. Shutting down\n"); return, end

    if any(isnan(filterSettings))
        warning("Filter limits must be numeric");
    else
        lowCutoffFilt = filterSettings(1);
        highCutoffFilt = filterSettings(2);
        break
    end

end

% Select voltage for auto-artifact rejection
while true
    amplitudeThreshold = inputdlg('Enter maximum voltage threshold for automatic voltage artifact rejection', 'Voltage Threshold', 1, "250");
    amplitudeThreshold = str2double(amplitudeThreshold);

    if isempty(amplitudeThreshold), fprintf("Operation canceled. Shutting down\n"); return, end
    if isnan(amplitudeThreshold), warning("Amplitude threshold must be numeric"); else, break, end
end

% Select target stimulus
options = {'Stimulus 1', 'Stimulus 2'};
extractStim = questdlg('Which stimulus data would you like to extract from the overlapped signals?', 'Extract Stimulus Data', options{:}, options{2});
selectedStim = find(strcmp(extractStim, options));

% decide resampling
doResample = questdlg('Do you want to resample your data?', 'Resample EEG Data', 'Yes', 'No', 'No');
if ~strcmpi(doResample, 'yes'), doResample = false; else, doResample = true; end

if doResample

    while true
        resampleValue = inputdlg('Input new sample frequency', 'Resample Frequency', 1);
        resampleValue = str2double(resampleValue);

        if isempty(resampleValue), fprintf("Operation canceled. Shutting down\n"); return, end
        if isnan(resampleValue), warning("Resampling frequency must be numeric"); else, break, end
    end

end

% set warning for chanlocs
warnMissChan = true;

% init error txt and var
errorFile = 0;
fid = fopen(fullfile(savepath, 'errorSubjects.txt'), 'a');

%% Run eeglab with unfold
% Loop through the list of files and run script for each file
for i = selected_files

    try
        % init error var
        errorFile = false;

        % Get the file name
        filename = filelist(i).name;

        % Get filename to save it later
        [~, ogfilename, ogExtension] = fileparts(filename);
        ogfilename = string(ogfilename);

        % Run EEGlab in the background and call it again for each iteration
        % so it clears previous unnecesary data.
        eeglab;
        close all

        % Load EEG data from .vhdr or .ahdr file or other
        if strcmpi(ogExtension, '.vhdr')
            EEG = pop_loadbv(folderpath, filename, [], []);
        else
            EEG = pop_loadset(filename, folderpath);
        end

        % Check chanlocs
        if warnMissChan
            isChanLocsEmpty = isempty([EEG.chanlocs.X]) || isempty([EEG.chanlocs.Y]) || isempty([EEG.chanlocs.Z]) || isempty([EEG.chanlocs.theta]);

            if isChanLocsEmpty

                doLoadCoords = questdlg('The coordinates for your channels/electrodes are missing. Do you wish to load a file with their coordinates?', 'Missing Coordinates', 'Yes', 'No', 'Yes');

            end

            warnMissChan = false;
        end

        % import chanlocs
        if exist('doLoadCoords', 'var')

            if strcmp(doLoadCoords, 'Yes')

                while true
                    % get file and extension
                    [chanlocsFile, chanlocsDir] = uigetfile('*.*', 'Select file containing EEG layout', 'MultiSelect', 'off');
                    chanlocsPath = fullfile(chanlocsDir, chanlocsFile);
                    [~, ~, chanlocsExt] = fileparts(chanlocsPath);

                    try
                        fprintf('Loading channel coordinates...\n');
                        EEG = eegImportChanlocs(EEG, chanlocsPath, chanlocsExt);
                        fprintf('Channel coordinates loaded successfully.\n');
                        break

                    catch
                        reChanlocsLoad = questdlg('Channels could not be loaded. Try again?', 'Channel Error', 'Yes', 'No', 'Yes');
                        if ~strcmp(reChanlocsLoad, 'Yes'), fprintf('Proceeding without loading channel coordinates...\n'); break, end
                    end

                end

            else
                dialToWait = warndlg('The data will be processed without channel locations. Please note that you will not be able to use functions that require channel coordinates, such as "Topoplot".', 'Channel Omission');
                uiwait(dialToWait);
            end

        end

        % Step 2 Remove channels before cleaning data
        if ~exist("remove_chan_decision_pre", "var")

            % Ask user to remove channels
            remove_chan_decision_pre = questdlg('Do you wish to remove any channels before processing the data?', 'Remove channels', 'Yes', 'No', 'Yes');

            % Check user's decision for removing channels
            if strcmpi(remove_chan_decision_pre, 'Yes')

                chanlabels_pre = {EEG.chanlocs.labels};
                [remove_chan_select_pre, ~] = listdlg('ListString', chanlabels_pre, 'PromptString', 'Select channels:', 'SelectionMode', 'multiple');
            end

        end

        % Check if channels to remove exist
        if strcmpi(remove_chan_decision_pre, 'Yes')

            % Find chanlabels from indices
            displaychanlabels_pre = cell(length(remove_chan_select_pre), 1);

            for chanidx = 1:length(remove_chan_select_pre)
                displaychanlabels_pre{chanidx} = EEG.chanlocs(remove_chan_select_pre(chanidx)).labels;
            end

            % Use EEGLAB function to remove them
            EEG = pop_select(EEG, 'nochannel', remove_chan_select_pre);

            % Update EEG
            EEG = eeg_checkset(EEG);

            % Completion msg
            fprintf("Removed channel(s) {%s} from EEG data.\n", strjoin(displaychanlabels_pre, ', '));
            clear displaychanlabels_pre; clear chanlabels_pre;
        else
            fprintf("No channels removed from EEG data.\n");
        end

        % resample EEG
        if doResample
            EEG = pop_resample(EEG, resampleValue);
        end

        % Apply filter to EEG
        EEG = pop_eegfiltnew(EEG, lowCutoffFilt, highCutoffFilt);

        % Initialize new fields for stim1 and stim2
        for eventIdx = 1:length(EEG.event)
            % Remove spaces from event type for consistency
            eventType = strrep(EEG.event(eventIdx).type, ' ', '');

            % Assign stim1 based on user-defined markers
            if ismember(eventType, labelsStim1)
                EEG.event(eventIdx).stim1 = find(strcmp(eventType, labelsStim1)); % Assign corresponding index
                EEG.event(eventIdx).type = 'S 10';
            else
                EEG.event(eventIdx).stim1 = 0;
            end

            % Assign stim2 based on user-defined markers
            if ismember(eventType, labelsStim2)
                EEG.event(eventIdx).stim2 = find(strcmp(eventType, labelsStim2)); % Assign corresponding index
                EEG.event(eventIdx).type = 'S 20';
            else
                EEG.event(eventIdx).stim2 = 0;
            end

        end

        % Setup design matrix for deconvolution
        cfg = [];
        cfg.eventtypes = {'S 10', 'S 20'};
        cfg.formula = {'y ~ 1 + stim1 + stim2'};
        EEG = uf_designmat(EEG, cfg);

        % Setup timeexpanded matrix for deconvolotuion
        cfg = [];
        cfg.timelimits = epochSettings;
        cfgTimeexpand.method = 'stick'; % Use stick functions for temporal expansion
        EEG = uf_timeexpandDesignmat(EEG, cfg);

        % Exclude artifacted segments from training data (does not delete them)
        winrej = uf_continuousArtifactDetect(EEG, 'amplitudeThreshold', amplitudeThreshold);
        EEG = uf_continuousArtifactExclude(EEG, struct('winrej', winrej));

        % Fit General Linear Model and extract deconvoluted stimulus data
        EEG = uf_glmfit(EEG);
        ufresult = uf_condense(EEG);

        % Extract stim from data
        timeCutoff = find(ufresult.times == -0.2);
        selectedStimData = ufresult.beta(:, timeCutoff:end, selectedStim + 1);

        if ~any(isnan(selectedStimData), 'all')
            % make eeg backup
            EEGb = EEG;

            % remake EEG for custom plotting compatibility (only partial info is kept)
            EEG = struct();

            EEG.data = single(selectedStimData);
            EEG.srate = EEGb.srate;
            EEG.times = ufresult.times(timeCutoff:end);

            EEG.nbchan = size(EEG.data, 1);
            EEG.pnts = size(EEG.data, 2);
            EEG.trials = size(EEG.data, 3);
            EEG.xmin = EEG.times(1);
            EEG.xmax = EEG.times(end);

            EEG.chanlocs = EEGb.chanlocs;
            EEG.chaninfo = EEGb.chaninfo;

            EEG.ref = EEGb.ref;

            % Correct baseline
            blIndices = find(EEG.times >= -0.2 & EEG.times <= 0);
            blMean = mean(EEG.data(:, blIndices), 2);

            EEG.data = EEG.data - blMean;

            % save data
            if isempty(saveLabel)
                saveFileName = ogfilename;
            else
                saveFileName = ogfilename + '_' + saveLabel;
            end

            save(fullfile(savepath, saveFileName), "EEG");

            % Display completion
            fprintf("\n-----Subject %s finished-----\n\n", saveFileName);

        else
            % subj error
            errorFile = errorFile + 1;
            fprintf(fid, 'Error in "%s" for condition "%s"\n', ogfilename, saveLabel);

            warning(['!--------------------------------!\n', ...
                         '\t\t\t"%s" could not be unfolded\n', ...
                     '\t\t !--------------------------------!'], ogfilename);
        end

    catch subject_loop_error
        warning("Error found in %s.\n%s (line %d): \n %s\n\nSkipping to next subject...", ogfilename, subject_loop_error.stack(end).name, subject_loop_error.stack(end).line, subject_loop_error.message);
        continue
    end

end

% close error file
if errorFile == 0
    fprintf(fid, 'No errors found for condition "%s"\n', saveLabel);
end

fclose(fid);

% Display completion
fprintf("\n-------Succesfully completed %d files-------", length(selected_files));
fprintf("\n\t\t  /\\_/\\ \t  /\\_/\\ \n\t\t ( o.o )\t ( ^.^ )\n\t\t  > ^ <\t\t  > ^ <\n");
