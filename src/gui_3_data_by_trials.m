function gui_3_data_by_trials()
% Interactive GUI wrapper for trial segmentation and QC diagnostic analysis.
%
% Launches a graphical interface (uifigure) to configure project filepaths, 
% participant identifiers, display metrics, and algorithm parameters for trial 
% segmentation. Performs pre-processing file existence checks, calls the trial 
% segmentation pipeline (get_data_by_trials), and computes post-execution quality 
% control (QC) metrics including signal dropout and invalid trial rates.
%
% Args:
%     None
%
% Returns:
%     None
%
% Raises:
%     None


    % --- Create Main Window ---
    fig = uifigure('Name', 'Step 3: Get Data by Trials', 'Position', [100, 100, 780, 740]);
    mainLayout = uigridlayout(fig, [3, 1]);
    mainLayout.RowHeight = {320, 150, '1x'};
    mainLayout.RowSpacing = 8;
    mainLayout.Padding = [10 10 10 10];

    % --- Panel 1: Parameter Inputs ---
    inputPanel = uipanel(mainLayout, 'Title', 'Input Parameters & Configuration');
    inputGrid = uigridlayout(inputPanel, [7, 4]);
    inputGrid.RowHeight = {28, 28, 28, 28, 28, 28, 36};
    inputGrid.RowSpacing = 5;
    inputGrid.Padding = [8 8 8 8];
    inputGrid.ColumnWidth = {110, '1x', 110, '1x'};

    % Row 1: Output Path
    lblBase = uilabel(inputGrid, 'Text', 'Output Path:');
    lblBase.Layout.Row = 1; lblBase.Layout.Column = 1;
    
    efBasePath = uieditfield(inputGrid, 'text', 'Value', pwd);
    efBasePath.Layout.Row = 1; efBasePath.Layout.Column = [2, 3];
    
    btnBrowseBase = uibutton(inputGrid, 'Text', 'Browse...', 'ButtonPushedFcn', @(~,~) selectDir(efBasePath));
    btnBrowseBase.Layout.Row = 1; btnBrowseBase.Layout.Column = 4;

    % Row 2: Pilot Path
    lblPilot = uilabel(inputGrid, 'Text', 'Pilot Path:');
    lblPilot.Layout.Row = 2; lblPilot.Layout.Column = 1;
    
    efPilotPath = uieditfield(inputGrid, 'text', 'Value', pwd);
    efPilotPath.Layout.Row = 2; efPilotPath.Layout.Column = [2, 3];
    
    btnBrowsePilot = uibutton(inputGrid, 'Text', 'Browse...', 'ButtonPushedFcn', @(~,~) selectDir(efPilotPath));
    btnBrowsePilot.Layout.Row = 2; btnBrowsePilot.Layout.Column = 4;

    % Row 3: Subject & Group
    lblGroup = uilabel(inputGrid, 'Text', 'Group String:');
    lblGroup.Layout.Row = 3; lblGroup.Layout.Column = 1;
    efGroup = uieditfield(inputGrid, 'text', 'Value', 'G01');
    efGroup.Layout.Row = 3; efGroup.Layout.Column = 2;

    lblSubj = uilabel(inputGrid, 'Text', 'Subject ID:');
    lblSubj.Layout.Row = 3; lblSubj.Layout.Column = 3;
    efSubjID = uieditfield(inputGrid, 'text', 'Value', '101');
    efSubjID.Layout.Row = 3; efSubjID.Layout.Column = 4;

    % Row 4: Condition & Algorithm
    lblCond = uilabel(inputGrid, 'Text', 'Condition:');
    lblCond.Layout.Row = 4; lblCond.Layout.Column = 1;
    efCondition = uieditfield(inputGrid, 'text', 'Value', 'bln');
    efCondition.Layout.Row = 4; efCondition.Layout.Column = 2;

    lblAlgo = uilabel(inputGrid, 'Text', 'Algorithm:');
    lblAlgo.Layout.Row = 4; lblAlgo.Layout.Column = 3;
    ddAlgo = uidropdown(inputGrid, 'Items', {'I2MC', 'MNH', 'REMoDNaV'}, ...
        'ItemsData', {'i2mc', 'mnh', 'remo'});
    ddAlgo.Layout.Row = 4; ddAlgo.Layout.Column = 4;

    % Row 5: Target Size & Trial Count
    lblTarget = uilabel(inputGrid, 'Text', 'Target Size:');
    lblTarget.Layout.Row = 5; lblTarget.Layout.Column = 1;
    ddTargetSize = uidropdown(inputGrid, 'Items', {'1 (Small)', '2 (Large)'}, 'ItemsData', [1, 2]);
    ddTargetSize.Layout.Row = 5; ddTargetSize.Layout.Column = 2;

    lblTrials = uilabel(inputGrid, 'Text', 'Num Trials:');
    lblTrials.Layout.Row = 5; lblTrials.Layout.Column = 3;
    efNumTrials = uieditfield(inputGrid, 'numeric', 'Value', 50, 'Limits', [1, 1000]);
    efNumTrials.Layout.Row = 5; efNumTrials.Layout.Column = 4;

    % Row 6: Display Dimensions
    lblScrW = uilabel(inputGrid, 'Text', 'Screen Width (cm):');
    lblScrW.Layout.Row = 6; lblScrW.Layout.Column = 1;
    efScreenWidth = uieditfield(inputGrid, 'numeric', 'Value', 47.7, 'Limits', [1, 300]);
    efScreenWidth.Layout.Row = 6; efScreenWidth.Layout.Column = 2;

    lblScrH = uilabel(inputGrid, 'Text', 'Screen Height (cm):');
    lblScrH.Layout.Row = 6; lblScrH.Layout.Column = 3;
    efScreenHeight = uieditfield(inputGrid, 'numeric', 'Value', 26.8, 'Limits', [1, 300]);
    efScreenHeight.Layout.Row = 6; efScreenHeight.Layout.Column = 4;

    % Row 7: Execution Button (Spartan Green)
    btnRun = uibutton(inputGrid, 'Text', 'Run Pre-QC & Extract Trials', ...
        'BackgroundColor', [0.098 0.271 0.23], 'FontColor', 'w', 'FontWeight', 'bold');
    btnRun.Layout.Row = 7;
    btnRun.Layout.Column = [1, 4];

    % --- Panel 2: Pre Safety Checks Output ---
    preProcessPanel = uipanel(mainLayout, 'Title', 'Pre Processing Check Log');
    preProcessGrid = uigridlayout(preProcessPanel, [1, 1]);
    txtpreProcess = uitextarea(preProcessGrid, 'Editable', 'off', 'Value', {'Awaiting execution...'});

    % --- Panel 3: Post-Execution Quality Control (QC) Summary ---
    qcPanel = uipanel(mainLayout, 'Title', 'Post Processing QC Diagnostics');
    qcGrid = uigridlayout(qcPanel, [1, 2]);
    qcGrid.ColumnWidth = {'1x', 240};
    txtQC = uitextarea(qcGrid, 'Editable', 'off', 'Value', {'QC statistics will display here.'});
    gaugeBox = uigridlayout(qcGrid, [2, 1]);
    gaugeBox.RowHeight = {22, '1x'};
    uilabel(gaugeBox, 'Text', '% Invalid Trials', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
    gaugeInvalid = uigauge(gaugeBox, 'semicircular', 'Limits', [0 100]);
    
    % Attach Main Call-Back Fcn
    btnRun.ButtonPushedFcn = @(~,~) executePipeline(...
        efBasePath.Value, efPilotPath.Value, efGroup.Value, efSubjID.Value, ...
        efCondition.Value, ddAlgo.Value, ddTargetSize.Value, efNumTrials.Value, ...
        efScreenWidth.Value, efScreenHeight.Value, txtpreProcess, txtQC, gaugeInvalid, fig);

    function selectDir(editField)
        chosenDir = uigetdir(editField.Value, 'Select Folder');
        if chosenDir ~= 0
            editField.Value = chosenDir;
        end
    end
end

 
function executePipeline(baseFilePath, pilotPath, ui_group_str, ui_subjectID, ui_condition_str, ui_algo_str, ui_targetSize_int, numTrials, screenW, screenH, txtpreProcess, txtQC, gaugeInvalid, fig)

    % Clear logs
    txtpreProcess.Value = {''};
    txtQC.Value = {''};

    % --- 1. RUN PRE SAFETY CHECKS ---
    logMessage(txtpreProcess, '[CHECK 1/4] Validating input paths...');
    if ~exist(baseFilePath, 'dir') || ~exist(pilotPath, 'dir')
        uialert(fig, 'Base Path or Pilot Path directory does not exist!', 'Path Error');
        logMessage(txtpreProcess, 'FAILED: Invalid base or pilot directory paths.');
        return;
    end

    sizeTag = '';
    if ui_targetSize_int == 2, sizeTag = '_lg'; end

    subjStr = num2str(ui_subjectID);
    algoResultsDir = fullfile(baseFilePath, 'post_step2', ui_group_str, [ui_algo_str '_results']);
    eyeFile_v3     = fullfile(algoResultsDir, sprintf('data_%s_%s%s_%s_converted_v3.mat', subjStr, ui_condition_str, sizeTag, ui_algo_str));
    eyeFile_std    = fullfile(algoResultsDir, sprintf('data_%s_%s%s_%s_converted.mat', subjStr, ui_condition_str, sizeTag, ui_algo_str));

    resolvedEyeFile = eyeFile_v3;
    if ~isfile(eyeFile_v3)
        resolvedEyeFile = eyeFile_std;
    end

    kinDir        = fullfile(pilotPath, ui_group_str, 'post_step1');
    rawDir        = fullfile(pilotPath, ui_group_str, 'raw');
    right_kinFile = fullfile(kinDir, sprintf('data_%s_%s_rh%s.mat', subjStr, ui_condition_str, sizeTag));
    left_kinFile  = fullfile(kinDir, sprintf('data_%s_%s_lh%s.mat', subjStr, ui_condition_str, sizeTag));
    lslFile       = fullfile(rawDir, sprintf('%s_%s%s.xdf', subjStr, ui_condition_str, sizeTag));
    presLogFile   = fullfile(rawDir, sprintf('%s_%s%s-Case 423.log', subjStr, ui_condition_str, sizeTag));

    logMessage(txtpreProcess, '[CHECK 2/4] Verifying required raw and processed files...');
    filesToCheck = {resolvedEyeFile, right_kinFile, left_kinFile, lslFile, presLogFile};
    missingCount = 0;

    for k = 1:length(filesToCheck)
        if isfile(filesToCheck{k})
            logMessage(txtpreProcess, sprintf('  [OK] Found: %s', filesToCheck{k}));
        else
            logMessage(txtpreProcess, sprintf('  [MISSING] %s', filesToCheck{k}));
            missingCount = missingCount + 1;
        end
    end

    if missingCount > 0
        uialert(fig, sprintf('Pre-processing failed: %d required file(s) missing.', missingCount), 'Missing Files');
        return;
    end

    logMessage(txtpreProcess, '[CHECK 3/4] Validating screen hardware parameters...');
    if screenW <= 0 || screenH <= 0
        uialert(fig, 'Screen dimensions must be positive non-zero values.', 'Parameter Error');
        return;
    end

    logMessage(txtpreProcess, '[CHECK 4/4] Pre-processing checks passed successfully.');

    % --- 2. EXECUTE DATA EXTRACTION ---
    EyeParams.screenWidthInCm  = screenW;
    EyeParams.screenHeightInCm = screenH;
    EyeParams.samplingFreq = 120;

    d = uiprogressdlg(fig, 'Title', 'Processing Data', 'Message', 'Splitting data into trials...');
    try
        [eyeTrialData, raw_eyeTrialData, handTrialData] = get_data_by_trials(baseFilePath, pilotPath, EyeParams, ui_group_str, ...
            ui_subjectID, ui_condition_str, ui_algo_str, ui_targetSize_int, numTrials);
        close(d);
    catch ME
        close(d);
        uialert(fig, sprintf('Execution Error: %s', ME.message), 'Pipeline Error');
        logMessage(txtpreProcess, sprintf('CRITICAL FAIL: %s', ME.message));
        return;
    end

    logMessage(txtQC, sprintf('--- QC REPORT: Subject %s (%s) ---', subjStr, ui_condition_str));
    outMatPath = fullfile(baseFilePath, 'post_step3', ui_group_str, ui_algo_str, ...
        sprintf('data_%s_%s%s_%s.mat', subjStr, ui_condition_str, sizeTag, ui_algo_str));
    savedData = load(outMatPath);
    
    badLH = sum(savedData.left_wrong_trials == 1);
    badRH = sum(savedData.right_wrong_trials == 1);
    invalidTotal = sum((savedData.left_wrong_trials | savedData.right_wrong_trials) > 0);
    pctInvalid = (invalidTotal / numTrials) * 100;
    gaugeInvalid.Value = pctInvalid;

    % Identify valid trials (not marked as wrong trials)
    validTrials = find(~(savedData.left_wrong_trials | savedData.right_wrong_trials));
    
    totalEyeSamples = 0;
    nanEyeSamples   = 0;
    shortEyeTrials  = []; % Track valid trials with < 50 eye samples

    for idx = validTrials(:)'
        % 1. Check length of classified eyeTrialData
        if idx <= length(savedData.eyeTrialData) && ~isempty(savedData.eyeTrialData{idx})
            nEyeSamples = size(savedData.eyeTrialData{idx}, 1);
        else
            nEyeSamples = 0;
        end

        if nEyeSamples < 50
            shortEyeTrials(end+1) = idx; %#ok<AGROW>
        end

        % 2. Calculate NaN dropout in raw_eyeTrialData
        if idx <= length(savedData.raw_eyeTrialData) && ~isempty(savedData.raw_eyeTrialData{idx})
            xVals = savedData.raw_eyeTrialData{idx}(:, 2);
            totalEyeSamples = totalEyeSamples + length(xVals);
            nanEyeSamples   = nanEyeSamples + sum(isnan(xVals));
        end
    end

    pctEyeLoss = 0;
    if totalEyeSamples > 0
        pctEyeLoss = (nanEyeSamples / totalEyeSamples) * 100;
    end

    % Populate QC Summary Log
    logMessage(txtQC, sprintf('Total Processed Trials: %d', numTrials));
    logMessage(txtQC, sprintf('Left Hand Flagged Trials: %d', badLH));
    logMessage(txtQC, sprintf('Right Hand Flagged Trials: %d', badRH));
    logMessage(txtQC, sprintf('Total Rejected Trials: %d (%.1f%%)', invalidTotal, pctInvalid));
    logMessage(txtQC, sprintf('Valid Trials Remaining: %d', length(validTrials)));
    logMessage(txtQC, sprintf('Eye Tracking Signal Dropout: %.2f%%', pctEyeLoss));

    % Flag Data Safety Warnings
    if ~isempty(shortEyeTrials)
        trialListStr = strjoin(string(shortEyeTrials), ', ');
        logMessage(txtQC, sprintf('WARNING: %d valid trial(s) have < 50 eye samples: [Trials %s]', ...
            length(shortEyeTrials), trialListStr));
        
        % Popup dialog notification
        uialert(fig, sprintf('%d valid trial(s) contain < 50 eye samples:\nTrials: %s\n\nPlease check kinematic boundary markers.', ...
            length(shortEyeTrials), trialListStr), 'Short Eye Segment Warning', 'Icon', 'warning');
    end

    if pctInvalid > 25.0
        logMessage(txtQC, 'WARNING: Rejecting > 25% of trials due to kinematic errors.');
    end
    if pctEyeLoss > 20.0
        logMessage(txtQC, 'WARNING: High eye tracking sample loss (> 20% NaN). Check participant dataset.');
    end
    if pctInvalid <= 25.0 && pctEyeLoss <= 20.0 && isempty(shortEyeTrials)
        logMessage(txtQC, 'STATUS: Dataset meets quality control thresholds.');
    end
end

function logMessage(txtArea, msg)
    txtArea.Value = [txtArea.Value; {msg}];
end