function gui_4_kmeans_roi_analysis()
% Interactive GUI wrapper for k-means derived ROI eye-tracking analysis.
%
% Launches a graphical interface (uifigure) for configuring participant files, 
% parameter files, and classification algorithm selection. Executes trial- and 
% condition-level region-of-interest (ROI) metrics, including dwell times, 
% gaze transition matrices, stationary distributions. Option to Embed scanpaths, 
% heatmaps, and digraphs directly into interactive GUI tabs.
%
% Args:
%     None
%
% Returns:
%     None
%
% Raises:
%     None

    fig = uifigure('Name', 'ET Pipeline Step4: k-Means ROI Analysis', 'Position', [100, 100, 1200, 800]);
    
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
    btnRun = uibutton(inputGrid, 'Text', 'Run k-Means Analysis', ...
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
    title(axTrial, 'Trial-Level Dwell Time per k-Means ROI');
    
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
    txtLog.Value = {''};
    logMsg(txtLog, '[START] Validating run inputs...');
    
    if ~exist(baseFilePath, 'dir')
        uialert(fig, 'Invalid Base Path Directory.', 'Path Error');
        return;
    end

    try
        subjList = eval(['[' subjectStr ']']);
    catch
        uialert(fig, 'Failed to parse participant List. Use valid MATLAB array syntax (e.g., 101:110).', 'Input Error');
        return;
    end

    if ~isfile(paramsScript)
        uialert(fig, sprintf('Params script "%s" not found on path.', paramsScript), 'Missing File');
        return;
    end

    kMeansFilePath = fullfile(baseFilePath, 'post_step4', groupStr, algoStr, 'kMeansPrimaryROIs.mat');
    if ~isfile(kMeansFilePath)
        uialert(fig, sprintf('k-Means ROI file not found at: %s', kMeansFilePath), 'Missing File');
        return;
    end

    logMsg(txtLog, sprintf('Loading experimental parameters from %s...', paramsScript));
    run(paramsScript); 
    if ~exist('EyeParams', 'var')
        uialert(fig, 'Script ran, but "EyeParams" structure was not created.', 'Variable Error');
        return;
    end

    d = uiprogressdlg(fig, 'Title', 'Processing', 'Message', 'Running k-Means ROI analysis pipeline...');
    try
        process_kmeans_roi_analysis(baseFilePath, subjList, EyeParams, ...
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

function process_kmeans_roi_analysis(baseFilePath, subject_list, EyeParams, ui_group_str, ui_condition_str, ui_algo_str, showTrialFigs, showFigs, embedInGUI, guiAxes, logFcn)
% Executes trial and condition-level k-Means ROI analysis on eye-tracking data.
% 
% Loads pre-computed k-Means primary cluster centroids, maps fixation and smooth 
% pursuit events to the nearest ROI using k-nearest neighbors, and computes quantitative 
% gaze metrics including dwell times, normalized dwell, fixation counts, distance to 
% centroids, transition matrices, stationary distributions, and gaze transition entropy. 
% Generates scanpath, heatmap, and transition digraph plots, saving summary structures to .mat file.
% 
% Args:
%     baseFilePath (str): Path string pointing to the root project directory.
%     subject_list (list or numpy.ndarray): Array or vector containing numeric participant IDs.
%     EyeParams (struct): Structure containing spatial conversion factors (e.g., cm2Deg) and target coordinates.
%     ui_group_str (str): String identifier specifying the participant group (e.g., 'G01').
%     ui_condition_str (str): String identifier specifying the condition (e.g., 'bln').
%     ui_algo_str (str): String identifier specifying the event-detection algorithm (e.g., 'i2mc').
%     showTrialFigs (int): Flag (1 or 0) indicating whether to render trial-level scatter plots.
%     showFigs (int): Flag (1 or 0) indicating whether to render condition-level dashboard figures.
%     embedInGUI (bool): Flag determining if plots render inside embedded GUI axes or standalone figure windows.
%     guiAxes (struct): Structure containing handle references for embedded GUI axes.
%     logFcn (function, optional): Callback function handle for diagnostic log streaming. Defaults to console printing if omitted.
% 
% Returns:
%     None: Processed metrics are saved directly to 'data_<ID>_<cond>_<algo>_kmeans.mat' files on disk.
% 
% Raises:
%     MException: Propagates MATLAB runtime exceptions encountered during file I/O operations or graphics generation. 

    if nargin < 11 || isempty(logFcn)
        logFcn = @(msg) fprintf('%s\n', msg);
    end

    numTrials = 50;
    numConditions = 5;

    % Load optimized k-means centroids and Voronoi boundaries
    kMeansFilePath = fullfile(baseFilePath, 'post_step4', ui_group_str, ui_algo_str, 'kMeansPrimaryROIs.mat');
    logFcn(sprintf('Loading k-Means primary centroids: %s', kMeansFilePath));
    optK = load(kMeansFilePath);

    for iSubject = 1:length(subject_list)
        subjectID = subject_list(iSubject);
        subjStr = num2str(subjectID);
        logFcn(sprintf('Analyzing Participant %d with Algorithm %s...', subjectID, ui_algo_str));

        % Locate input data matrix
        inMatFile = fullfile(baseFilePath, 'post_step4', ui_group_str, ui_algo_str, sprintf('data_%d_%s_%s_v9.mat', subjectID, ui_condition_str, ui_algo_str));
        if ~isfile(inMatFile)
            inMatFile = fullfile(baseFilePath, 'post_step4', ui_group_str, ui_algo_str, sprintf('data_%d_%s_%s.mat', subjectID, ui_condition_str, ui_algo_str));
            if ~isfile(inMatFile)
                logFcn(sprintf('WARNING: Input file not found for Participant %d. Skipping...', subjectID));
                continue;
            end
        end

        outFile = fullfile(baseFilePath, 'post_step4', ui_group_str, ui_algo_str, sprintf('data_%d_%s_%s_kmeans.mat', subjectID, ui_condition_str, ui_algo_str));
        loadedData = load(inMatFile);

        if isfield(loadedData, 'predefinedData')
            predefinedData = loadedData.predefinedData;
        else
            logFcn(sprintf('ERROR: "predefinedData" structure missing in %s', inMatFile));
            continue;
        end

        kmeansData = struct();
        kmeansData.TrialLevel = struct();
        kmeansData.ConditionLevel = struct();

        % Preallocate Trial-Level Metrics
        kmeansData.TrialLevel.conditionLabel     = zeros(numTrials, 1);
        kmeansData.TrialLevel.pursCountA         = zeros(numTrials, 1);
        kmeansData.TrialLevel.pursDurA           = zeros(numTrials, 1);
        kmeansData.TrialLevel.pursCountB         = zeros(numTrials, 1);
        kmeansData.TrialLevel.pursDurB           = zeros(numTrials, 1);
        kmeansData.TrialLevel.pursCountC         = zeros(numTrials, 1);
        kmeansData.TrialLevel.pursDurC           = zeros(numTrials, 1);
        kmeansData.TrialLevel.fixCountA          = zeros(numTrials, 1);
        kmeansData.TrialLevel.tDwellA            = zeros(numTrials, 1);
        kmeansData.TrialLevel.meanFixDurA        = zeros(numTrials, 1);
        kmeansData.TrialLevel.mdcA               = zeros(numTrials, 1);
        kmeansData.TrialLevel.fixCountB          = zeros(numTrials, 1);
        kmeansData.TrialLevel.tDwellB            = zeros(numTrials, 1);
        kmeansData.TrialLevel.meanFixDurB        = zeros(numTrials, 1);
        kmeansData.TrialLevel.mdcB               = zeros(numTrials, 1);
        kmeansData.TrialLevel.fixCountC          = zeros(numTrials, 1);
        kmeansData.TrialLevel.tDwellC            = zeros(numTrials, 1);
        kmeansData.TrialLevel.meanFixDurC        = zeros(numTrials, 1);
        kmeansData.TrialLevel.mdcC               = zeros(numTrials, 1);
        kmeansData.TrialLevel.norm_tDwellA       = zeros(numTrials, 1);
        kmeansData.TrialLevel.norm_tDwellB       = zeros(numTrials, 1);
        kmeansData.TrialLevel.norm_tDwellC       = zeros(numTrials, 1);
        kmeansData.TrialLevel.roiTotalEngagement = zeros(numTrials, 1);

        %% Trial Level Analysis
        for i = 1:numTrials
            if i > 1 && i < 11
                kmeansData.TrialLevel.conditionLabel(i) = 1;
            elseif i > 11 && i < 21
                kmeansData.TrialLevel.conditionLabel(i) = 2;
            elseif i > 21 && i < 31
                kmeansData.TrialLevel.conditionLabel(i) = 3;
            elseif i > 31 && i < 41
                kmeansData.TrialLevel.conditionLabel(i) = 4;
            elseif i > 41 && i < 51
                kmeansData.TrialLevel.conditionLabel(i) = 5;
            else
                kmeansData.TrialLevel.conditionLabel(i) = NaN;
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

            % Nearest primaryCentroid for every event using knnsearch
            X_events = [eventMeanX, eventMeanY];
            [idx, dists] = knnsearch(optK.primaryCentroids, X_events);

            isFix  = (eventLabel == 1);
            isPurs = (eventLabel == 8);

            event_ROI_hit_A = (idx == 1); % Left-most Cluster
            event_ROI_hit_C = (idx == 2); % Middle Cluster
            event_ROI_hit_B = (idx == 3); % Right-most Cluster

            if any(isFix)
                % ROI A
                kmeansData.TrialLevel.fixCountA(i)   = sum(isFix & event_ROI_hit_A);
                kmeansData.TrialLevel.tDwellA(i)     = sum(eventDuration(isFix & event_ROI_hit_A));
                kmeansData.TrialLevel.meanFixDurA(i) = mean(eventDuration(isFix & event_ROI_hit_A));
                kmeansData.TrialLevel.mdcA(i)        = ifelse(kmeansData.TrialLevel.fixCountA(i) >= 2, mean(dists(isFix & event_ROI_hit_A)) * double(EyeParams.cm2Deg), NaN);

                % ROI C
                kmeansData.TrialLevel.fixCountC(i)   = sum(isFix & event_ROI_hit_C);
                kmeansData.TrialLevel.tDwellC(i)     = sum(eventDuration(isFix & event_ROI_hit_C));
                kmeansData.TrialLevel.meanFixDurC(i) = mean(eventDuration(isFix & event_ROI_hit_C));
                kmeansData.TrialLevel.mdcC(i)        = ifelse(kmeansData.TrialLevel.fixCountC(i) >= 2, mean(dists(isFix & event_ROI_hit_C)) * double(EyeParams.cm2Deg), NaN);

                % ROI B
                kmeansData.TrialLevel.fixCountB(i)   = sum(isFix & event_ROI_hit_B);
                kmeansData.TrialLevel.tDwellB(i)     = sum(eventDuration(isFix & event_ROI_hit_B));
                kmeansData.TrialLevel.meanFixDurB(i) = mean(eventDuration(isFix & event_ROI_hit_B));
                kmeansData.TrialLevel.mdcB(i)        = ifelse(kmeansData.TrialLevel.fixCountB(i) >= 2, mean(dists(isFix & event_ROI_hit_B)) * double(EyeParams.cm2Deg), NaN);

                allDwells   = [kmeansData.TrialLevel.tDwellA(i), kmeansData.TrialLevel.tDwellC(i), kmeansData.TrialLevel.tDwellB(i)];
                totalDwells = sum(allDwells);

                if totalDwells > 0
                    kmeansData.TrialLevel.norm_tDwellA(i) = kmeansData.TrialLevel.tDwellA(i) / totalDwells;
                    kmeansData.TrialLevel.norm_tDwellB(i) = kmeansData.TrialLevel.tDwellB(i) / totalDwells;
                    kmeansData.TrialLevel.norm_tDwellC(i) = kmeansData.TrialLevel.tDwellC(i) / totalDwells;
                else
                    kmeansData.TrialLevel.norm_tDwellA(i) = 0;
                    kmeansData.TrialLevel.norm_tDwellB(i) = 0;
                    kmeansData.TrialLevel.norm_tDwellC(i) = 0;
                end
            else
                kmeansData.TrialLevel.fixCountA(i)   = NaN; kmeansData.TrialLevel.tDwellA(i)   = NaN; kmeansData.TrialLevel.meanFixDurA(i) = NaN; kmeansData.TrialLevel.mdcA(i) = NaN;
                kmeansData.TrialLevel.fixCountB(i)   = NaN; kmeansData.TrialLevel.tDwellB(i)   = NaN; kmeansData.TrialLevel.meanFixDurB(i) = NaN; kmeansData.TrialLevel.mdcB(i) = NaN;
                kmeansData.TrialLevel.fixCountC(i)   = NaN; kmeansData.TrialLevel.tDwellC(i)   = NaN; kmeansData.TrialLevel.meanFixDurC(i) = NaN; kmeansData.TrialLevel.mdcC(i) = NaN;
                kmeansData.TrialLevel.norm_tDwellA(i) = NaN; kmeansData.TrialLevel.norm_tDwellB(i) = NaN; kmeansData.TrialLevel.norm_tDwellC(i) = NaN;
                totalDwells = NaN;
            end

            if any(isPurs)
                isPursInA = isPurs & event_ROI_hit_A;
                kmeansData.TrialLevel.pursCountA(i) = sum(isPursInA); kmeansData.TrialLevel.pursDurA(i) = sum(eventDuration(isPursInA));
                isPursInB = isPurs & event_ROI_hit_B;
                kmeansData.TrialLevel.pursCountB(i) = sum(isPursInB); kmeansData.TrialLevel.pursDurB(i) = sum(eventDuration(isPursInB));
                isPursInC = isPurs & event_ROI_hit_C;
                kmeansData.TrialLevel.pursCountC(i) = sum(isPursInC); kmeansData.TrialLevel.pursDurC(i) = sum(eventDuration(isPursInC));
                kmeansData.TrialLevel.roiTotalEngagement(i) = sum(totalDwells) + kmeansData.TrialLevel.pursDurA(i) + kmeansData.TrialLevel.pursDurC(i) + kmeansData.TrialLevel.pursDurB(i);
            else
                kmeansData.TrialLevel.pursCountA(i) = NaN; kmeansData.TrialLevel.pursDurA(i) = NaN;
                kmeansData.TrialLevel.pursCountB(i) = NaN; kmeansData.TrialLevel.pursDurB(i) = NaN;
                kmeansData.TrialLevel.pursCountC(i) = NaN; kmeansData.TrialLevel.pursDurC(i) = NaN;
                kmeansData.TrialLevel.roiTotalEngagement(i) = sum(totalDwells);
            end
        end

        % Plotting Trial Level Visualizations
        if showTrialFigs == 1
            if embedInGUI
                ax = guiAxes.axTrial;
                cla(ax);
            else
                figure('Name', sprintf('k-Means Dwell Time per Trial: Participant %s', subjStr));
                ax = gca;
            end

            x = 1:numTrials;
            hold(ax, 'on');
            scatter(ax, x, kmeansData.TrialLevel.tDwellA, 'filled', 'o', 'MarkerFaceColor', 'r');
            scatter(ax, x, kmeansData.TrialLevel.tDwellB, 'filled', 'o', 'MarkerFaceColor', 'g');
            scatter(ax, x, kmeansData.TrialLevel.tDwellC, 'filled', 'o', 'MarkerFaceColor', 'b');
            xline(ax, [11 21 31 41]);
            hold(ax, 'off');
            title(ax, sprintf('Dwell Time per k-Means ROI (Subj %s)', subjStr));
            xlabel(ax, 'Trial'); ylabel(ax, 'Time (s)');
            legend(ax, {'Left', 'Right', 'Center'});
        end

        %% Condition Level Analysis
        for c = 1:numConditions
            condName = sprintf('c%d', c);
            if ~isfield(predefinedData.ConditionLevel, condName)
                continue;
            end

            condData = predefinedData.ConditionLevel.(condName).eventMatrix;
            eventLabel    = condData(:, 2);
            eventMeanX    = condData(:, 3);
            eventMeanY    = condData(:, 4);
            eventDuration = condData(:, 5);

            X_events = [eventMeanX, eventMeanY];
            [idx, dists] = knnsearch(optK.primaryCentroids, X_events);

            isFix  = (eventLabel == 1);
            isPurs = (eventLabel == 8);

            event_ROI_hit_A = (idx == 1);
            event_ROI_hit_C = (idx == 2);
            event_ROI_hit_B = (idx == 3);

            if any(isFix)
                kmeansData.ConditionLevel.(condName).fixCountA   = sum(isFix & event_ROI_hit_A);
                kmeansData.ConditionLevel.(condName).tDwellA     = sum(eventDuration(isFix & event_ROI_hit_A));
                kmeansData.ConditionLevel.(condName).meanFixDurA = mean(eventDuration(isFix & event_ROI_hit_A));
                kmeansData.ConditionLevel.(condName).mdcA        = mean(dists(isFix & event_ROI_hit_A)) * double(EyeParams.cm2Deg);

                kmeansData.ConditionLevel.(condName).fixCountC   = sum(isFix & event_ROI_hit_C);
                kmeansData.ConditionLevel.(condName).tDwellC     = sum(eventDuration(isFix & event_ROI_hit_C));
                kmeansData.ConditionLevel.(condName).meanFixDurC = mean(eventDuration(isFix & event_ROI_hit_C));
                kmeansData.ConditionLevel.(condName).mdcC        = mean(dists(isFix & event_ROI_hit_C)) * double(EyeParams.cm2Deg);

                kmeansData.ConditionLevel.(condName).fixCountB   = sum(isFix & event_ROI_hit_B);
                kmeansData.ConditionLevel.(condName).tDwellB     = sum(eventDuration(isFix & event_ROI_hit_B));
                kmeansData.ConditionLevel.(condName).meanFixDurB = mean(eventDuration(isFix & event_ROI_hit_B));
                kmeansData.ConditionLevel.(condName).mdcB        = mean(dists(isFix & event_ROI_hit_B)) * double(EyeParams.cm2Deg);
            else
                logFcn(sprintf('ERROR: No fixations in Condition %d for Participant %d', c, subjectID));
            end

            allDwells   = [kmeansData.ConditionLevel.(condName).tDwellA, kmeansData.ConditionLevel.(condName).tDwellC, kmeansData.ConditionLevel.(condName).tDwellB];
            totalDwells = sum(allDwells);

            if any(isPurs)
                isPursInA = isPurs & event_ROI_hit_A;
                kmeansData.ConditionLevel.(condName).pursCountA = sum(isPursInA); kmeansData.ConditionLevel.(condName).pursDurA = sum(eventDuration(isPursInA));
                isPursInB = isPurs & event_ROI_hit_B;
                kmeansData.ConditionLevel.(condName).pursCountB = sum(isPursInB); kmeansData.ConditionLevel.(condName).pursDurB = sum(eventDuration(isPursInB));
                isPursInC = isPurs & event_ROI_hit_C;
                kmeansData.ConditionLevel.(condName).pursCountC = sum(isPursInC); kmeansData.ConditionLevel.(condName).pursDurC = sum(eventDuration(isPursInC));
                kmeansData.ConditionLevel.(condName).roiTotalEngagement = totalDwells + kmeansData.ConditionLevel.(condName).pursDurA + kmeansData.ConditionLevel.(condName).pursDurC + kmeansData.ConditionLevel.(condName).pursDurB;
            else
                kmeansData.ConditionLevel.(condName).pursCountA = NaN; kmeansData.ConditionLevel.(condName).pursDurA = NaN;
                kmeansData.ConditionLevel.(condName).pursCountB = NaN; kmeansData.ConditionLevel.(condName).pursDurB = NaN;
                kmeansData.ConditionLevel.(condName).pursCountC = NaN; kmeansData.ConditionLevel.(condName).pursDurC = NaN;
                kmeansData.ConditionLevel.(condName).roiTotalEngagement = totalDwells;
            end

            % Transition Matrix & Entropy Analysis
            roiSequence = idx(isFix);
            roiSequence = roiSequence(roiSequence > 0);
            numROIs = 3;

            if length(roiSequence) > 1
                transitionMatrix = zeros(numROIs);
                for k = 1:(length(roiSequence)-1)
                    from = roiSequence(k);
                    to   = roiSequence(k+1);
                    if from > 0 && to > 0
                        transitionMatrix(from, to) = transitionMatrix(from, to) + 1;
                    end
                end

                sparseSafetyCheck = 0;
                matrixSum = sum(transitionMatrix(:));
                kmeansData.ConditionLevel.(condName).matrixSum = matrixSum;
                if matrixSum < (numROIs * numROIs) % numROIs * 2 for predefined & kde
                    sparseSafetyCheck = 1;
                    logFcn(sprintf('WARNING: Sparse transition matrix in Cond %d (Sum = %d)', c, matrixSum));
                end

                rowSums = sum(transitionMatrix, 2);
                p_ij    = transitionMatrix ./ rowSums;
                p_ij(isnan(p_ij)) = 0;

                if totalDwells > 0
                    p_i = (allDwells / totalDwells)';
                else
                    p_i = zeros(numROIs, 1);
                end

                Hs = -sum(p_i(p_i > 0) .* log2(p_i(p_i > 0)));
                Ht = 0;
                for i = 1:numROIs
                    if p_i(i) > 0
                        row_p       = p_ij(i, :);
                        row_entropy = -sum(row_p(row_p > 0) .* log2(row_p(row_p > 0)));
                        Ht          = Ht + (p_i(i) * row_entropy);
                    end
                end

                Hs_rel = Hs / log2(numROIs);
                Ht_rel = Ht / log2(numROIs);

                kmeansData.ConditionLevel.(condName).sparseSafetyCheck = sparseSafetyCheck;
                kmeansData.ConditionLevel.(condName).p_ij = p_ij;
                kmeansData.ConditionLevel.(condName).p_i  = p_i;
                kmeansData.ConditionLevel.(condName).Hs   = Hs;
                kmeansData.ConditionLevel.(condName).Hs_rel = Hs_rel;
                kmeansData.ConditionLevel.(condName).Ht   = Ht;
                kmeansData.ConditionLevel.(condName).Ht_rel = Ht_rel;

                if showFigs == 1
                    labels = {'Left ROI', 'Cent. ROI', 'Right ROI'};

                    if embedInGUI
                        ax1 = guiAxes.cond(c).axScanpath;   cla(ax1);
                        ax2 = guiAxes.cond(c).axHeatmap;    cla(ax2);
                        ax3 = guiAxes.cond(c).axBar;        cla(ax3);
                        ax4 = guiAxes.cond(c).axTransition; cla(ax4);
                    else
                        figure('Color', 'w', 'Name', sprintf('k-Means Cond %d: Participant %s', c, subjStr));
                        sgtitle([ui_algo_str ' ' subjStr ' k-Means Condition ' num2str(c)]);
                        ax1 = subplot(2, 2, 1);
                        ax2 = subplot(2, 2, 2);
                        ax3 = subplot(2, 2, 3);
                        ax4 = subplot(2, 2, 4);
                    end

                    fixIdx = find(isFix);
                    x      = eventMeanX(fixIdx);
                    y      = eventMeanY(fixIdx);
                    dur    = eventDuration(fixIdx);

                    % 1. Scanpath + Voronoi Boundaries
                    hold(ax1, 'on');
                    plot(ax1, x, y, '-', 'Color', [0.5 0.5 0.5 0.6], 'LineWidth', 1.5);
                    scatter(ax1, x, y, 20 + (dur / max(dur)) * 200, 1:length(x), 'filled', 'MarkerEdgeColor', 'k');
                    if isfield(optK, 'vx') && isfield(optK, 'vy')
                        plot(ax1, optK.vx, optK.vy, 'k-', 'LineWidth', 2);
                    end
                    axis(ax1, 'equal'); xlim(ax1, [-20 20]); ylim(ax1, [-5 15]);
                    xlabel(ax1, 'X (cm)'); ylabel(ax1, 'Y (cm)'); title(ax1, ['Scanpath Condition: ' num2str(c)]);
                    colormap(ax1, jet); hold(ax1, 'off');

                    % 2. Transition Probability Matrix
                    imagesc(ax2, p_ij);
                    colormap(ax2, flipud(hot));
                    clim(ax2, [0 1]);
                    colorbar(ax2);
                    ax2.XTick = 1:length(labels);
                    ax2.XTickLabel = labels;
                    ax2.YTick = 1:length(labels);
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
                    bar(ax3, p_i, 'FaceColor', [0.2 0.4 0.6]);
                    set(ax3, 'XTickLabel', labels); ylabel(ax3, 'Probability (\pi_i)'); 
                    title(ax3, sprintf('Stationary Dist (H_s = %.2f)', Hs_rel)); ylim(ax3, [0 1]);

                    % 4. Transition Digraph
                    roiX = [EyeParams.targetA_bln.X_cm, EyeParams.targetC_bln.X_cm, EyeParams.targetB_bln.X_cm];
                    roiY = [EyeParams.targetA_bln.Y_cm, EyeParams.targetC_bln.Y_cm, EyeParams.targetB_bln.Y_cm];
                    G = digraph(transitionMatrix, {'Left', 'Center', 'Right'});
                    LWidths = 5 * G.Edges.Weight / max(1, max(G.Edges.Weight));
                    plot(ax4, G, 'XData', roiX, 'YData', roiY, 'LineWidth', LWidths);
                    axis(ax4, 'equal'); title(ax4, 'Gaze Transition Map');
                end
            else
                kmeansData.ConditionLevel.(condName).sparseSafetyCheck = NaN;
                kmeansData.ConditionLevel.(condName).matrixSum         = NaN;
                kmeansData.ConditionLevel.(condName).p_ij              = [];
                kmeansData.ConditionLevel.(condName).p_i               = [];
                kmeansData.ConditionLevel.(condName).Hs                = NaN;
                kmeansData.ConditionLevel.(condName).Hs_rel            = NaN;
                kmeansData.ConditionLevel.(condName).Ht                = NaN;
                kmeansData.ConditionLevel.(condName).Ht_rel            = NaN;
                logFcn(sprintf('Condition %d: Not enough transitions', c));
            end
        end

        save(outFile, 'kmeansData');
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