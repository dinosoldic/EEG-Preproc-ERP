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

        otherwise
            EEG = pop_chanedit(EEG, 'load', chanlocsPath);
            EEG = eeg_checkset(EEG);

    end

end
