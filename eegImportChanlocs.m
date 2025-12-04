%
% Helper function to import channel locations into an EEG structure
%
% Inputs:
%   EEG          - EEGLAB EEG structure
%   chanlocsPath - Path to channel location file (.vhdr, .bvef, or others)
%   ext          - File extension indicating type of chanloc file
%
% Output:
%   EEG          - EEG structure updated with channel location info
%
% Supports BrainVision formats (.vhdr, .bvef) with conversion of spherical
% coordinates to topographic and cartesian. For other formats, calls EEGLAB’s
% pop_chanedit to load channel locations.
%
% Intended as a helper within the EEG preprocessing workflow.
%
% Author: Dino Soldic
% Email: dino.soldic@urjc.es
% Date: 2025-06-30

function EEG = eegImportChanlocs(EEG, chanlocsPath, ext)

    switch ext
        case '.vhdr'
            % Open file and read lines
            fid = fopen(chanlocsPath, 'r');
            lines = textscan(fid, '%s', 'Delimiter', '\n');
            fclose(fid);
            lines = lines{1};

            % Find indices of chan and coord sections
            chStart = find(contains(lines, '[Channel Infos]')) + 1;
            chEnd = find(contains(lines, '[Channel User Infos]')) - 1;
            coordStart = find(contains(lines, '[Coordinates]')) + 1;
            coordEnd = numel(lines);

            % Initialize chanlocs
            EEG.chanlocs = struct('labels', [], 'sph_radius', [], 'sph_theta', [], 'sph_phi', [], 'theta', [], 'radius', [], 'X', [], 'Y', [], 'Z', [], 'type', [], 'ref', [], 'urchan', []);

            % Extract chan names
            for i = chStart:chEnd
                line = lines{i};

                if startsWith(line, 'Ch')
                    tokens = split(line, '=');
                    chIdx = str2double(extractAfter(tokens{1}, 'Ch'));
                    chan = split(tokens{2}, ',');
                    label = strtrim(chan{1}); % Extract channel name
                    EEG.chanlocs(chIdx).labels = label;
                end

            end

            % Extract channel coordinates
            for i = coordStart:coordEnd
                line = lines{i};

                if startsWith(line, 'Ch')
                    tokens = split(line, '=');
                    chIdx = str2double(extractAfter(tokens{1}, 'Ch'));
                    coord = str2double(split(tokens{2}, ','));

                    if all(coord == 0)
                        EEG.chanlocs(chIdx).sph_radius = [];
                        EEG.chanlocs(chIdx).sph_theta = [];
                        EEG.chanlocs(chIdx).sph_phi = [];
                    else
                        EEG.chanlocs(chIdx).sph_radius = coord(1);
                        EEG.chanlocs(chIdx).sph_theta = coord(3) - 90 * sign(coord(2)); % phi - 90 * sign(theta)
                        EEG.chanlocs(chIdx).sph_phi = -abs(coord(2)) + 90; % -abs(theta) + 90

                    end

                end

            end

            try
                [EEG.chanlocs, EEG.chaninfo] = pop_chanedit(EEG.chanlocs, 'convert', 'sph2topo'); % Convert spherical to topographic coordinates
                [EEG.chanlocs, EEG.chaninfo] = pop_chanedit(EEG.chanlocs, 'convert', 'sph2cart'); % Convert spherical to cartesian coordinates
            catch
                error('Could not convert spherical channel coordinates');
            end

            EEG = eeg_checkset(EEG);

        case '.bvef'
            % Read XML file
            doc = xmlread(chanlocsPath);
            electrodes = doc.getElementsByTagName('Electrode');

            % Initialize chanlocs structure
            EEG.chanlocs = struct('labels', [], 'sph_radius', [], 'sph_theta', [], 'sph_phi', [], 'theta', [], 'radius', [], 'X', [], 'Y', [], 'Z', [], 'type', [], 'ref', [], 'urchan', []);

            % Parse electrodes
            for i = 0:electrodes.getLength - 1
                electrode = electrodes.item(i);

                % Extract values
                label = char(electrode.getElementsByTagName('Name').item(0).getTextContent());
                phi = str2double(electrode.getElementsByTagName('Phi').item(0).getTextContent());
                theta = str2double(electrode.getElementsByTagName('Theta').item(0).getTextContent());
                radius = str2double(electrode.getElementsByTagName('Radius').item(0).getTextContent());

                % Assign values
                EEG.chanlocs(i + 1).labels = label;
                EEG.chanlocs(i + 1).sph_radius = radius;
                EEG.chanlocs(i + 1).sph_theta = phi - 90 * sign(theta);
                EEG.chanlocs(i + 1).sph_phi = -abs(theta) + 90;
            end

            try
                [EEG.chanlocs, EEG.chaninfo] = pop_chanedit(EEG.chanlocs, 'convert', 'sph2topo'); % Convert spherical to topographic coordinates
                [EEG.chanlocs, EEG.chaninfo] = pop_chanedit(EEG.chanlocs, 'convert', 'sph2cart'); % Convert spherical to cartesian coordinates
            catch
                error('Could not convert spherical channel coordinates');
            end

            EEG = eeg_checkset(EEG);

        case '.elc'
            % Open file and read lines
            fid = fopen(chanlocsPath, 'r');
            lines = textscan(fid, '%s', 'Delimiter', '\n');
            fclose(fid);
            lines = lines{1};

            % Extract labels and coords
            layLabelsStart = find(contains(lines, 'Labels')) + 1;
            layLabelsEnd = numel(lines);
            layCoordsStart = find(contains(lines, 'Positions'), 1, "last") + 1;
            layCoordsEnd = layLabelsStart - 2;

            layLabels = lines(layLabelsStart:layLabelsEnd);
            layCoords = lines(layCoordsStart:layCoordsEnd);

            % Find existing chans
            [~, idxLay] = intersect(layLabels, {EEG.chanlocs.labels}, 'stable');

            % make new temp lay file
            tempLay = [lines(1:layCoordsStart - 3); {sprintf('NumberPositions=->%d', length(idxLay))}; {'Positions'}; layCoords(idxLay); {'Labels'}; layLabels(idxLay)];

            % Write temporary file
            tempPath = fullfile(pwd, 'temp.elc');
            fid = fopen(tempPath, 'w');

            for i = 1:length(tempLay)
                fprintf(fid, '%s\n', tempLay{i});
            end

            fclose(fid);

            % Load positions into EEGLAB
            EEG = pop_chanedit(EEG, 'load', tempPath);
            EEG = eeg_checkset(EEG);

            % Delete temp file
            delete(tempPath);

        otherwise
            EEG = pop_chanedit(EEG, 'lookup', chanlocsPath);
            EEG = eeg_checkset(EEG);

    end

end
