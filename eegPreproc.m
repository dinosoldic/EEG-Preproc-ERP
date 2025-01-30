% Convert BrainVision .dat files to MVPAlab format using EEGLAB functions
%
% This script processes EEG data exported from BrainVision in .dat format
% to MVPAlab format. It requires corresponding .vhdr, .dat, and .vmrk files.
% The script can handle segmented data and allows the user to specify various
% cleaning and preprocessing steps, including channel removal, resampling,
% filtering, epoching, baseline correction, ICA, interpolation, and more.
% The final data can be saved in .set (EEGLAB format), .mat (MATLAB format), or both.
%
% Once the data is saved in either .set or .mat it can be inputed once
% again into the script to perform additional steps if needed.
%
% The script performs the following steps:
% 1. Prompts the user to select cleaning steps.
% 2. Prompts the user for necessary parameters for the selected steps.
% 3. Selects files for processing.
% 4. Processes each selected file according to the specified steps.
% 5. Saves the processed data in the specified format.
%
% Note: If ICA and/or automatic rejection are selected, a checkpoint save
% will be created in the selected format for each one before rejecting
% components/trials.
%
% Ensure you have EEGLAB installed and added to the MATLAB path.
%

%% Clean Matlab
clear; clc;

%% Ask user for parameters

cleanoptions = {'Resample', 'Data filters', 'Epoch data', 'Correct baseline', 'Reject with ICA', ...
                    'Interpolate', 'Reject voltage outliers', 'Reject abnormal spectra', 'Re-reference', 'Plot ERPs'};
[cleanselection, ~] = listdlg('ListString', cleanoptions, 'PromptString', 'Select cleaning steps:', 'SelectionMode', 'multiple');

if isempty(cleanselection)
    % The user canceled the selection
    fprintf('Operation canceled. Shutting down\n');
    return
end

if any(cleanselection == 1)
    % Enter new fsample
    resampleValue = inputdlg('Enter new sampling frequency', 'Sampling Frequency', 1, "250");
    resampleValue = str2double(resampleValue);

    if isempty(resampleValue) || any(isnan(resampleValue))
        fprintf('Enter valid numeric value. Shutting down\n');
        return
    end

end

if any(cleanselection == 3)
    % Enter labels for epoching
    stimuliLabels = inputdlg({'Enter stimuli labels (labels must be "," separated)', 'Enter label for file''s name (labels must be "," separated)'}, 'Epoch Labels', 1);

    labelsMap = {};

    % split labels
    if ~isempty(stimuliLabels) && ~any(cellfun(@isempty, stimuliLabels))

        for labelsMapIdx = 1:numel(stimuliLabels)

            % Split strings
            parts = strsplit(stimuliLabels{labelsMapIdx}, ',');

            % Trim spaces
            trimmedParts = cellfun(@strtrim, parts, 'UniformOutput', false);

            % Concatenate results
            labelsMap = [labelsMap; trimmedParts]; %#ok<AGROW>
        end

    end

end

if any(cleanselection == 4)
    baselineThreshold = inputdlg({'Enter baseline correction start point in milliseconds (ms)', 'Enter baseline correction end point in milliseconds (ms)'}, 'Baseline Correction', 1, {'-200', '0'});
    baselineThreshold = str2double(baselineThreshold);

    if isempty(baselineThreshold) || any(isnan(baselineThreshold))
        fprintf('Enter valid numeric value. Shutting down\n');
        return
    end

end

if any(cleanselection == 7)
    amplitudeThreshold = inputdlg('Enter maximum voltage threshold for automatic voltage epoch rejection', 'Voltage Threshold', 1, "75");
    amplitudeThreshold = str2double(amplitudeThreshold);

    if isempty(amplitudeThreshold) || isnan(amplitudeThreshold)
        fprintf('Enter valid numeric value. Shutting down\n');
        return
    end

end

if any(cleanselection == 8)
    rejSpecSettings = cell(1);
    spectraIdx = 1;

    while true

        while true
            % Set spectrum settings
            spectraOptions = {'Enter power rejection threshold (dB)', ...
                                  'Enter low frequency limit (Hz)', 'Enter high frequency limit (Hz)'};
            rejSpecValues = inputdlg(spectraOptions, 'Spectra Thresholds', 1, {'50', '0', '2'});
            rejSpecValues = str2double(rejSpecValues);

            % Check values
            if isempty(rejSpecValues) || any(isnan(rejSpecValues))
                fprintf('Enter valid values for epoching\n');
            else
                break
            end

        end

        % Save values to cell
        rejSpecSettings{spectraIdx} = rejSpecValues;
        spectraIdx = spectraIdx + 1;

        % Prompt to redo spectra with other options
        addSpectra = questdlg('Do you wish to add more spectra reject options?', 'Reject spectra', 'Yes', 'No', 'No');
        if strcmpi(addSpectra, 'no'), break, end
    end

end

% Select files
folderpath = uigetdir(pwd, 'Select folder with files to load ');

if folderpath == 0
    fprintf('Operation canceled. Shutting down\n');
    return
end

% Define savepath
savepath = uigetdir(pwd, 'Select path to save the data');

if savepath == 0
    fprintf('Operation canceled. Shutting down\n');
    return
end

% Prompt save format
saveformat = questdlg('Do you want to save as .set (EEGLAB dataset), .mat (MATLAB data) file or both?', 'Choose format', 'set', 'mat', 'both', 'mat');

% Check the user's response
if strcmpi(saveformat, 'set')

    fprintf('Data will be saved as .set file.\n');

    % Set save path
    savepath_set = fullfile(savepath, 'set_files');
    icaSaveFolderPath = fullfile(savepath_set, 'preIca');
    rejSaveFolderPath = fullfile(savepath_set, 'preRej');

    % Check folder
    if ~exist(savepath_set, 'dir'), mkdir(savepath_set); end
    if ~exist(icaSaveFolderPath, 'dir'), mkdir(icaSaveFolderPath); end
    if ~exist(rejSaveFolderPath, 'dir'), mkdir(rejSaveFolderPath); end

    % Update the savepath
    savepath = savepath_set;

elseif strcmpi(saveformat, 'mat')

    fprintf('Data will be saved as .mat file.\n');

    % Set save path
    savepath_mat = fullfile(savepath, 'mat_files');
    icaSaveFolderPath = fullfile(savepath_mat, 'preIca');
    rejSaveFolderPath = fullfile(savepath_mat, 'preRej');

    % Check folder
    if ~exist(savepath_mat, 'dir'), mkdir(savepath_mat); end
    if ~exist(icaSaveFolderPath, 'dir'), mkdir(icaSaveFolderPath); end
    if ~exist(rejSaveFolderPath, 'dir'), mkdir(rejSaveFolderPath); end

    % Update savepath
    savepath = savepath_mat;

elseif strcmpi(saveformat, 'both')

    fprintf('Data will be saved as both .set and .mat file.\n');

    % Set save path
    savepath_mat = fullfile(savepath, 'mat_files');
    savepath_set = fullfile(savepath, 'set_files');

    % Update savepath
    savepath = struct();
    icaSaveFolderPath = struct();
    rejSaveFolderPath = struct();
    savepath.mat = savepath_mat;
    savepath.set = savepath_set;
    icaSaveFolderPath.mat = fullfile(savepath.mat, 'preIca');
    icaSaveFolderPath.set = fullfile(savepath.set, 'preIca');
    rejSaveFolderPath.mat = fullfile(savepath.mat, 'preRej');
    rejSaveFolderPath.set = fullfile(savepath.set, 'preRej');

    % Check folder
    if ~exist(savepath.mat, 'dir'), mkdir(savepath.mat); end
    if ~exist(icaSaveFolderPath.mat, 'dir'), mkdir(icaSaveFolderPath.mat); end
    if ~exist(rejSaveFolderPath.mat, 'dir'), mkdir(rejSaveFolderPath.mat); end

    if ~exist(savepath.set, 'dir'), mkdir(savepath.set); end
    if ~exist(icaSaveFolderPath.set, 'dir'), mkdir(icaSaveFolderPath.set); end
    if ~exist(rejSaveFolderPath.set, 'dir'), mkdir(rejSaveFolderPath.set); end

end

%% Decide start point

% Get a list of files in the folder
vhdrFiles = dir(fullfile(folderpath, '*.vhdr'));
matFiles = dir(fullfile(folderpath, '*.mat'));
setFiles = dir(fullfile(folderpath, '*.set'));
filelist = [vhdrFiles, matFiles, setFiles];

% Ask user to select files from dir
selectoptions = {filelist.name};
[selected_files, ~] = listdlg('ListString', selectoptions, 'PromptString', 'Select file:', 'SelectionMode', 'multiple');

if isempty(selected_files)
    fprintf('Operation canceled. Shutting down\n');
    return
end

% set warning for missing chanlocs
warnMissChan = true;

%% Process data
while true

    for i = selected_files

        try
            %% Load data
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

            %% Clean EEG data using EEGLAB functions

            while true
                % Step 1 visualize raw data
                pop_eegplot(EEG, 1, 0, 0); % [1 channel data or 0 independent components], [1 for channel interpolation, 0 to skip interpolation], [1 to allow manual rejection]
                uiwait(gcf);
                close all

                % Step 2 Remove channels before cleaning data
                if ~exist('doRemoveChans', 'var')
                    doRemoveChans = questdlg('Do you wish to remove channels from your data?', 'Remove Channels', 'Yes', 'No', 'Yes');
                    if strcmpi(doRemoveChans, 'yes'), doRemoveChans = true; else, doRemoveChans = false; end
                end

                if doRemoveChans

                    if ~exist('selectChansToRemove', 'var')
                        [selectChansToRemove, ~] = listdlg('ListString', {EEG.chanlocs.labels}, 'PromptString', 'Select channels to remove:', 'SelectionMode', 'multiple');

                        % Find chanlabels from indices
                        chansToRemove = {EEG.chanlocs(selectChansToRemove).labels};
                    end

                    % Use EEGLAB function to remove them
                    EEG = pop_select(EEG, 'nochannel', selectChansToRemove);

                    % Update EEG
                    EEG = eeg_checkset(EEG);

                    % Completion msg
                    fprintf('Removed channel(s) {%s} from EEG data.\n', strjoin(chansToRemove, ', '));
                else
                    fprintf('No channels removed from EEG data.\n');
                end

                % Step 3 Resample
                if any(cleanselection == 1)

                    % Resample
                    EEG = pop_resample(EEG, resampleValue);

                    % Plot
                    pop_eegplot(EEG, 1, 0, 0); % [1 channel data or 0 independent components], [1 for channel interpolation, 0 to skip interpolation], [1 to allow manual rejection]
                    uiwait(gcf);
                    close all
                end

                % Step 4 filter data and visualize
                if any(cleanselection == 2)

                    while true

                        try
                            EEG = pop_eegfiltnew(EEG);
                            pop_eegplot(EEG, 1, 0, 0); % [1 channel data or 0 independent components], [1 for channel interpolation, 0 to skip interpolation], [1 to allow manual rejection]
                            uiwait(gcf);
                            close all
                        catch
                            warning('Input at least one value valid numeric value to filter the data.')
                        end

                        % Ask to filter again
                        refilter = questdlg('Do you wish to filter again your data?', 'Filter data', 'Yes', 'No', 'No');
                        if strcmpi(refilter, 'No'), break, end
                    end

                end

                % Step 5 Split data in epochs
                if any(cleanselection == 3)

                    if ~exist('epochSettings', 'var')

                        while true
                            % Select stimulus
                            selectStimuli = unique({EEG.event.type});
                            [epochSettings.stimuli, ~] = listdlg('ListString', selectStimuli, 'PromptString', 'Select Stimuli for Epoch:', 'SelectionMode', 'multiple');

                            % Select time window
                            epochSettings.time = inputdlg({'Enter epoch start point in seconds (s)', 'Enter epoch end point in seconds (s)'}, 'Split in Epochs', 1)';
                            epochSettings.time = str2double(epochSettings.time);

                            % init suffix
                            suffixToSave = '';

                            if ~isempty(labelsMap)
                                % Remove spaces and convert to lowercase
                                inputStimuliToCompare = cellfun(@(x) lower(strrep(x, ' ', '')), labelsMap(1, :), 'UniformOutput', false);
                                stimuliToCompare = lower(strrep(selectStimuli(epochSettings.stimuli), ' ', ''));

                                % Find label to save
                                [stimuliMatches, stimuliIndices] = ismember(stimuliToCompare, inputStimuliToCompare);

                                if stimuliMatches
                                    suffixToSave = ['-', labelsMap{2, stimuliIndices}];
                                end

                            end

                            % Check values
                            if ~isnumeric(epochSettings.time) || any(isnan(epochSettings.time)) || isempty(epochSettings.stimuli) || isempty(epochSettings.time)
                                fprintf('Enter valid values for epoching\n');
                            else
                                break
                            end

                        end

                    end

                    % Epoch with eeglab
                    EEG = pop_epoch(EEG, selectStimuli(epochSettings.stimuli), epochSettings.time);

                    pop_eegplot(EEG, 1, 1, 1); % [1 channel data or 0 independent components], [1 for channel interpolation, 0 to skip interpolation], [1 to allow manual rejection]
                    uiwait(gcf);
                    close all
                end

                % Change filename for saving
                fileNameSave = ogfilename + suffixToSave;

                % Step 6 Correct baseline
                if any(cleanselection == 4)
                    EEG = pop_rmbase(EEG, baselineThreshold');
                end

                % Step 7 run ICA
                if any(cleanselection == 5)

                    while true

                        try
                            EEG = pop_runica(EEG, 'icatype', 'runica', 'extended', 1, 'interrupt', 'off');
                            break
                        catch
                            opts = struct('WindowStyle', 'non-modal', 'Interpreter', 'tex');
                            errordlg('\color{red} \fontsize{13} ICA was interrupted. Running again', 'ICA Error', opts);
                        end

                    end

                    % Review and label ICA components
                    EEG = iclabel(EEG, 'default');
                    pop_viewprops(EEG, 0);

                    if ~isempty(findall(0, 'Type', 'figure'))
                        uiwait(gcf);
                        close all
                    end

                    % Save checkpoint
                    EEG.comments = [];

                    if strcmpi(saveformat, 'mat')
                        save(fullfile(icaSaveFolderPath, fileNameSave), 'EEG');
                    elseif strcmpi(saveformat, 'set')
                        EEG = pop_saveset(EEG, char(fileNameSave), char(icaSaveFolderPath), 'savemode', 'onefile');
                    elseif strcmpi(saveformat, 'both')
                        save(fullfile(icaSaveFolderPath.mat, fileNameSave), 'EEG');
                        EEG = pop_saveset(EEG, char(fileNameSave), char(icaSaveFolderPath.set), 'savemode', 'onefile');
                    end

                    % IC Artifact Rejection
                    while true
                        EEG = pop_selectcomps(EEG); % Manually inspect and select

                        if ~isempty(findall(0, 'Type', 'figure'))
                            uiwait(gcf);
                            close all
                        end

                        EEG = pop_subcomp(EEG, [], 1, 0); % Remove components from data

                        EEG = eeg_checkset(EEG);

                        % Plot channel data
                        pop_eegplot(EEG, 1, 1, 1); % [1 channel data or 0 independent components], [1 for channel interpolation, 0 to skip interpolation], [1 to allow manual rejection]
                        uiwait(gcf);
                        close all

                        % Ask to reject componentes again
                        reICA = questdlg('Do you wish to reject ICA components once more?', 'Reject ICA', 'Yes', 'No', 'No');
                        if strcmpi(reICA, 'No'), break, end
                    end

                end

                % Step 8 Interpolate bad channels if necessary
                if any(cleanselection == 6)

                    while true
                        EEG = pop_interp(EEG);

                        pop_eegplot(EEG, 1, 1, 1); % [1 channel data or 0 independent components], [1 for channel interpolation, 0 to skip interpolation], [1 to allow manual rejection]
                        uiwait(gcf);
                        close all

                        % Ask to interpolate again
                        interpochan = questdlg('Do you wish to interpolate again?', 'Interpolation', 'Yes', 'No', 'No');
                        if strcmpi(interpochan, 'No'), break, end
                    end

                end

                % Step 9 Auto Reject abnormal voltage epochs
                if any(cleanselection == 7)

                    % Save checkpoint
                    EEG.comments = [];

                    if strcmpi(saveformat, 'mat')
                        save(fullfile(rejSaveFolderPath, fileNameSave), 'EEG');
                    elseif strcmpi(saveformat, 'set')
                        EEG = pop_saveset(EEG, char(fileNameSave), char(rejSaveFolderPath), 'savemode', 'onefile');
                    elseif strcmpi(saveformat, 'both')
                        save(fullfile(rejSaveFolderPath.mat, fileNameSave), 'EEG');
                        EEG = pop_saveset(EEG, char(fileNameSave), char(rejSaveFolderPath.set), 'savemode', 'onefile');
                    end

                    % Mark trials to reject
                    EEG = pop_eegthresh(EEG, 1, 1:length(EEG.chanlocs), -abs(amplitudeThreshold), abs(amplitudeThreshold), EEG.times(1) / 1000, EEG.times(end) / 1000, 1, 0);

                    % Update thresholds
                    if ~isempty(EEG.reject.rejmanual)
                        EEG.reject.rejmanual = EEG.reject.rejmanual | EEG.reject.rejthresh;
                        EEG.reject.rejmanualE = EEG.reject.rejmanualE | EEG.reject.rejthreshE;
                    else
                        EEG.reject.rejmanual = EEG.reject.rejthresh;
                        EEG.reject.rejmanualE = EEG.reject.rejthreshE;
                    end

                    % Decide epoch rej
                    pop_eegplot(EEG, 1, 1, 1); % [1 channel data or 0 independent components], [1 for channel interpolation, 0 to skip interpolation], [1 to allow manual rejection]
                    uiwait(gcf);
                    close all

                    % Reject marked trials
                    if ~isempty(EEG.reject.rejmanual) && any(EEG.reject.rejmanual)
                        EEG = pop_rejepoch(EEG, EEG.reject.rejmanual, 0);
                    end

                end

                % Step 10 Auto reject abnormal spectra
                if any(cleanselection == 8)

                    % Save checkpoint
                    if ~any(cleanselection == 7)
                        EEG.comments = [];

                        if strcmpi(saveformat, 'mat')
                            save(fullfile(rejSaveFolderPath, fileNameSave), 'EEG');
                        elseif strcmpi(saveformat, 'set')
                            EEG = pop_saveset(EEG, char(fileNameSave), char(rejSaveFolderPath), 'savemode', 'onefile');
                        elseif strcmpi(saveformat, 'both')
                            save(fullfile(rejSaveFolderPath.mat, fileNameSave), 'EEG');
                            EEG = pop_saveset(EEG, char(fileNameSave), char(rejSaveFolderPath.set), 'savemode', 'onefile');
                        end

                    end

                    % Mark trials to reject
                    for spectraIdx = 1:numel(rejSpecSettings)
                        rejSpecSettingsFunc = rejSpecSettings{spectraIdx};
                        EEG = pop_rejspec(EEG, 1, 'elecrange', 1:length(EEG.chanlocs), 'method', 'fft', ...
                            'threshold', [-abs(rejSpecSettingsFunc(1)) abs(rejSpecSettingsFunc(1))], ...
                            'freqlimits', [rejSpecSettingsFunc(2), rejSpecSettingsFunc(3)], ...
                            'eegplotreject', 0, 'eegplotplotallrej', 1);

                        % Update thresholds
                        if ~isempty(EEG.reject.rejmanual)
                            EEG.reject.rejmanual = EEG.reject.rejmanual | EEG.reject.rejfreq;
                            EEG.reject.rejmanualE = EEG.reject.rejmanualE | EEG.reject.rejfreqE;
                        else
                            EEG.reject.rejmanual = EEG.reject.rejfreq;
                            EEG.reject.rejmanualE = EEG.reject.rejfreqE;
                        end

                        % Decide epoch rej
                        pop_eegplot(EEG, 1, 1, 1); % [1 channel data or 0 independent components], [1 for channel interpolation, 0 to skip interpolation], [1 to allow manual rejection]
                        uiwait(gcf);
                        close all

                        % Reject marked trials
                        if ~isempty(EEG.reject.rejmanual) && any(EEG.reject.rejmanual)
                            EEG = pop_rejepoch(EEG, EEG.reject.rejmanual, 0);
                        end

                    end

                end

                % Step 11 Re-reference
                if any(cleanselection == 9)

                    if ~exist('trialRef', 'var')

                        while true
                            trialRef = questdlg('How do you wish to re-reference the data?', 'Re-reference', 'Average', 'Channel', 'Average');

                            if strcmpi(trialRef, 'channel')
                                % Select channel for ref
                                chanlabels = {EEG.chanlocs.labels};
                                [rerefChan, ~] = listdlg('ListString', chanlabels, 'PromptString', 'Select channel for Re-reference:', 'SelectionMode', 'single');

                                % Check input
                                if isempty(rerefChan), fprintf('Select a valid channel.\n'), else, break, end
                            end

                            % Check input
                            if isempty(trialRef), fprintf('Select an option.\n'), else, break, end
                        end

                    end

                    % Re-ref func
                    if strcmpi(trialRef, 'average')
                        EEG = pop_reref(EEG, []);
                        fprintf('Computing average reference of the data.\n');
                    elseif strcmpi(trialRef, 'channel')
                        EEG = pop_reref(EEG, rerefChan);
                        fprintf('Referencing data to channel "%s".\n', EEG.chanlocs(rerefChan).labels);
                    end

                    % Plot
                    pop_eegplot(EEG, 1, 1, 1); % [1 channel data or 0 independent components], [1 for channel interpolation, 0 to skip interpolation], [1 to allow manual rejection]
                    uiwait(gcf);
                    close all
                end

                % Step 12 final data inspection
                while true
                    pop_eegplot(EEG, 1, 1, 1); % [1 channel data or 0 independent components], [1 for channel interpolation, 0 to skip interpolation], [1 to allow manual rejection]
                    uiwait(gcf);
                    close all

                    % Check and reject leftover merked trials
                    if ~isempty(EEG.reject.rejmanual) && any(EEG.reject.rejmanual)
                        EEG = pop_rejepoch(EEG, EEG.reject.rejmanual, 0);
                    end

                    % Ask to inspect again
                    re_rej = questdlg('Do you wish to inspect the data once again?', 'Data Inspection', 'Yes', 'No', 'No');
                    if strcmpi(re_rej, 'No'), break, end
                end

                % Step 13 Plot ERPs
                if any(cleanselection == 10)
                    topoTitle = sprintf('ERPs for %s', fileNameSave);
                    pop_plottopo(EEG, 1:length(EEG.chanlocs), char(topoTitle), 0);
                    uiwait(gcf);
                    close all
                end

                % Ask to redo all preproc
                redoclean = questdlg('Do you wish to redo data processing or continue?', 'Finish cleaning', 'Redo', 'Finish', 'Finish');

                if ~strcmpi(redoclean, 'redo')
                    fprintf('Proceeding to save data ... \n');
                    break
                else
                    fprintf ('Deleting current dataset and importing raw data\n');

                    % Run eeglab and reset vars
                    eeglab;
                    close all

                    % Load EEG data from .vhdr or .ahdr file or other
                    if strcmpi(ogExtension, '.vhdr')
                        EEG = pop_loadbv(folderpath, filename, [], []);
                    else
                        EEG = pop_loadset(filename, folderpath);
                    end

                end

            end

            % Step 14 Save data and remove comments
            EEG.comments = [];

            if strcmpi(saveformat, 'mat')
                % Save "EEG" var
                save(fullfile(savepath, fileNameSave), 'EEG');

            elseif strcmpi(saveformat, 'set')
                % Save dataset
                EEG = pop_saveset(EEG, char(fileNameSave), char(savepath), 'savemode', 'onefile');

            elseif strcmpi(saveformat, 'both')
                % Save "EEG" var
                save(fullfile(savepath.mat, fileNameSave), 'EEG');

                % Save dataset
                EEG = pop_saveset(EEG, char(fileNameSave), char(savepath.set), 'savemode', 'onefile');
            end

            % Display completion
            fprintf('\n-----Subject %s finished-----\n\n', fileNameSave);

        catch subject_loop_error
            % Display error message
            warning('Error found in %s.\n%s (line %d): \n %s\n\nSkipping to next subject...', ogfilename, subject_loop_error.stack(end).name, subject_loop_error.stack(end).line, subject_loop_error.message);
            % Skip to next subject
            continue
        end

    end

    % Display completion
    fprintf('\n-------Successfully completed %d files-------', length(selected_files));

    %% Ask to run script on a different condition
    askConditionRerun = questdlg('Do you wish to clean a different condition?', 'Clean new condition', 'Yes', 'No', 'No');

    if strcmpi(askConditionRerun, 'yes')
        fprintf ('Preparing to run on new condition...\n');

        clear epochSettings
    else
        break
    end

end

% Display completion
fprintf('\n\t\t  /\\_/\\ \t  /\\_/\\ \n\t\t ( o.o )\t ( ^.^ )\n\t\t  > ^ <\t\t  > ^ <\n');
