function gui_4_kde_roi_analysis()
% Launches the GUI wrapper for the Step 4 KDE ROI analysis pipeline.
% 
% Launches a graphical interface (uifigure) for configuring participant files, 
% parameter files, and classification algorithm selection. Executes trial- and 
% condition-level region-of-interest (ROI) metrics, including dwell times, 
% gaze transition matrices, stationary distributions. Option to Embed scanpaths, 
% heatmaps, and digraphs directly into interactive GUI tabs.
%
% Args:
%   None
%
% Returns:
%   None
% 
% Raises:
%   None
%

    fig = uifigure('Name', 'ET Pipeline Step4: KDE ROI Analysis', 'Position', [100, 100, 1200, 800]);
    
    % Main Layout Split: Left Controls/Logs vs Right Visualizations
    mainLayout = uigridlayout(fig, [1, 2]);
    mainLayout.ColumnWidth = {420, '1x'};
    mainLayout.Padding = [10 10 10 10];

    % --- Left Column Layout ---
    leftGrid = uigridlayout(mainLayout, [2, 1]);
    leftGrid.RowHeight = {340, '1x'};
    leftGrid.Padding = [0 0 0 0];

    % Panel 1: Settings
    inputPanel = uipanel(leftGrid, 'Title', 'Configuration Parameters');
    inputGrid  = uigridlayout(inputPanel, [8, 4]);
    inputGrid.RowHeight   = {28, 28, 28, 28, 28, 28, 28, 36};
    inputGrid.ColumnWidth = {110, '1x', 110, '1x'};

    % Row 1: Base Path
    lblBase = uilabel(inputGrid, 'Text', 'Base Path:');
    lblBase.Layout.Row = 1; lblBase.Layout.Column = 1;
    efBasePath = uieditfield(inputGrid, 'text', 'Value', pwd);
    efBasePath.Layout.Row = 1; efBasePath.Layout.Column = [2, 3];
    btnBase = uibutton(inputGrid, 'Text', 'Browse...', 'ButtonPushedFcn', @(~,~) selectDir(efBasePath));
    btnBase.Layout.Row = 1; btnBase.Layout.Column = 4;

    % Row 2: Subject List
    lblSubj = uilabel(inputGrid, 'Text', 'Participant ID:');
    lblSubj.Layout.Row = 2; lblSubj.Layout.Column = 1;
    efSubjects = uieditfield(inputGrid, 'text', 'Value', '101');
    efSubjects.Layout.Row = 2; efSubjects.Layout.Column = [2, 4];

    % Row 3: Group & Condition
    lblGrp = uilabel(inputGrid, 'Text', 'Group String:');
    lblGrp.Layout.Row = 3; lblGrp.Layout.Column = 1;
    efGroup = uieditfield(inputGrid, 'text', 'Value', 'G01');
    efGroup.Layout.Row = 3; efGroup.Layout.Column = 2;
    
    lblCond = uilabel(inputGrid, 'Text', 'Condition:');
    lblCond.Layout.Row = 3; lblCond.Layout.Column = 3;
    efCondition = uieditfield(inputGrid, 'text', 'Value', 'bln');
    efCondition.Layout.Row = 3; efCondition.Layout.Column = 4;

    % Row 4: Algorithm
    lblAlgo = uilabel(inputGrid, 'Text', 'Algorithm:');
    lblAlgo.Layout.Row = 4; lblAlgo.Layout.Column = 1;
    ddAlgo = uidropdown(inputGrid, 'Items', {'I2MC', 'MNH', 'REMoDNaV'}, 'ItemsData', {'i2mc', 'mnh', 'remo'});
    ddAlgo.Layout.Row = 4; ddAlgo.Layout.Column = [2, 4];

    % Row 5: Visualization Flags
    cbTrialFigs = uicheckbox(inputGrid, 'Text', 'Show Trial Figs', 'Value', true);
    cbTrialFigs.Layout.Row = 5; cbTrialFigs.Layout.Column = 2;
    cbCondFigs  = uicheckbox(inputGrid, 'Text', 'Show Condition Figs', 'Value', true);
    cbCondFigs.Layout.Row = 5; cbCondFigs.Layout.Column = 4;

    % Row 6: Embed Option
    cbEmbedInGUI = uicheckbox(inputGrid, 'Text', 'Embed Plots in GUI', 'Value', true);
    cbEmbedInGUI.Layout.Row = 6; cbEmbedInGUI.Layout.Column = [2, 4];

    % Row 7: Eye Params Script
    lblParams = uilabel(inputGrid, 'Text', 'Eye Params Script:');
    lblParams.Layout.Row = 7; lblParams.Layout.Column = 1;
    efParamsScript = uieditfield(inputGrid, 'text', 'Value', 'eye_params.m');
    efParamsScript.Layout.Row = 7; efParamsScript.Layout.Column = [2, 4];

    % Row 8: Run Button
    btnRun = uibutton(inputGrid, 'Text', 'Run KDE Analysis', ...
        'BackgroundColor', [0.098 0.271 0.23], 'FontColor', 'w', 'FontWeight', 'bold');
    btnRun.Layout.Row = 8; btnRun.Layout.Column = [1, 4];

    % Panel 2: Execution Log
    logPanel = uipanel(leftGrid, 'Title', 'Diagnostics Log');
    logGrid  = uigridlayout(logPanel, [1, 1]);
    txtLog   = uitextarea(logGrid, 'Editable', 'off', 'Value', {'Awaiting pipeline run...'});

    % --- Right Column Layout (Visualization Area) ---
    plotPanel = uipanel(mainLayout, 'Title', 'Embedded Visualizations');
    plotLayout = uigridlayout(plotPanel, [1, 1]);
    plotLayout.Padding = [2 2 2 2];
    
    tabGroup = uitabgroup(plotLayout);
    
    % Tab 1: Trial Level
    tabTrial = uitab(tabGroup, 'Title', 'Dwell Time per Trial');
    gridTrial = uigridlayout(tabTrial, [1, 1]);
    axTrial = uiaxes(gridTrial);
    title(axTrial, 'Trial-Level Dwell Time per KDE ROI');
    
    guiAxes = struct();
    guiAxes.axTrial = axTrial;

    % Create 5 Condition Tabs dynamically
    numConditions = 5;
    for c = 1:numConditions
        tabCond = uitab(tabGroup, 'Title', sprintf('Condition %d', c));
        gridCond = uigridlayout(tabCond, [2, 2]);
        guiAxes.cond(c).axScanpath   = uiaxes(gridCond); guiAxes.cond(c).axScanpath.Layout.Row = 1; guiAxes.cond(c).axScanpath.Layout.Column = 1;
        guiAxes.cond(c).axHeatmap    = uiaxes(gridCond); guiAxes.cond(c).axHeatmap.Layout.Row = 1; guiAxes.cond(c).axHeatmap.Layout.Column = 2;
        guiAxes.cond(c).axBar        = uiaxes(gridCond); guiAxes.cond(c).axBar.Layout.Row = 2; guiAxes.cond(c).axBar.Layout.Column = 1;
        guiAxes.cond(c).axTransition = uiaxes(gridCond); guiAxes.cond(c).axTransition.Layout.Row = 2; guiAxes.cond(c).axTransition.Layout.Column = 2;
    end

    % Attach Callback
    btnRun.ButtonPushedFcn = @(~,~) runCallback(...
        efBasePath.Value, efSubjects.Value, efGroup.Value, ...
        efCondition.Value, ddAlgo.Value, cbTrialFigs.Value, ...
        cbCondFigs.Value, cbEmbedInGUI.Value, efParamsScript.Value, txtLog, fig, guiAxes);

    function selectDir(ef)
        d = uigetdir(ef.Value, 'Select Directory');
        if d ~= 0, ef.Value = d; end
    end
end

function runCallback(baseFilePath, subjectStr, groupStr, condStr, algoStr, showTrialFigs, showCondFigs, embedInGUI, paramsScript, txtLog, fig, guiAxes)
% Validates GUI inputs and triggers the primary KDE ROI analysis function.
% 
% Parses participant ID strings, validates file paths, loads parameter scripts, 
% and handles pipeline exceptions while updating the progress dialog and UI text log.
% 
% Args:
%     baseFilePath (str): Directory path containing input data and step folders.
%     subjectStr (str): Character vector representing participant IDs (e.g., '101:105').
%     groupStr (str): Name string identifying the experimental group (e.g., 'G01').
%     condStr (str): Name string identifying the experimental condition (e.g., 'bln').
%     algoStr (str): Short name string for the target algorithm (e.g., 'i2mc', 'mnh', 'remo').
%     showTrialFigs (bool): Flag to enable or disable trial-level figure rendering.
%     showCondFigs (bool): Flag to enable or disable condition-level figure rendering.
%     embedInGUI (bool): Flag indicating whether figures render into GUI tabs or external windows.
%     paramsScript (str): File name/path of the MATLAB script containing eye parameters.
%     txtLog (matlab.ui.control.TextArea): UI text area object used for streaming logs.
%     fig (matlab.ui.Figure): Parent UI figure reference used for UI alerts and dialogs.
%     guiAxes (struct): Structure containing references to target embedded uiaxes components.
% 
% Returns:
%   None
% Raises:    
%   None
%


    txtLog.Value = {''};
    logMsg(txtLog, '[START] Validating run inputs...');
    
    if ~exist(baseFilePath, 'dir')
        uialert(fig, 'Invalid Base Path Directory.', 'Path Error');
        return;
    end

    try
        subjList = eval(['[' subjectStr ']']);
    catch
        uialert(fig, 'Failed to parse participant List. Use valid MATLAB array syntax (e.g., 101:112, 114:121).', 'Input Error');
        return;
    end

    if ~isfile(paramsScript)
        uialert(fig, sprintf('Params script "%s" not found on path.', paramsScript), 'Missing File');
        return;
    end

    kdeFilePath = fullfile(baseFilePath, 'post_step4', groupStr, algoStr, 'kdePrimaryROIs.mat');
    if ~isfile(kdeFilePath)
        uialert(fig, sprintf('KDE ROI file not found at: %s', kdeFilePath), 'Missing File');
        return;
    end

    logMsg(txtLog, sprintf('Loading experimental parameters from %s...', paramsScript));
    run(paramsScript); 
    if ~exist('EyeParams', 'var')
        uialert(fig, 'Script ran, but "EyeParams" structure was not created.', 'Variable Error');
        return;
    end

    d = uiprogressdlg(fig, 'Title', 'Processing', 'Message', 'Running KDE ROI analysis pipeline...');

    try
        process_kde_roi_analysis(baseFilePath, subjList, EyeParams, ...
            groupStr, condStr, algoStr, double(showTrialFigs), double(showCondFigs), ...
            embedInGUI, guiAxes, @(msg) logMsg(txtLog, msg));
        close(d);
        logMsg(txtLog, '[COMPLETE] Pipeline run finished successfully.');
    catch ME
        close(d);
        uialert(fig, sprintf('Pipeline Failed: %s', ME.message), 'Run Error');
        logMsg(txtLog, sprintf('CRITICAL ERROR: %s', ME.message));
    end
end

function logMsg(txt, msg)
    txt.Value = [txt.Value; {msg}];
end

function process_kde_roi_analysis(baseFilePath, subject_list, EyeParams, ui_group_str, ui_condition_str, ui_algo_str, showTrialFigs, showFigs, embedInGUI, guiAxes, logFcn)
% Executes trial and condition-level analysis using Kernel Density Estimation derived ROIs.
% 
% Loads spatial KDE ROI maps and processes participant fixation events. Computes dwell times, distance to 
% centroids, transition matrices,  stationary distributions, and gaze transition entropy metrics before 
% saving output `.mat` files.
% 
% Args:
%     baseFilePath (str): Base file directory containing raw and step data folders.
%     subject_list (list or numpy.ndarray): Numeric array of participant IDs to analyze.
%     EyeParams (struct): Structure holding eyetracker spatial and temporal conversion factors.
%     ui_group_str (str): Identifier string of the target experimental group (e.g., 'G01').
%     ui_condition_str (str): Identifier string of the target experimental condition.(e.g., 'bln')
%     ui_algo_str (str): Identifier string of the target processing algorithm.
%     showTrialFigs (int): Binary indicator (1 or 0) toggling trial-level plots.
%     showFigs (int): Binary indicator (1 or 0) toggling condition-level plots.
%     embedInGUI (bool): If True, plots populate GUI tab axes; otherwise, new figure windows spawn.
%     guiAxes (struct): Struct holding target handle arrays for embedded GUI axes.
%     logFcn (function, optional): Callback function for message logging. Defaults to printing to console.
% 
% Returns:
%     dict: Saves processed output structs directly to 'data_<ID>_<cond>_<algo>_kde.mat' files.
% 
% Raises:
%     MException: Propagates runtime exceptions encounterable during processing or plotting.
% 


    if nargin < 11 || isempty(logFcn)
        logFcn = @(msg) fprintf('%s\n', msg);
    end

    numTrials = 50;
    numConditions = 5;

    % Bounds definition
    x_min = -23.85; x_max = 23.85;
    y_min = -13.4;  y_max = 13.4;

    % Load KDE ROIs
    kdeFilePath = fullfile(baseFilePath, 'post_step4', ui_group_str, ui_algo_str, 'kdePrimaryROIs.mat');
    logFcn(sprintf('Loading KDE primary ROIs: %s', kdeFilePath));
    loadedKde = load(kdeFilePath);
    primaryKde = loadedKde.primaryKde;
    [h, w] = size(primaryKde.labeled);

    for iSubject = 1:length(subject_list)
        subjectID = subject_list(iSubject);
        subjStr = num2str(subjectID);
        logFcn(sprintf('Analyzing Participant %d with Algorithm %s...', subjectID, ui_algo_str));

        % Input fixation file
        inMatFile = fullfile(baseFilePath, 'post_step4', ui_group_str, ui_algo_str, sprintf('data_%d_%s_%s_v9.mat', subjectID, ui_condition_str, ui_algo_str));
        if ~isfile(inMatFile)
            inMatFile = fullfile(baseFilePath, 'post_step4', ui_group_str, ui_algo_str, sprintf('data_%d_%s_%s.mat', subjectID, ui_condition_str, ui_algo_str));
            if ~isfile(inMatFile)
                logFcn(sprintf('WARNING: Input file not found for Participant %d. Skipping...', subjectID));
                continue;
            end
        end

        outFile = fullfile(baseFilePath, 'post_step4', ui_group_str, ui_algo_str, sprintf('data_%d_%s_%s_kde.mat', subjectID, ui_condition_str, ui_algo_str));
        loadedData = load(inMatFile);
        
        if isfield(loadedData, 'predefinedData')
            predefinedData = loadedData.predefinedData;
        else
            logFcn(sprintf('ERROR: "predefinedData" structure missing in %s', inMatFile));
            continue;
        end

        kdeData = struct();
        kdeData.TrialLevel = struct();
        kdeData.ConditionLevel = struct();

        % Preallocate Trial-Level Metrics
        kdeData.TrialLevel.conditionLabel     = zeros(numTrials, 1);
        kdeData.TrialLevel.pursCountA         = zeros(numTrials, 1);
        kdeData.TrialLevel.pursDurA           = zeros(numTrials, 1);
        kdeData.TrialLevel.pursCountB         = zeros(numTrials, 1);
        kdeData.TrialLevel.pursDurB           = zeros(numTrials, 1);
        kdeData.TrialLevel.pursCountC         = zeros(numTrials, 1);
        kdeData.TrialLevel.pursDurC           = zeros(numTrials, 1);
        kdeData.TrialLevel.fixCountA          = zeros(numTrials, 1);
        kdeData.TrialLevel.tDwellA            = zeros(numTrials, 1);
        kdeData.TrialLevel.meanFixDurA        = zeros(numTrials, 1);
        kdeData.TrialLevel.mdcA               = zeros(numTrials, 1);
        kdeData.TrialLevel.fixCountB          = zeros(numTrials, 1);
        kdeData.TrialLevel.tDwellB            = zeros(numTrials, 1);
        kdeData.TrialLevel.meanFixDurB        = zeros(numTrials, 1);
        kdeData.TrialLevel.mdcB               = zeros(numTrials, 1);
        kdeData.TrialLevel.fixCountC          = zeros(numTrials, 1);
        kdeData.TrialLevel.tDwellC            = zeros(numTrials, 1);
        kdeData.TrialLevel.meanFixDurC        = zeros(numTrials, 1);
        kdeData.TrialLevel.mdcC               = zeros(numTrials, 1);
        kdeData.TrialLevel.norm_tDwellA       = zeros(numTrials, 1);
        kdeData.TrialLevel.norm_tDwellB       = zeros(numTrials, 1);
        kdeData.TrialLevel.norm_tDwellC       = zeros(numTrials, 1);
        kdeData.TrialLevel.roiTotalEngagement = zeros(numTrials, 1);

        %% Trial Level Analysis
        for i = 1:numTrials
            if i > 1 && i < 11
                kdeData.TrialLevel.conditionLabel(i) = 1;
            elseif i > 11 && i < 21
                kdeData.TrialLevel.conditionLabel(i) = 2;
            elseif i > 21 && i < 31
                kdeData.TrialLevel.conditionLabel(i) = 3;
            elseif i > 31 && i < 41
                kdeData.TrialLevel.conditionLabel(i) = 4;
            elseif i > 41 && i < 51
                kdeData.TrialLevel.conditionLabel(i) = 5;
            else
                kdeData.TrialLevel.conditionLabel(i) = NaN;
            end

            if i > length(predefinedData.trialBlockedEvents) || isempty(predefinedData.trialBlockedEvents{1, i})
                logFcn(sprintf('WARNING: Trial %d is empty for Participant %d.', i, subjectID));
                continue;
            end

            trialData = predefinedData.trialBlockedEvents{1, i};
            eventLabel    = trialData(:, 2);
            eventMeanX    = trialData(:, 3);
            eventMeanY    = trialData(:, 4);
            eventDuration = trialData(:, 5);

            % Smooth pursuits
            pursRows = (eventLabel == 8);
            x_purs   = eventMeanX(pursRows);
            y_purs   = eventMeanY(pursRows);
            dur_purs = eventDuration(pursRows);

            % Fixations
            fixRows = (eventLabel == 1);
            x_fix   = eventMeanX(fixRows);
            y_fix   = eventMeanY(fixRows);
            dur_fix = eventDuration(fixRows);

            % Map fixations to KDE ROIs
            numFix = length(x_fix);
            roiLabels = zeros(numFix, 1);

            for iFix = 1:numFix
                col = floor((x_fix(iFix) - x_min) / primaryKde.dx) + 1;
                row = floor((y_fix(iFix) - y_min) / primaryKde.dy) + 1;

                if row >= 1 && row <= h && col >= 1 && col <= w
                    roiLabels(iFix) = primaryKde.labeled(row, col);
                else
                    roiLabels(iFix) = -1;
                end
            end

            inROI_idx    = (roiLabels > 0);
            activeLabels = roiLabels(inROI_idx);
            activeDurs   = dur_fix(inROI_idx);

            if sum(inROI_idx) > 0
                roiDwell = accumarray(activeLabels, activeDurs, [primaryKde.nROIs, 1]);
            else
                roiDwell = zeros(primaryKde.nROIs, 1);
            end

            if sum(roiLabels(roiLabels > 0)) > 0
                insideROICount = accumarray(roiLabels(roiLabels > 0), 1, [primaryKde.nROIs, 1]);
            else
                insideROICount = zeros(primaryKde.nROIs, 1);
            end

            inROIFixX = x_fix(inROI_idx);
            inROIFixY = y_fix(inROI_idx);

            if ~isempty(activeLabels)
                cx_all = primaryKde.centroids_cm(activeLabels, 1);
                cy_all = primaryKde.centroids_cm(activeLabels, 2);
                activeDistances = sqrt((inROIFixX - cx_all).^2 + (inROIFixY - cy_all).^2);
                meanDistPerROI  = accumarray(activeLabels, activeDistances, [primaryKde.nROIs, 1], @mean, NaN);
            else
                meanDistPerROI  = NaN(primaryKde.nROIs, 1);
            end

            % Map smooth pursuits to ROIs
            numPurs       = length(x_purs);
            pursRoiLabels = zeros(numPurs, 1);
            roiPursDwell  = zeros(primaryKde.nROIs, 1);

            if numPurs > 0
                for iPurs = 1:numPurs
                    col = floor((x_purs(iPurs) - x_min) / primaryKde.dx) + 1;
                    row = floor((y_purs(iPurs) - y_min) / primaryKde.dy) + 1;
                    if row >= 1 && row <= h && col >= 1 && col <= w
                        pursRoiLabels(iPurs) = primaryKde.labeled(row, col);
                    else
                        pursRoiLabels(iPurs) = -1;
                    end
                end

                inRoiPurs_idx    = (pursRoiLabels > 0);
                activePursLabels = pursRoiLabels(inRoiPurs_idx);
                activePursDurs   = dur_purs(inRoiPurs_idx);

                if ~isempty(activePursLabels)
                    roiPursDwell = accumarray(activePursLabels, activePursDurs, [primaryKde.nROIs, 1]);
                end
            end

            if sum(pursRoiLabels(pursRoiLabels > 0)) > 0
                pursCount = accumarray(pursRoiLabels(pursRoiLabels > 0), 1, [primaryKde.nROIs, 1]);
            else
                pursCount = zeros(primaryKde.nROIs, 1);
            end

            % Assign Variables for Trial-Level (Index mapping: 1=A, 3=B, 2=C)
            if any(pursRows) && primaryKde.nROIs >= 3
                kdeData.TrialLevel.pursCountA(i) = pursCount(1);
                kdeData.TrialLevel.pursDurA(i)   = roiPursDwell(1);
                kdeData.TrialLevel.pursCountB(i) = pursCount(3);
                kdeData.TrialLevel.pursDurB(i)   = roiPursDwell(3);
                kdeData.TrialLevel.pursCountC(i) = pursCount(2);
                kdeData.TrialLevel.pursDurC(i)   = roiPursDwell(2);
                kdeData.TrialLevel.roiTotalEngagement(i) = sum(roiDwell(:)) + sum(roiPursDwell(:));
            else
                kdeData.TrialLevel.pursCountA(i) = NaN; kdeData.TrialLevel.pursDurA(i) = NaN;
                kdeData.TrialLevel.pursCountB(i) = NaN; kdeData.TrialLevel.pursDurB(i) = NaN;
                kdeData.TrialLevel.pursCountC(i) = NaN; kdeData.TrialLevel.pursDurC(i) = NaN;
                kdeData.TrialLevel.roiTotalEngagement(i) = sum(roiDwell(:));
            end

            if primaryKde.nROIs >= 3
                kdeData.TrialLevel.fixCountA(i) = insideROICount(1);
                kdeData.TrialLevel.tDwellA(i)   = roiDwell(1);
                kdeData.TrialLevel.mdcA(i)      = ifelse(kdeData.TrialLevel.fixCountA(i) >= 2, meanDistPerROI(1) * double(EyeParams.cm2Deg), NaN);

                kdeData.TrialLevel.fixCountB(i) = insideROICount(3);
                kdeData.TrialLevel.tDwellB(i)   = roiDwell(3);
                kdeData.TrialLevel.mdcB(i)      = ifelse(kdeData.TrialLevel.fixCountB(i) >= 2, meanDistPerROI(3) * double(EyeParams.cm2Deg), NaN);

                kdeData.TrialLevel.fixCountC(i) = insideROICount(2);
                kdeData.TrialLevel.tDwellC(i)   = roiDwell(2);
                kdeData.TrialLevel.mdcC(i)      = ifelse(kdeData.TrialLevel.fixCountC(i) >= 2, meanDistPerROI(2) * double(EyeParams.cm2Deg), NaN);

                allDwells   = [kdeData.TrialLevel.tDwellA(i), kdeData.TrialLevel.tDwellB(i), kdeData.TrialLevel.tDwellC(i)];
                totalDwells = sum(allDwells, 'omitnan');

                if totalDwells > 0
                    kdeData.TrialLevel.norm_tDwellA(i) = kdeData.TrialLevel.tDwellA(i) / totalDwells;
                    kdeData.TrialLevel.norm_tDwellB(i) = kdeData.TrialLevel.tDwellB(i) / totalDwells;
                    kdeData.TrialLevel.norm_tDwellC(i) = kdeData.TrialLevel.tDwellC(i) / totalDwells;
                elseif any(fixRows)
                    kdeData.TrialLevel.norm_tDwellA(i) = 0;
                    kdeData.TrialLevel.norm_tDwellB(i) = 0;
                    kdeData.TrialLevel.norm_tDwellC(i) = 0;
                else
                    kdeData.TrialLevel.norm_tDwellA(i) = NaN;
                    kdeData.TrialLevel.norm_tDwellB(i) = NaN;
                    kdeData.TrialLevel.norm_tDwellC(i) = NaN;
                end
            end
        end

        % Plotting Trial Level Visualizations
        if showTrialFigs == 1
            if embedInGUI
                ax = guiAxes.axTrial;
                cla(ax);
            else
                figure('Name', sprintf('KDE Trial Dwell: Participant %s', subjStr));
                ax = gca;
            end
            x = 1:numTrials;
            hold(ax, 'on');
            scatter(ax, x, kdeData.TrialLevel.tDwellA, 'filled', 'o', 'MarkerFaceColor', 'r');
            scatter(ax, x, kdeData.TrialLevel.tDwellB, 'filled', 'o', 'MarkerFaceColor', 'g');
            scatter(ax, x, kdeData.TrialLevel.tDwellC, 'filled', 'o', 'MarkerFaceColor', 'b');
            xline(ax, [11 21 31 41]);
            hold(ax, 'off');
            title(ax, sprintf('Dwell Time per KDE ROI (Participant %s)', subjStr));
            xlabel(ax, 'Trial'); ylabel(ax, 'Time (s)');
            legend(ax, {'Left', 'Right', 'Center'});
        end

        %% Condition Level Analysis
        for c = 1:numConditions
            condName = sprintf('c%d', c);
            if ~isfield(predefinedData.ConditionLevel, condName)
                continue;
            end

            condData      = predefinedData.ConditionLevel.(condName).eventMatrix;
            eventLabel    = condData(:, 2);
            eventMeanX    = condData(:, 3);
            eventMeanY    = condData(:, 4);
            eventDuration = condData(:, 5);

            pursRows = (eventLabel == 8);
            x_purs   = eventMeanX(pursRows);
            y_purs   = eventMeanY(pursRows);
            dur_purs = eventDuration(pursRows);

            fixRows = (eventLabel == 1);
            x_fix   = eventMeanX(fixRows);
            y_fix   = eventMeanY(fixRows);
            dur_fix = eventDuration(fixRows);

            numFix    = length(x_fix);
            roiLabels = zeros(numFix, 1);

            for iFix = 1:numFix
                col = floor((x_fix(iFix) - x_min) / primaryKde.dx) + 1;
                row = floor((y_fix(iFix) - y_min) / primaryKde.dy) + 1;

                if row >= 1 && row <= h && col >= 1 && col <= w
                    roiLabels(iFix) = primaryKde.labeled(row, col);
                else
                    roiLabels(iFix) = -1;
                end
            end

            inROI_idx      = (roiLabels > 0);
            activeLabels   = roiLabels(inROI_idx);
            activeDurs     = dur_fix(inROI_idx);

            roiDwell       = accumarray(activeLabels, activeDurs, [primaryKde.nROIs, 1]);
            tDwell         = sum(roiDwell);
            insideROICount = accumarray(roiLabels(roiLabels > 0), 1, [primaryKde.nROIs, 1]);

            inROIFixX = x_fix(inROI_idx);
            inROIFixY = y_fix(inROI_idx);

            if ~isempty(activeLabels)
                cx_all = primaryKde.centroids_cm(activeLabels, 1);
                cy_all = primaryKde.centroids_cm(activeLabels, 2);
                activeDistances = sqrt((inROIFixX - cx_all).^2 + (inROIFixY - cy_all).^2);
                meanDistPerROI  = accumarray(activeLabels, activeDistances, [primaryKde.nROIs, 1], @mean, NaN);
            else
                meanDistPerROI  = NaN(primaryKde.nROIs, 1);
            end

            % Smooth pursuits
            numPurs       = length(x_purs);
            pursRoiLabels = zeros(numPurs, 1);
            roiPursDwell  = zeros(primaryKde.nROIs, 1);

            if numPurs > 0
                for iPurs = 1:numPurs
                    col = floor((x_purs(iPurs) - x_min) / primaryKde.dx) + 1;
                    row = floor((y_purs(iPurs) - y_min) / primaryKde.dy) + 1;
                    if row >= 1 && row <= h && col >= 1 && col <= w
                        pursRoiLabels(iPurs) = primaryKde.labeled(row, col);
                    else
                        pursRoiLabels(iPurs) = -1;
                    end
                end

                inRoiPurs_idx    = (pursRoiLabels > 0);
                activePursLabels = pursRoiLabels(inRoiPurs_idx);
                activePursDurs   = dur_purs(inRoiPurs_idx);

                if ~isempty(activePursLabels)
                    roiPursDwell = accumarray(activePursLabels, activePursDurs, [primaryKde.nROIs, 1]);
                end
            end

            pursCount          = accumarray(pursRoiLabels(pursRoiLabels > 0), 1, [primaryKde.nROIs, 1]);
            roiTotalEngagement = roiDwell(:) + roiPursDwell(:);

            % Save vars
            kdeData.ConditionLevel.(condName).roiDwell           = roiDwell;
            kdeData.ConditionLevel.(condName).tDwell             = tDwell;
            kdeData.ConditionLevel.(condName).insideROICount     = insideROICount;
            kdeData.ConditionLevel.(condName).mdc                 = meanDistPerROI * double(EyeParams.cm2Deg);
            kdeData.ConditionLevel.(condName).roiPursDwell       = roiPursDwell;
            kdeData.ConditionLevel.(condName).tPursDwell         = sum(roiPursDwell);
            kdeData.ConditionLevel.(condName).pursCount          = pursCount;
            kdeData.ConditionLevel.(condName).roiTotalEngagement = sum(roiTotalEngagement);

            % Transition Matrix & Entropy Analysis
            seq = roiLabels(roiLabels > 0);

            if primaryKde.nROIs > 1 && length(seq) > 1
                transitionMatrix = zeros(primaryKde.nROIs);
                for k = 1:(length(seq)-1)
                    from = seq(k);
                    to   = seq(k+1);
                    if from > 0 && to > 0
                        transitionMatrix(from, to) = transitionMatrix(from, to) + 1;
                    end
                end

                sparseSafetyCheck = 0;
                matrixSum = sum(transitionMatrix(:));
                kdeData.ConditionLevel.(condName).matrixSum = matrixSum;

                if matrixSum < (primaryKde.nROIs * 2) % numROIs * 2 for predefined & kde
                    sparseSafetyCheck = 1;
                    logFcn(sprintf('WARNING: Sparse transition matrix in Cond %d (Sum = %d)', c, matrixSum));
                end

                rowSums = sum(transitionMatrix, 2);
                p_ij    = transitionMatrix ./ (rowSums + 1e-9);
                p_ij(isnan(p_ij)) = 0;

                p_i = roiDwell / (sum(roiDwell) + 1e-9);
                Hs  = -sum(p_i(p_i > 0) .* log2(p_i(p_i > 0)));

                Ht = 0;
                for idx = 1:primaryKde.nROIs
                    if p_i(idx) > 0
                        row_p       = p_ij(idx, :);
                        row_entropy = -sum(row_p(row_p > 0) .* log2(row_p(row_p > 0)));
                        Ht          = Ht + (p_i(idx) * row_entropy);
                    end
                end

                Hs_rel = Hs / log2(primaryKde.nROIs);
                Ht_rel = Ht / log2(primaryKde.nROIs);

                kdeData.ConditionLevel.(condName).sparseSafetyCheck = sparseSafetyCheck;
                kdeData.ConditionLevel.(condName).p_ij   = p_ij;
                kdeData.ConditionLevel.(condName).p_i    = p_i;
                kdeData.ConditionLevel.(condName).Hs     = Hs;
                kdeData.ConditionLevel.(condName).Hs_rel = Hs_rel;
                kdeData.ConditionLevel.(condName).Ht     = Ht;
                kdeData.ConditionLevel.(condName).Ht_rel = Ht_rel;

                if showFigs == 1
                    %labels = string(1:primaryKde.nROIs);
                    labels = {'Left ROI', 'Cent. ROI', 'Right ROI'};
                    if embedInGUI
                        ax1 = guiAxes.cond(c).axScanpath;   cla(ax1);
                        ax2 = guiAxes.cond(c).axHeatmap;    cla(ax2);
                        ax3 = guiAxes.cond(c).axBar;        cla(ax3);
                        ax4 = guiAxes.cond(c).axTransition; cla(ax4);
                    else
                        figure('Color', 'w', 'Name', sprintf('KDE Cond %d: Participant %s', c, subjStr));
                        sgtitle([ui_algo_str ' ' subjStr ' KDE Condition ' num2str(c)]);
                        ax1 = subplot(2, 2, 1);
                        ax2 = subplot(2, 2, 2);
                        ax3 = subplot(2, 2, 3);
                        ax4 = subplot(2, 2, 4);
                    end

                    % 1. Spatial ROIs (KDE Heatmap + Outlines + Fixations)
                    imagesc(ax1, primaryKde.x_grid, primaryKde.y_grid, primaryKde.kde);
                    set(ax1, 'YDir', 'normal');
                    colormap(ax1, parula);
                    hold(ax1, 'on');

                    [B, ~] = bwboundaries(primaryKde.labeled, 'noholes');
                    for k = 1:length(B)
                        boundary = B{k};
                        bx = interp1(1:length(primaryKde.x_grid), primaryKde.x_grid, boundary(:,2));
                        by = interp1(1:length(primaryKde.y_grid), primaryKde.y_grid, boundary(:,1));
                        plot(ax1, bx, by, 'r-', 'LineWidth', 2);
                        if k <= size(primaryKde.centroids_cm, 1)
                            text(ax1, primaryKde.centroids_cm(k,1), primaryKde.centroids_cm(k,2), num2str(k), ...
                                'Color', 'w', 'FontSize', 12, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
                        end
                    end
                    plot(ax1, x_fix, y_fix, 'k.', 'MarkerSize', 4);
                    hold(ax1, 'off');
                    title(ax1, sprintf('Spatial ROIs'));
                    xlabel(ax1, 'X (cm)'); ylabel(ax1, 'Y (cm)');

                    % 2. Transition Probability Matrix
                    imagesc(ax2, p_ij);
                    colormap(ax2, flipud(hot));
                    clim(ax2, [0 1]);
                    colorbar(ax2);
                    ax2.XTick = 1:primaryKde.nROIs;
                    ax2.XTickLabel = labels;
                    ax2.YTick = 1:primaryKde.nROIs;
                    ax2.YTickLabel = labels;
                    title(ax2, sprintf('Transition Prob (H_t = %.2f)', Ht_rel));

                    [numRows, numCols] = size(p_ij);
                    for r = 1:numRows
                        for col = 1:numCols
                            text(ax2, col, r, sprintf('%.2f', p_ij(r, col)), ...
                                'HorizontalAlignment', 'center', ...
                                'Color', ifelse(p_ij(r, col) > 0.5, 'w', 'k'), ...
                                'FontWeight', 'bold');
                        end
                    end

                    % 3. Stationary Distribution
                    bar(ax3, p_i, 'FaceColor', [0.2 0.6 0.8]);
                    set(ax3, 'XTick', 1:primaryKde.nROIs, 'XTickLabel', labels);
                    ylabel(ax3, 'Probability (\pi_i)');
                    title(ax3, sprintf('Stationary Dist (H_s = %.2f)', Hs_rel));
                    ylim(ax3, [0 1]);

                    % 4. Transition Map / Digraph
                    if primaryKde.nROIs > 1
                        G = digraph(transitionMatrix, cellstr(labels));
                        LWidths = 5 * G.Edges.Weight / max(1, max(G.Edges.Weight));
                        plot(ax4, G, 'XData', primaryKde.centroids_cm(:,1), 'YData', primaryKde.centroids_cm(:,2), 'LineWidth', LWidths);
                        axis(ax4, 'equal');
                        title(ax4, 'Gaze Transition Map');
                    end
                end
            else
                logFcn(sprintf('Condition %d: Not enough transitions to compute GTE reliably', c));
                kdeData.ConditionLevel.(condName).sparseSafetyCheck = NaN;
                kdeData.ConditionLevel.(condName).matrixSum         = NaN;
                kdeData.ConditionLevel.(condName).p_ij              = [];
                kdeData.ConditionLevel.(condName).p_i               = [];
                kdeData.ConditionLevel.(condName).Hs                = NaN;
                kdeData.ConditionLevel.(condName).Hs_rel            = NaN;
                kdeData.ConditionLevel.(condName).Ht                = NaN;
                kdeData.ConditionLevel.(condName).Ht_rel            = NaN;
                
            end
        end

        save(outFile, 'kdeData');
        logFcn(sprintf('Successfully saved: %s', outFile));
    end
end

function val = ifelse(cond, trueVal, falseVal)
    if cond
        val = trueVal;
    else
        val = falseVal;
    end
end