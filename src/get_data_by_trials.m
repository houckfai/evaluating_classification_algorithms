function [eyeTrialData, raw_eyeTrialData, handTrialData] = get_data_by_trials(baseFilePath, pilotPath, EyeParams, ui_group_str, ui_subjectID_int, ui_condition_str, ui_algo_str, ui_targetSize_int, numTrials)
% Extracts trial-segmented eye and hand movement data.
%
% Loads eyetracking classification matrices, raw Tobii gaze streams, and 
% bimanual hand kinematic log files. Aligns presentation and kinematics timing 
% using LSL offsets, segments continuous data streams into discrete trial windows 
% bound by hand movement onset/offset, and saves output cell arrays to a .mat file.
%
% Args:
%     baseFilePath (str): Root project output directory path.
%     pilotPath (str): Path to directory containing raw and hand post_step1 pilot files.
%     EyeParams (struct): Display and acquisition parameters containing:
%         screenWidthInCm (float): Physical display screen width in centimeters.
%         screenHeightInCm (float): Physical display screen height in centimeters.
%         samplingFreq (float): Eyetracker sampling frequency in Hz.
%     ui_group_str (str): Participant group folder name (e.g., 'G01').
%     ui_subjectID_int (str | int): Unique participant identifier (e.g., '101' or 101).
%     ui_condition_str (str): Experimental condition tag (e.eg.,'bln').
%     ui_algo_str (str): Algorithm tag ('remo', 'mnh', or 'i2mc').
%     ui_targetSize_int (int): Experimental task target size flag (uses '_lg' suffix if equal to 2). If n/a to your data, use 1.
%     numTrials (int): Total number of experimental trials to segment (e.g., 50 for bln condition).
%
% Returns:
%     tuple: A tuple containing:
%         eyeTrialData (cell): 1-by-numTrials cell array containing algorithm event classification matrices segmented per trial.
%         raw_eyeTrialData (cell): 1-by-numTrials cell array containing raw Tobii gaze trajectories [relative_time, x_cm, y_cm] segmented per trial.
%         handTrialData (cell): 1-by-numTrials cell array of structs containing left (.left) and right (.right) hand trajectories [rel_time, x, y].
%
% Raises:
%     MException: If any required input data files (.mat, .xdf, .log) are missing.
%     MException: If loaded eye classification MAT file lacks 'sampledData'.

    % Preallocate cell arrays
    eyeTrialData          = cell(1, numTrials);
    raw_eyeTrialData      = cell(1, numTrials);
    handTrialData         = cell(1, numTrials);

    % ============= 1. Standardize Inputs & File Naming====================
    if isnumeric(ui_subjectID_int)
        subjStr = num2str(ui_subjectID_int);
    else
        subjStr = char(ui_subjectID_int);
    end

    sizeTag = '';
    if ui_targetSize_int == 2
        sizeTag = '_lg';
    end

    dataTitle = sprintf('data_%s_%s%s_%s', subjStr, ui_condition_str, sizeTag, ui_algo_str);

    % ====================2. Construct Cross-Platform Paths ===============
    algoResultsDir = fullfile(baseFilePath, 'post_step2', ui_group_str, [ui_algo_str '_results']);
    outFilePath    = fullfile(baseFilePath, 'post_step3', ui_group_str, ui_algo_str);
    if ~exist(outFilePath, 'dir'), mkdir(outFilePath); end

    % Smart resolution for converted MAT file variations
    eyeFile = fullfile(algoResultsDir, sprintf('data_%s_%s%s_%s_converted_v3.mat', subjStr, ui_condition_str, sizeTag, ui_algo_str));
    if ~isfile(eyeFile)
        % Fallback to standard converted file name
        eyeFile = fullfile(algoResultsDir, sprintf('data_%s_%s%s_%s_converted.mat', subjStr, ui_condition_str, sizeTag, ui_algo_str));
    end

    kinDir = fullfile(pilotPath, ui_group_str, 'post_step1');
    rawDir = fullfile(pilotPath, ui_group_str, 'raw');

    right_kinFile = fullfile(kinDir, sprintf('data_%s_%s_rh%s.mat', subjStr, ui_condition_str, sizeTag));
    left_kinFile  = fullfile(kinDir, sprintf('data_%s_%s_lh%s.mat', subjStr, ui_condition_str, sizeTag));
    lslFile       = fullfile(rawDir, sprintf('%s_%s%s.xdf', subjStr, ui_condition_str, sizeTag));
    presLogFile   = fullfile(rawDir, sprintf('%s_%s%s-Case 423.log', subjStr, ui_condition_str, sizeTag));

    % ==================== 3. Validate File Existence =====================
    requiredFiles = {eyeFile, right_kinFile, left_kinFile, lslFile, presLogFile};
    for f = 1:length(requiredFiles)
        if ~isfile(requiredFiles{f})
            error('Required file missing: %s', requiredFiles{f});
        end
    end

    % ===================== 4. Load Data ==================================
    right_kinData = load(right_kinFile);
    left_kinData  = load(left_kinFile);
    eyeData       = load(eyeFile);
    
    % Extract eye algorithm matrix
    if isfield(eyeData, 'sampledData')
        eyeMatrix = eyeData.sampledData;
    else
        error('Loaded eye file %s does not contain sampledData', eyeFile);
    end

    [tobii, pres_lslData] = load_TobiiPresentation(lslFile);
    tobii.xMean_cm = (mean(tobii.time_series([24 26], :), 'omitnan') - 0.5) * EyeParams.screenWidthInCm;
    tobii.yMean_cm = (0.5 - mean(tobii.time_series([25 27], :), 'omitnan')) * EyeParams.screenHeightInCm;

    % Adjust time stamps
    offset = Presentation_to_LSL_offset(pres_lslData, presLogFile);
    right_kinData.time_LSL = (right_kinData.time(:) / 1000) + offset;
    left_kinData.time_LSL  = (left_kinData.time(:) / 1000) + offset;

    % setup 1-to-1 time vector construction (fixed previous bug)
    % Create uniform double-precision LSL time vector for raw Tobii tracking
    N_raw = length(tobii.time_stamps);
    eye_LSL_time = tobii.time_stamps(1) + (0:N_raw-1)' / EyeParams.samplingFreq;

    % ======================= 5. Segment Trials Loop ======================
    right_wrong_trials = zeros(numTrials, 1);
    left_wrong_trials  = zeros(numTrials, 1);

    % --- 1. Compute Continuous True LSL Time for Eye Tracking ---
    %eye_LSL_time = eyeMatrix(:,1); 

    for iTrial = 1:numTrials
        if left_kinData.wrong_trial(iTrial) == 1 || right_kinData.wrong_trial(iTrial) == 1
            left_wrong_trials(iTrial)  = left_kinData.wrong_trial(iTrial);
            right_wrong_trials(iTrial) = right_kinData.wrong_trial(iTrial);
            continue;
        end
    
        % 1. Extract raw kinematic sample segments
        rh_idx = right_kinData.b1(iTrial):right_kinData.b2(iTrial);
        lh_idx = left_kinData.b1(iTrial):left_kinData.b2(iTrial);
    
        rh_time_LSL = right_kinData.time_LSL(rh_idx);
        lh_time_LSL = left_kinData.time_LSL(lh_idx);
    
        % 2. Establish trial onset reference (t = 0 s is the earliest physical movement)
        trial_onset_LSL = min(rh_time_LSL(1), lh_time_LSL(1));
    
        % 3. Calculate relative time grids for each hand independently (t = 0 relative)
        rh_rel_time = rh_time_LSL - trial_onset_LSL;
        lh_rel_time = lh_time_LSL - trial_onset_LSL;
    
        % 4. Store raw hand kinematics with native timestamp vectors
        handTrialData{iTrial} = struct();
        
        % Left Hand (raw sample rate & length preserved)
        % enfore columns:
        handTrialData{iTrial}.left = [lh_rel_time(:), ...
            reshape(left_kinData.x(lh_idx), [], 1), ...
            reshape(left_kinData.y(lh_idx), [], 1)];
                                  
        % Right Hand (raw sample rate & length preserved)
        handTrialData{iTrial}.right = [rh_rel_time(:), ...
            reshape(right_kinData.x(rh_idx), [], 1), ...
            reshape(right_kinData.y(rh_idx), [], 1)];
    
        % 5. Segment Eye Tracking relative to the same trial onset (t = 0 s)
        trial_offset_LSL = max(rh_time_LSL(end), lh_time_LSL(end));
        eye_mask = (eye_LSL_time >= trial_onset_LSL) & (eye_LSL_time <= trial_offset_LSL);
        
        eye_rel_time = eye_LSL_time(eye_mask) - trial_onset_LSL;
    
        raw_eyeTrialData{iTrial} = [eye_rel_time(:), ...
                                    tobii.xMean_cm(eye_mask)', ...
                                    tobii.yMean_cm(eye_mask)'];
        % eyeTrialData{iTrial} = [eye_rel_time(:), ...
        %                         eyeMatrix(eye_mask,2:4)];
    
        % Segment algorithm event classifications matching the eye time window
        [~, i_t1_eye] = min(abs(eye_LSL_time - trial_onset_LSL));
        [~, i_t2_eye] = min(abs(eye_LSL_time - trial_offset_LSL));
        
        eyeTrialData{iTrial} = eyeMatrix(i_t1_eye:i_t2_eye, :);

    end
    
    % OLD: 
    % for iTrial = 1:numTrials
    %     if left_kinData.wrong_trial(iTrial) == 1
    %         left_wrong_trials(iTrial) = 1;
    %         fprintf('Trial %d: LH Wrong Trial\n', iTrial);
    %         continue;
    %     elseif right_kinData.wrong_trial(iTrial) == 1
    %         right_wrong_trials(iTrial) = 1;
    %         fprintf('Trial %d: RH Wrong Trial\n', iTrial);
    %         continue;
    %     end
    % 
    %     % Extract trial indices
    %     trialSeg_rh = right_kinData.b1(iTrial):right_kinData.b2(iTrial);
    %     trialSeg_lh = left_kinData.b1(iTrial):left_kinData.b2(iTrial);
    % 
    %     % Match kinematic timestamps to Tobii
    %     start_time_rh = right_kinData.time_LSL(trialSeg_rh(1));
    %     end_time_rh   = right_kinData.time_LSL(trialSeg_rh(end));
    %     start_time_lh = left_kinData.time_LSL(trialSeg_lh(1));
    %     end_time_lh   = left_kinData.time_LSL(trialSeg_lh(end));
    % 
    %     [~, i_t1_rh] = min(abs(tobii.time_stamps - start_time_rh));
    %     [~, i_t2_rh] = min(abs(tobii.time_stamps - end_time_rh));
    %     [~, i_t1_lh] = min(abs(tobii.time_stamps - start_time_lh));
    %     [~, i_t2_lh] = min(abs(tobii.time_stamps - end_time_lh));
    % 
    %     % Determine bounding trial range across hands
    %     i_t1_tobii = min(i_t1_rh, i_t1_lh);
    %     i_t2_tobii = max(i_t2_rh, i_t2_lh);
    % 
    %     trialSeg_eye = i_t1_tobii:i_t2_tobii;
    % 
    %     % Segment Raw Eye Data
    %     eye_start_time = time_from_zero(trialSeg_eye(1));
    %     eye_stop_time  = time_from_zero(trialSeg_eye(end));
    % 
    %     raw_eyeTrialData{iTrial} = [time_from_zero(trialSeg_eye)', ...
    %                                 tobii.xMean_cm(trialSeg_eye)', ...
    %                                 tobii.yMean_cm(trialSeg_eye)'];
    % 
    %     % Segment Event Classified Eye Data
    %     [~, i_t1_eye] = min(abs(eyeMatrix(:, 1) - eye_start_time));
    %     [~, i_t2_eye] = min(abs(eyeMatrix(:, 1) - eye_stop_time));
    % 
    %     eye_trial = eyeMatrix(i_t1_eye:i_t2_eye, :);
    %     eyeTrialData{iTrial}          = eye_trial;
    %     bySample_eyeTrialData{iTrial} = eye_trial;
    % 

    % end

    % ============== 6. Save Segmented Trial Results ======================
    outFile = fullfile(outFilePath, [dataTitle, '.mat']);
    save(outFile, 'left_wrong_trials', 'right_wrong_trials', 'handTrialData', 'eyeTrialData', 'raw_eyeTrialData');
    fprintf('Trial segmentation complete for %d trials. Output saved to: %s\n', numTrials, outFile);
end