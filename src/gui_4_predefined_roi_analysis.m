function gui_4_predefined_roi_analysis()
% Interactive GUI wrapper for predefined ROI eye-tracking analysis.
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



    fig = uifigure('Name', 'ET Pipeline Step4: Predefined ROI Analysis', 'Position', [100, 100, 1200, 800]);
    
    % Main Layout Split: Left (Settings/Logs) vs Right (Embedded Plots)
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

    % Row 4: Algorithm & Target Size
    lblAlgo = uilabel(inputGrid, 'Text', 'Algorithm:');
    lblAlgo.Layout.Row = 4; lblAlgo.Layout.Column = 1;
    ddAlgo = uidropdown(inputGrid, 'Items', {'I2MC', 'MNH', 'REMoDNaV'}, 'ItemsData', {'i2mc', 'mnh', 'remo'});
    ddAlgo.Layout.Row = 4; ddAlgo.Layout.Column = 2;
    
    lblTgt = uilabel(inputGrid, 'Text', 'Target Size:');
    lblTgt.Layout.Row = 4; lblTgt.Layout.Column = 3;
    ddTargetSize = uidropdown(inputGrid, 'Items', {'1 (Small)', '2 (Large)'}, 'ItemsData', [1, 2]);
    ddTargetSize.Layout.Row = 4; ddTargetSize.Layout.Column = 4;

    % Row 5: Visualization Flags
    cbTrialFigs = uicheckbox(inputGrid, 'Text', 'Show Trial Figs', 'Value', true);
    cbTrialFigs.Layout.Row = 5; cbTrialFigs.Layout.Column = 2;
    cbCondFigs  = uicheckbox(inputGrid, 'Text', 'Show Condition Figs', 'Value', true);
    cbCondFigs.Layout.Row = 5; cbCondFigs.Layout.Column = 4;

    % Row 6: Embed Option
    cbEmbedInGUI = uicheckbox(inputGrid, 'Text', 'Embed Plots in GUI', 'Value', true);
    cbEmbedInGUI.Layout.Row = 6; cbEmbedInGUI.Layout.Column = [2 4];

    % Row 7: Eye Params Script
    lblParams = uilabel(inputGrid, 'Text', 'Parameter File:');
    lblParams.Layout.Row = 7; lblParams.Layout.Column = 1;
    efParamsScript = uieditfield(inputGrid, 'text', 'Value', 'eye_params.m');
    efParamsScript.Layout.Row = 7; efParamsScript.Layout.Column = [2, 4];

    % Row 8: Run Button
    btnRun = uibutton(inputGrid, 'Text', 'Run Analysis', ...
        'BackgroundColor', [0.098 0.271 0.23], 'FontColor', 'w', 'FontWeight', 'bold');
    btnRun.Layout.Row = 8; btnRun.Layout.Column = [1, 4];

    % Panel 2: diagnostic Log
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
    title(axTrial, 'Trial-Level Dwell Time');
    
    % Store trial axis
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
        efCondition.Value, ddAlgo.Value, ddTargetSize.Value, cbTrialFigs.Value, ...
        cbCondFigs.Value, cbEmbedInGUI.Value, efParamsScript.Value, txtLog, fig, guiAxes);

    function selectDir(ef)
        d = uigetdir(ef.Value, 'Select Directory');
        if d ~= 0, ef.Value = d; end
    end
end

function runCallback(baseFilePath, subjectStr, groupStr, condStr, algoStr, targetSize, showTrialFigs, showCondFigs, embedInGUI, paramsScript, txtLog, fig, guiAxes)
% Executes pre-run validation checks and invokes the ROI analysis pipeline.
%
% Parses participant range strings, validates dependency files, loads parameter 
% definitions, and triggers process_predefined_roi_analysis.
%
% Args:
%     baseFilePath (str): Path to root project directory.
%     subjectStr (str): String representation of participant IDs (e.g., '101:105').
%     groupStr (str): Experimental group tag (e.g., 'G01').
%     condStr (str): Condition identifier tag (e.g., 'bln').
%     algoStr (str): Classification algorithm identifier ('i2mc', 'mnh', 'remo').
%     targetSize (int): Experimental task target size flag (uses '_lg' suffix if equal to 2). If n/a to your data, use 1.
%     showTrialFigs (bool): Flag to render trial-level figure axes.
%     showCondFigs (bool): Flag to render condition-level figure axes.
%     embedInGUI (bool): Flag to render directly inside GUI tab axes.
%     paramsScript (str): Path to parameter setup MATLAB script.
%     txtLog (matlab.ui.control.TextArea): Diagnostics log UI control.
%     fig (matlab.ui.Figure): Parent application window handle.
%     guiAxes (struct): Structure containing embedded uiaxes references.
%
% Returns:
%     None


    txtLog.Value = {''};
    logMsg(txtLog, '[START] Validating inputs...');
    if ~exist(baseFilePath, 'dir')
        uialert(fig, 'Invalid Base Path Directory.', 'Path Error');
        return;
    end

    try
        subjList = eval(['[' subjectStr ']']);
    catch
        uialert(fig, 'Failed to parse Participant List. Use valid MATLAB array syntax (e.g., 101:110).', 'Input Error');
        return;
    end

    if ~isfile(paramsScript)
        uialert(fig, sprintf('Params script "%s" not found on path.', paramsScript), 'Missing File');
        return;
    end

    logMsg(txtLog, sprintf('Loading experimental parameters from %s...', paramsScript));
    run(paramsScript); 
    if ~exist('EyeParams', 'var')
        uialert(fig, 'Script ran, but "EyeParams" structure was not created.', 'Variable Error');
        return;
    end

    d = uiprogressdlg(fig, 'Title', 'Processing', 'Message', 'Running eye analysis pipeline...');
    try
        process_predefined_roi_analysis(baseFilePath, subjList, EyeParams, ...
            groupStr, condStr, algoStr, targetSize, double(showTrialFigs), double(showCondFigs), ...
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
% Appends a single log entry to the visual UI diagnostic area.
%
% Args:
%     txt (matlab.ui.control.TextArea): Text area UI handle.
%     msg (str): Diagnostic string message.
%
% Returns:
%     None

    txt.Value = [txt.Value; {msg}];
end

function process_predefined_roi_analysis(baseFilePath, subject_list, EyeParams, ui_group_str, ui_condition_str, ui_algo_str, ui_targetSize_int, showTrialFigs, showFigs, embedInGUI, guiAxes, logFcn)
% Processes trial and condition ROI metrics and computes stationary/transition entropy.
%
% Performs spatial indexing against geometric predefined ROI boundaries (Targets A (left), 
% B (right), and C (center)). Extracts trial-by-trial dwell times, fixation counts, and 
% durations. Aggregates data into condition blocks to construct transition matrices, 
% stationary distributions, and relative transition entropies.
%
% Args:
%     baseFilePath (str): Root project folder path.
%     subject_list (array): Array of participant integer IDs.
%     EyeParams (struct): Visual angle and geometry parameters.
%     ui_group_str (str): Group identifier string.
%     ui_condition_str (str): Condition name string.
%     ui_algo_str (str): Algorithm tag.
%     ui_targetSize_int (int): Experimental task target size flag (uses '_lg' suffix if equal to 2). If n/a to your data, use 1.
%     showTrialFigs (double): Binary toggle for trial-level plotting (1/0).
%     showFigs (double): Binary toggle for condition-level plotting (1/0).
%     embedInGUI (bool): Binary switch for target axes (GUI vs standalone figure).
%     guiAxes (struct): Struct holding GUI axis references.
%     logFcn (function_handle): Function handle for diagnostic outputs.
%
% Returns:
%     None



    if nargin < 12 || isempty(logFcn)
        logFcn = @(msg) fprintf('%s\n', msg);
    end
    numTrials = 50;
    numConditions = 5;
    
    sizeTag = '';
    if ui_targetSize_int == 2
        sizeTag = '_lg';
    end

    inFilePath  = fullfile(baseFilePath, 'post_step3', ui_group_str, ui_algo_str);
    outFilePath = fullfile(baseFilePath, 'post_step4', ui_group_str, ui_algo_str);
    if ~exist(outFilePath, 'dir')
        mkdir(outFilePath);
    end

    for iSubject = 1:length(subject_list)
        ui_subjectID_int = subject_list(iSubject);
        subjStr = num2str(ui_subjectID_int);
        dataTitle  = sprintf('data_%s_%s%s_%s', subjStr, ui_condition_str, sizeTag, ui_algo_str);
        inMatFile  = fullfile(inFilePath, [dataTitle, '.mat']);
        outMatFile = fullfile(outFilePath, sprintf('data_%s_%s%s_%s.mat', subjStr, ui_condition_str, sizeTag, ui_algo_str));

        if ~isfile(inMatFile)
            logFcn(sprintf('WARNING: File not found for %s. Skipping participant...', dataTitle));
            continue;
        end

        logFcn(sprintf('Analyzing Participant %s with Algorithm %s...', subjStr, ui_algo_str));
        loadedData = load(inMatFile);

        if isfield(loadedData, 'bySample_eyeTrialData')
            eyeTrialSrc = loadedData.bySample_eyeTrialData;
        elseif isfield(loadedData, 'eyeTrialData')
            eyeTrialSrc = loadedData.eyeTrialData;
        else
            logFcn(sprintf('ERROR: No valid eye trial field in %s', inMatFile));
            continue;
        end

        predefinedData = struct();
        predefinedData.TrialLevel = struct();
        predefinedData.ConditionLevel = struct();
        predefinedData.trialBlockedEvents = cell(1, numTrials);

        predefinedData.TrialLevel.conditionLabel     = zeros(numTrials, 1);
        predefinedData.TrialLevel.pursCountA         = zeros(numTrials, 1);
        predefinedData.TrialLevel.pursDurA           = zeros(numTrials, 1);
        predefinedData.TrialLevel.pursCountB         = zeros(numTrials, 1);
        predefinedData.TrialLevel.pursDurB           = zeros(numTrials, 1);
        predefinedData.TrialLevel.pursCountC         = zeros(numTrials, 1);
        predefinedData.TrialLevel.pursDurC           = zeros(numTrials, 1);
        predefinedData.TrialLevel.fixCountA          = zeros(numTrials, 1);
        predefinedData.TrialLevel.tDwellA            = zeros(numTrials, 1);
        predefinedData.TrialLevel.meanFixDurA        = zeros(numTrials, 1);
        predefinedData.TrialLevel.mdcA               = zeros(numTrials, 1);
        predefinedData.TrialLevel.fixCountB          = zeros(numTrials, 1);
        predefinedData.TrialLevel.tDwellB            = zeros(numTrials, 1);
        predefinedData.TrialLevel.meanFixDurB        = zeros(numTrials, 1);
        predefinedData.TrialLevel.mdcB               = zeros(numTrials, 1);
        predefinedData.TrialLevel.fixCountC          = zeros(numTrials, 1);
        predefinedData.TrialLevel.tDwellC            = zeros(numTrials, 1);
        predefinedData.TrialLevel.meanFixDurC        = zeros(numTrials, 1);
        predefinedData.TrialLevel.mdcC               = zeros(numTrials, 1);
        predefinedData.TrialLevel.norm_tDwellA       = zeros(numTrials, 1);
        predefinedData.TrialLevel.norm_tDwellB       = zeros(numTrials, 1);
        predefinedData.TrialLevel.norm_tDwellC       = zeros(numTrials, 1);
        predefinedData.TrialLevel.roiTotalEngagement = zeros(numTrials, 1);

        %% Trial-Level Analysis
        for i = 1:numTrials
            if i > 1 && i < 11
                predefinedData.TrialLevel.conditionLabel(i) = 1;
            elseif i > 11 && i < 21
                predefinedData.TrialLevel.conditionLabel(i) = 2;
            elseif i > 21 && i < 31
                predefinedData.TrialLevel.conditionLabel(i) = 3;
            elseif i > 31 && i < 41
                predefinedData.TrialLevel.conditionLabel(i) = 4;
            elseif i > 41 && i < 51
                predefinedData.TrialLevel.conditionLabel(i) = 5;
            else
                predefinedData.TrialLevel.conditionLabel(i) = NaN;
            end

            if i > length(eyeTrialSrc) || isempty(eyeTrialSrc{1, i})
                continue;
            end

            trialData = eyeTrialSrc{1, i};
            labelToBlock = trialData(:, 2);
            changeIndices = find(diff(labelToBlock) ~= 0);
            start_indices = [1; changeIndices + 1];
            stop_indices  = [changeIndices; length(labelToBlock)];
            numBlocks     = length(start_indices);
            eventOnset    = zeros(numBlocks, 1);
            eventDuration = zeros(numBlocks, 1);
            eventLabel    = zeros(numBlocks, 1);
            eventMeanX    = zeros(numBlocks, 1);
            eventMeanY    = zeros(numBlocks, 1);

            for iBlock = 1:numBlocks
                s = start_indices(iBlock);
                e = stop_indices(iBlock);
                xVals = trialData(s:e, 3);
                yVals = trialData(s:e, 4);
                eventOnset(iBlock)    = trialData(s, 1);
                eventDuration(iBlock) = (e - s + 1) / EyeParams.samplingFreq;
                eventLabel(iBlock)    = labelToBlock(s);
                eventMeanX(iBlock)    = mean(xVals, 'omitnan');
                eventMeanY(iBlock)    = mean(yVals, 'omitnan');
            end

            tempMatrix = [eventOnset, eventLabel, eventMeanX, eventMeanY, eventDuration];
            tempMatrix = [tempMatrix; NaN(1, 5)];
            predefinedData.trialBlockedEvents{1, i} = tempMatrix;

            event_gazeDistance_A = sqrt(((eventMeanX - EyeParams.targetA_bln.X_cm).^2) + ((eventMeanY - EyeParams.targetA_bln.Y_cm).^2));
            event_gazeDistance_B = sqrt(((eventMeanX - EyeParams.targetB_bln.X_cm).^2) + ((eventMeanY - EyeParams.targetB_bln.Y_cm).^2));
            event_gazeDistance_C = sqrt(((eventMeanX - EyeParams.targetC_bln.X_cm).^2) + ((eventMeanY - EyeParams.targetC_bln.Y_cm).^2));
            totalRadius = (EyeParams.targetRadiusInMm / 10);
            event_ROI_hit_A = (event_gazeDistance_A <= totalRadius);
            event_ROI_hit_B = (event_gazeDistance_B <= totalRadius);
            event_ROI_hit_C = (event_gazeDistance_C <= totalRadius);

            isFix  = (eventLabel == 1);
            isPurs = (eventLabel == 8);

            if any(isFix)
                isFixInA = isFix & event_ROI_hit_A;
                predefinedData.TrialLevel.fixCountA(i)   = sum(isFixInA);
                predefinedData.TrialLevel.tDwellA(i)     = sum(eventDuration(isFixInA));
                predefinedData.TrialLevel.meanFixDurA(i) = mean(eventDuration(isFixInA));
                predefinedData.TrialLevel.mdcA(i)        = ifelse(predefinedData.TrialLevel.fixCountA(i) >= 2, mean(event_gazeDistance_A(isFixInA)) * double(EyeParams.cm2Deg), NaN);

                isFixInB = isFix & event_ROI_hit_B;
                predefinedData.TrialLevel.fixCountB(i)   = sum(isFixInB);
                predefinedData.TrialLevel.tDwellB(i)     = sum(eventDuration(isFixInB));
                predefinedData.TrialLevel.meanFixDurB(i) = mean(eventDuration(isFixInB));
                predefinedData.TrialLevel.mdcB(i)        = ifelse(predefinedData.TrialLevel.fixCountB(i) >= 2, mean(event_gazeDistance_B(isFixInB)) * double(EyeParams.cm2Deg), NaN);

                isFixInC = isFix & event_ROI_hit_C;
                predefinedData.TrialLevel.fixCountC(i)   = sum(isFixInC);
                predefinedData.TrialLevel.tDwellC(i)     = sum(eventDuration(isFixInC));
                predefinedData.TrialLevel.meanFixDurC(i) = mean(eventDuration(isFixInC));
                predefinedData.TrialLevel.mdcC(i)        = ifelse(predefinedData.TrialLevel.fixCountC(i) >= 2, mean(event_gazeDistance_C(isFixInC)) * double(EyeParams.cm2Deg), NaN);

                allDwells   = [predefinedData.TrialLevel.tDwellA(i), predefinedData.TrialLevel.tDwellC(i), predefinedData.TrialLevel.tDwellB(i)];
                totalDwells = sum(allDwells);

                if totalDwells > 0
                    predefinedData.TrialLevel.norm_tDwellA(i) = predefinedData.TrialLevel.tDwellA(i) / totalDwells;
                    predefinedData.TrialLevel.norm_tDwellB(i) = predefinedData.TrialLevel.tDwellB(i) / totalDwells;
                    predefinedData.TrialLevel.norm_tDwellC(i) = predefinedData.TrialLevel.tDwellC(i) / totalDwells;
                else
                    predefinedData.TrialLevel.norm_tDwellA(i) = 0; predefinedData.TrialLevel.norm_tDwellB(i) = 0; predefinedData.TrialLevel.norm_tDwellC(i) = 0;
                end
            else
                predefinedData.TrialLevel.fixCountA(i)   = NaN; predefinedData.TrialLevel.tDwellA(i)   = NaN; predefinedData.TrialLevel.meanFixDurA(i) = NaN; predefinedData.TrialLevel.mdcA(i) = NaN;
                predefinedData.TrialLevel.fixCountB(i)   = NaN; predefinedData.TrialLevel.tDwellB(i)   = NaN; predefinedData.TrialLevel.meanFixDurB(i) = NaN; predefinedData.TrialLevel.mdcB(i) = NaN;
                predefinedData.TrialLevel.fixCountC(i)   = NaN; predefinedData.TrialLevel.tDwellC(i)   = NaN; predefinedData.TrialLevel.meanFixDurC(i) = NaN; predefinedData.TrialLevel.mdcC(i) = NaN;
                predefinedData.TrialLevel.norm_tDwellA(i) = NaN; predefinedData.TrialLevel.norm_tDwellB(i) = NaN; predefinedData.TrialLevel.norm_tDwellC(i) = NaN;
                totalDwells = NaN;
            end

            if any(isPurs)
                isPursInA = isPurs & event_ROI_hit_A;
                predefinedData.TrialLevel.pursCountA(i) = sum(isPursInA); predefinedData.TrialLevel.pursDurA(i)   = sum(eventDuration(isPursInA));
                isPursInB = isPurs & event_ROI_hit_B;
                predefinedData.TrialLevel.pursCountB(i) = sum(isPursInB); predefinedData.TrialLevel.pursDurB(i)   = sum(eventDuration(isPursInB));
                isPursInC = isPurs & event_ROI_hit_C;
                predefinedData.TrialLevel.pursCountC(i) = sum(isPursInC); predefinedData.TrialLevel.pursDurC(i)   = sum(eventDuration(isPursInC));
                predefinedData.TrialLevel.roiTotalEngagement(i) = sum(totalDwells) + predefinedData.TrialLevel.pursDurA(i) + predefinedData.TrialLevel.pursDurC(i) + predefinedData.TrialLevel.pursDurB(i);
            else
                predefinedData.TrialLevel.pursCountA(i) = NaN; predefinedData.TrialLevel.pursDurA(i) = NaN;
                predefinedData.TrialLevel.pursCountB(i) = NaN; predefinedData.TrialLevel.pursDurB(i) = NaN;
                predefinedData.TrialLevel.pursCountC(i) = NaN; predefinedData.TrialLevel.pursDurC(i) = NaN;
                predefinedData.TrialLevel.roiTotalEngagement(i) = sum(totalDwells);
            end
        end

        % Plotting Trial Dwell
        if showTrialFigs == 1
            if embedInGUI
                ax = guiAxes.axTrial;
                cla(ax);
            else
                figT = figure('Name', sprintf('Dwell Time per Trial: Participant %s', subjStr));
                ax = gca;
            end
            
            x = 1:numTrials;
            hold(ax, 'on');
            scatter(ax, x, predefinedData.TrialLevel.tDwellA, 'filled', 'o', 'MarkerFaceColor', 'r');
            scatter(ax, x, predefinedData.TrialLevel.tDwellB, 'filled', 'o', 'MarkerFaceColor', 'g');
            scatter(ax, x, predefinedData.TrialLevel.tDwellC, 'filled', 'o', 'MarkerFaceColor', 'b');
            xline(ax, [11 21 31 41]);
            hold(ax, 'off');
            title(ax, sprintf('Dwell Time per ROI (Participant %s)', subjStr));
            xlabel(ax, 'Trial'); ylabel(ax, 'Time (s)');
            legend(ax, {'Left', 'Right', 'Center'});
        end

        %% Condition-Level Analysis
        condRanges = {[2, 10], [12, 20], [22, 30], [32, 40], [42, 50]};
        for c = 1:numConditions
            condName = sprintf('c%d', c);
            rangeIdx = condRanges{c}(1):condRanges{c}(2);
            validTrialsInCond = predefinedData.trialBlockedEvents(rangeIdx);
            validTrialsInCond = validTrialsInCond(~cellfun(@isempty, validTrialsInCond));

            if isempty(validTrialsInCond)
                continue;
            end

            condData = vertcat(validTrialsInCond{:});
            predefinedData.ConditionLevel.(condName).eventMatrix = condData;

            eventLabel    = condData(:, 2);
            eventMeanX    = condData(:, 3);
            eventMeanY    = condData(:, 4);
            eventDuration = condData(:, 5);

            event_gazeDistance_A = sqrt(((eventMeanX - EyeParams.targetA_bln.X_cm).^2) + ((eventMeanY - EyeParams.targetA_bln.Y_cm).^2));
            event_gazeDistance_B = sqrt(((eventMeanX - EyeParams.targetB_bln.X_cm).^2) + ((eventMeanY - EyeParams.targetB_bln.Y_cm).^2));
            event_gazeDistance_C = sqrt(((eventMeanX - EyeParams.targetC_bln.X_cm).^2) + ((eventMeanY - EyeParams.targetC_bln.Y_cm).^2));
            totalRadius     = (EyeParams.targetRadiusInMm / 10);
            event_ROI_hit_A = (event_gazeDistance_A <= totalRadius);
            event_ROI_hit_B = (event_gazeDistance_B <= totalRadius);
            event_ROI_hit_C = (event_gazeDistance_C <= totalRadius);

            isFix  = (eventLabel == 1);
            isPurs = (eventLabel == 8);

            if any(isFix)
                isFixInA = isFix & event_ROI_hit_A;
                predefinedData.ConditionLevel.(condName).fixCountA   = sum(isFixInA);
                predefinedData.ConditionLevel.(condName).tDwellA     = sum(eventDuration(isFixInA));
                predefinedData.ConditionLevel.(condName).meanFixDurA = mean(eventDuration(isFixInA));
                predefinedData.ConditionLevel.(condName).mdcA        = mean(event_gazeDistance_A(isFixInA)) * double(EyeParams.cm2Deg);

                isFixInB = isFix & event_ROI_hit_B;
                predefinedData.ConditionLevel.(condName).fixCountB   = sum(isFixInB);
                predefinedData.ConditionLevel.(condName).tDwellB     = sum(eventDuration(isFixInB));
                predefinedData.ConditionLevel.(condName).meanFixDurB = mean(eventDuration(isFixInB));
                predefinedData.ConditionLevel.(condName).mdcB        = mean(event_gazeDistance_B(isFixInB)) * double(EyeParams.cm2Deg);

                isFixInC = isFix & event_ROI_hit_C;
                predefinedData.ConditionLevel.(condName).fixCountC   = sum(isFixInC);
                predefinedData.ConditionLevel.(condName).tDwellC     = sum(eventDuration(isFixInC));
                predefinedData.ConditionLevel.(condName).meanFixDurC = mean(eventDuration(isFixInC));
                predefinedData.ConditionLevel.(condName).mdcC        = mean(event_gazeDistance_C(isFixInC)) * double(EyeParams.cm2Deg);
            end

            allDwells   = [predefinedData.ConditionLevel.(condName).tDwellA, predefinedData.ConditionLevel.(condName).tDwellC, predefinedData.ConditionLevel.(condName).tDwellB];
            totalDwells = sum(allDwells);

            if any(isPurs)
                isPursInA = isPurs & event_ROI_hit_A;
                predefinedData.ConditionLevel.(condName).pursCountA = sum(isPursInA); predefinedData.ConditionLevel.(condName).pursDurA = sum(eventDuration(isPursInA));
                isPursInB = isPurs & event_ROI_hit_B;
                predefinedData.ConditionLevel.(condName).pursCountB = sum(isPursInB); predefinedData.ConditionLevel.(condName).pursDurB = sum(eventDuration(isPursInB));
                isPursInC = isPurs & event_ROI_hit_C;
                predefinedData.ConditionLevel.(condName).pursCountC = sum(isPursInC); predefinedData.ConditionLevel.(condName).pursDurC = sum(eventDuration(isPursInC));
                predefinedData.ConditionLevel.(condName).roiTotalEngagement = totalDwells + predefinedData.ConditionLevel.(condName).pursDurA + predefinedData.ConditionLevel.(condName).pursDurC + predefinedData.ConditionLevel.(condName).pursDurB;
            else
                predefinedData.ConditionLevel.(condName).pursCountA = NaN; predefinedData.ConditionLevel.(condName).pursDurA = NaN;
                predefinedData.ConditionLevel.(condName).pursCountB = NaN; predefinedData.ConditionLevel.(condName).pursDurB = NaN;
                predefinedData.ConditionLevel.(condName).pursCountC = NaN; predefinedData.ConditionLevel.(condName).pursDurC = NaN;
                predefinedData.ConditionLevel.(condName).roiTotalEngagement = totalDwells;
            end

            % Transition Entropy Logic
            roiSequence = zeros(sum(isFix), 1);
            fixROI_A    = event_ROI_hit_A(isFix);
            fixROI_B    = event_ROI_hit_B(isFix);
            fixROI_C    = event_ROI_hit_C(isFix);
            roiSequence(fixROI_A) = 1;
            roiSequence(fixROI_C) = 2;
            roiSequence(fixROI_B) = 3;
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

                predefinedData.ConditionLevel.(condName).sparseSafetyCheck = 0;
                matrixSum = sum(transitionMatrix(:));
                predefinedData.ConditionLevel.(condName).matrixSum = matrixSum;
                if matrixSum < (numROIs * 2) % check for sparse matrix!!
                    predefinedData.ConditionLevel.(condName).sparseSafetyCheck = 1; % check for sparse matrix!!
                    %fprintf('Check data: sparse transition matrix for condition %d\n', c);
                    logFcn(sprintf('Check data: sparse transition matrix for condition %d', c));
                    logFcn(sprintf('Matrix Sum: %d', matrixSum));
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

                predefinedData.ConditionLevel.(condName).roiSeqLength = length(roiSequence);
                predefinedData.ConditionLevel.(condName).p_ij         = p_ij;
                predefinedData.ConditionLevel.(condName).p_i          = p_i;
                predefinedData.ConditionLevel.(condName).Hs           = Hs;
                predefinedData.ConditionLevel.(condName).Hs_rel       = Hs_rel;
                predefinedData.ConditionLevel.(condName).Ht           = Ht;
                predefinedData.ConditionLevel.(condName).Ht_rel       = Ht_rel;

                if showFigs == 1
                    labels = {'Left ROI', 'Cent. ROI', 'Right ROI'};
                    
                    if embedInGUI
                        % Route plot output to Condition c's tab axes
                        ax1 = guiAxes.cond(c).axScanpath;   cla(ax1);
                        ax2 = guiAxes.cond(c).axHeatmap;    cla(ax2);
                        ax3 = guiAxes.cond(c).axBar;        cla(ax3);
                        ax4 = guiAxes.cond(c).axTransition; cla(ax4);
                    else
                        figure('Color', 'w', 'Name', sprintf('Cond %d: Participant %s', c, subjStr));
                        sgtitle([ui_algo_str ' ' subjStr ' Condition ' num2str(c)]);
                        ax1 = subplot(2, 2, 1);
                        ax2 = subplot(2, 2, 2);
                        ax3 = subplot(2, 2, 3);
                        ax4 = subplot(2, 2, 4);
                    end

                    fixIdx = find(isFix);
                    x      = eventMeanX(fixIdx);
                    y      = eventMeanY(fixIdx);
                    dur    = eventDuration(fixIdx);

                    % 1. Scanpath
                    hold(ax1, 'on');
                    plot(ax1, x, y, '-', 'Color', [0.5 0.5 0.5 0.6], 'LineWidth', 1.5);
                    scatter(ax1, x, y, 20 + (dur / max(dur)) * 200, 1:length(x), 'filled', 'MarkerEdgeColor', 'k');
                    viscircles(ax1, [EyeParams.targetA_bln.X_cm, EyeParams.targetA_bln.Y_cm], totalRadius, 'Color', 'r', 'LineStyle', '--');
                    viscircles(ax1, [EyeParams.targetC_bln.X_cm, EyeParams.targetC_bln.Y_cm], totalRadius, 'Color', 'b', 'LineStyle', '--');
                    viscircles(ax1, [EyeParams.targetB_bln.X_cm, EyeParams.targetB_bln.Y_cm], totalRadius, 'Color', 'g', 'LineStyle', '--');
                    axis(ax1, 'equal'); xlim(ax1, [-20 20]); ylim(ax1, [-5 15]);
                    xlabel(ax1, 'X (cm)'); ylabel(ax1, 'Y (cm)'); title(ax1, ['Scanpath: Condition ' num2str(c)]);
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
                    G = digraph(transitionMatrix, {'Left', 'Center', 'Right'});
                    LWidths = 5 * G.Edges.Weight / max(1, max(G.Edges.Weight));
                    plot(ax4, G, 'XData', [EyeParams.targetA_bln.X_cm, EyeParams.targetC_bln.X_cm, EyeParams.targetB_bln.X_cm], ...
                         'YData', [EyeParams.targetA_bln.Y_cm, EyeParams.targetC_bln.Y_cm, EyeParams.targetB_bln.Y_cm], ...
                         'LineWidth', LWidths);
                    axis(ax4, 'equal'); title(ax4, 'Gaze Transition Map');
                end
            else
                logFcn(sprintf('Not enough fixations in condition %d to compute GTE reliably.', c));
                predefinedData.ConditionLevel.(condName).sparseSafetyCheck = NaN;
                predefinedData.ConditionLevel.(condName).matrixSum         = NaN; 
                predefinedData.ConditionLevel.(condName).p_ij              = [];
                predefinedData.ConditionLevel.(condName).p_i               = [];
                predefinedData.ConditionLevel.(condName).Hs                = NaN;
                predefinedData.ConditionLevel.(condName).Hs_rel            = NaN;
                predefinedData.ConditionLevel.(condName).Ht                = NaN;
                predefinedData.ConditionLevel.(condName).Ht_rel            = NaN;
            end
        end

        save(outMatFile, 'predefinedData');
        logFcn(sprintf('Successfully saved: %s', outMatFile));
    end
end

function val = ifelse(cond, trueVal, falseVal)
% Returns trueVal if condition is true, otherwise returns falseVal.
%
% Args:
%     cond (logical): Conditional evaluation statement.
%     trueVal (any): Value returned when cond evaluates to true.
%     falseVal (any): Value returned when cond evaluates to false.
%
% Returns:
%     val (any): Result corresponding to condition evaluation.

    if cond
        val = trueVal;
    else
        val = falseVal;
    end
end