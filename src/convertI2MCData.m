function [sampledData] = convertI2MCData(baseFilePath, EyeParams, ui_group_str, ui_subjectID, ui_condition_str, ui_targetSize_int, tobii)
% Converts I2MC fixation classification output to centimeter coordinates.
%
% Loads sample-by-sample output from I2MC (from modified getFixations I2MC function), 
% converts pixel gaze coordinates back to normalized Tobii units, transforms coordinates 
% into screen-centered centimeter offsets, aligns timestamps with raw Tobii eye-tracking 
% data, and saves the formatted matrix to a .mat file.
%
% Args:
%     baseFilePath (str): Root project directory path.
%     EyeParams (struct): Display and acquisition parameters containing:
%         samplingFreq (float): Eyetracker sampling rate in Hz.
%         screenResolutionWidth (float): Horizontal screen resolution in pixels.
%         screenResolutionHeight (float): Vertical screen resolution in pixels.
%         screenWidthInCm (float): Physical display width in centimeters.
%         screenHeightInCm (float): Physical display height in centimeters.
%     ui_group_str (str): Participant group identifier (e.g., 'G01').
%     ui_subjectID (str | int): Unique subject identifier (e.g., '101' or 101).
%     ui_condition_str (str): Experimental condition tag (e.g., 'bln').
%     ui_targetSize_int (int): Experimental task target size flag (uses '_lg' suffix if equal to 2). If n/a to your data, use 1.
%     tobii (struct): Tobii eye tracking struct containing time_stamps array.
%
% Returns:
%     sampledData (double matrix): N-by-4 matrix containing [time_sec, label, x_cm, y_cm].
%
% Raises:
%     MException: If the specified I2MC results file does not exist.


    % ====== 1. Standardize Subject ID to handles string or numeric========
    if isnumeric(ui_subjectID)
        subjStr = num2str(ui_subjectID);
    else
        subjStr = char(ui_subjectID);
    end

    % ============ 2 Target Size ==========================================
    sizeTag = '';
    if ui_targetSize_int == 2
        sizeTag = '_lg';
    end

    % ==============3 make cross-platform filepaths =======================
    i2mcResultsDir = fullfile(baseFilePath, 'post_step2', ui_group_str, 'i2mc_results');
    if ~exist(i2mcResultsDir, 'dir')
        mkdir(i2mcResultsDir);
    end

    i2mcFile       = fullfile(i2mcResultsDir, sprintf('data_%s_%s%s_i2mc.mat', subjStr, ui_condition_str, sizeTag));
    outputFileName = fullfile(i2mcResultsDir, sprintf('data_%s_%s%s_i2mc_converted.mat', subjStr, ui_condition_str, sizeTag));

    % ===========4. Validate and Load I2MC Output File ====================
    if ~isfile(i2mcFile)
        error('I2MC results file not found: %s', i2mcFile);
    end
    loadedData = load(i2mcFile, 'fix');
    fix = loadedData.fix;

    % ============= 5 Coordinate Transformations ==========================
    % create uniform time grid starting at first tobii time sample:
    N = length(tobii.time_stamps);
    timeSec = tobii.time_stamps(1) + (0:N-1)' / EyeParams.samplingFreq;
    timeSec = timeSec(:); % force column vector

    label         = fix.sampleBySample(:, 2); label = label(:);

    % Convert pixels back to Tobii units and then to cm
    x_tobii_units = fix.sampleBySample(:, 3) / EyeParams.screenResolutionWidth; x_tobii_units = x_tobii_units(:);
    y_tobii_units = fix.sampleBySample(:, 4) / EyeParams.screenResolutionHeight;; y_tobii_units = y_tobii_units(:);

    x_cm = (x_tobii_units - 0.5) * EyeParams.screenWidthInCm;
    y_cm = (0.5 - y_tobii_units) * EyeParams.screenHeightInCm;


    sampledData = [timeSec, label, x_cm, y_cm];    
    save(outputFileName, 'sampledData');

end