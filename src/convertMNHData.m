function [sampledData] = convertMNHData(baseFilePath, EyeParams, ui_group_str, ui_subjectID, ui_condition_str, ui_targetSize_int, tobii)
% Converts MNH visual-angle classification output to centimeter coordinates.
%
% Loads event classification output from MNH, corrects for Savitzky-Golay filter 
% group delay, converts gaze coordinates from visual degrees back to screen 
% centimeters, pads missing initial timestamps, aligns the time vector with raw 
% Tobii data, and saves the formatted matrix to a .mat file.
%
% Args:
%     baseFilePath (str): Root project directory path.
%     EyeParams (struct): Display & setup settings containing:
%         cmToPixel (float): Conversion factor from centimeters to pixels.
%         pixelToDegrees (float): Conversion factor from pixels to degrees.
%         samplingFreq (float): Eye tracker sampling rate in Hz.
%     ui_group_str (str): Participant group identifier (e.g., 'G01').
%     ui_subjectID (str | int): Unique participant identifier.
%     ui_condition_str (str): Experimental condition tag (e.g., 'bln').
%     ui_targetSize_int (int): Experimental task target size flag (uses '_lg' suffix if equal to 2). If n/a to your data, use 1.
%     tobii (struct): Tobii eye tracking struct containing time_stamps array.
%
% Returns:
%     sampledData (double matrix): N-by-4 matrix containing [time_sec, label_corr, xsmo_cm, ysmo_cm].
%
% Raises:
%     MException: If the specified MNH results file does not exist.
%     MException: If the required variable 'ET' is missing from the loaded file.
%     MException: If sample length difference between Tobii data and MNH results exceeds 2 samples.

    % --- 1. Standardize Subject ID ---
    if isnumeric(ui_subjectID)
        subjStr = num2str(ui_subjectID);
    else
        subjStr = char(ui_subjectID);
    end

    % --- 2. Target Size Tagging ---
    sizeTag = '';
    if ui_targetSize_int == 2
        sizeTag = '_lg';
    end

    % --- 3. Build Cross-Platform Directories & Paths ---
    mnhResultsDir = fullfile(baseFilePath, 'post_step2', ui_group_str, 'mnh_results');
    if ~exist(mnhResultsDir, 'dir')
        mkdir(mnhResultsDir);
    end

    dataTitle      = sprintf('data_%s_%s%s_mnh', subjStr, ui_condition_str, sizeTag);
    mnhFile        = fullfile(mnhResultsDir, [dataTitle '.mat']);
    mnhOutputFile = fullfile(mnhResultsDir, [dataTitle '_converted.mat']);

    % --- 4. Validate File Existence ---
    if ~isfile(mnhFile)
        error('MNH results file missing: %s', mnhFile);
    end

    loadedData = load(mnhFile, 'ET');
    if ~isfield(loadedData, 'ET')
        error('Variable "ET" not found in MNH file: %s', mnhFile);
    end
    ET = loadedData.ET;

    % --- 5. Remove Savitzky-Golay Filter Delay ---
    ui_savgol_fl = 5; % Filter frame length
    delay_sg     = floor((ui_savgol_fl - 1) / 2);

    xsmo   = ET.Vectors.Xsmo(:);
    ysmo   = ET.Vectors.Ysmo(:);
    vel    = ET.Vectors.vel(:);
    label = ET.Vectors.Classification(:);
    msec   = ET.Vectors.Msec(:);

    % Shift vectors up to realign signal timing post-filter
    xsmo_corr  = [xsmo(delay_sg+1:end); NaN(delay_sg, 1)];
    ysmo_corr  = [ysmo(delay_sg+1:end); NaN(delay_sg, 1)];
    vel_corr   = [vel(delay_sg+1:end);  NaN(delay_sg, 1)];
    label_corr = [label(delay_sg+1:end); NaN(delay_sg, 1)];

    % --- 6. Reconvert Visual Degrees Back to cm ---
    degToCmFactor = EyeParams.cmToPixel * EyeParams.pixelToDegrees;
    xsmo_cm       = xsmo_corr / degToCmFactor;
    ysmo_cm       = ysmo_corr / degToCmFactor;

    %==== 7. correct time if 1st time stamp > 0============================
    sec = msec / 1000; % Convert ms to seconds
    dt  = 1 / EyeParams.samplingFreq; % Sample interval in seconds

    if sec(1) > 0
        % Compute exact number of missing initial samples
        numLeadingSamples = round(sec(1) / dt);

        if numLeadingSamples > 0
            % Generate synthetic leading timestamps starting from 0
            leadingTime = (0 : numLeadingSamples - 1)' * dt;

            % Prepend NaN padding to match original timeline
            sec        = [leadingTime; sec];
            xsmo_cm    = [NaN(numLeadingSamples, 1); xsmo_cm];
            ysmo_cm    = [NaN(numLeadingSamples, 1); ysmo_cm];
            vel_corr   = [NaN(numLeadingSamples, 1); vel_corr];
            label_corr = [NaN(numLeadingSamples, 1); label_corr];
        end
    end

    % ============== save sampledData======================================
    % create uniform time grid starting at first tobii time sample:
    N = length(tobii.time_stamps);
    timeSec = tobii.time_stamps(1) + (0:N-1)' / EyeParams.samplingFreq;
    timeSec = timeSec(:); % force column vector

    % Enforce equal length across all concatenated columns
    % in case of being off by ~1 sample from tobii length (to prevent
    % crashes)
    minLen = min([length(timeSec), length(label_corr), length(xsmo_cm), length(ysmo_cm)]);
    lenDiff = length(timeSec) - length(label_corr);
    if lenDiff > 2
        error('Length difference between Tobii & MNH results: %d', lenDiff);
    end 
    sampledData = [timeSec(1:minLen), label_corr(1:minLen), xsmo_cm(1:minLen), ysmo_cm(1:minLen)];
    save(mnhOutputFile, 'sampledData');

        
end