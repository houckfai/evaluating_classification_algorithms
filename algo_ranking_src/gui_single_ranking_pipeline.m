function gui_single_ranking_pipeline()
% Launches the GUI wrapper for single-participant algorithm evaluation and ranking.
% 
% Initializes an interactive MATLAB uifigure containing execution controls, file 
% selection widgets for fixation classification algorithms (I2MC, MNH, REMoDNaV), 
% and an embedded output panel. Manages interactive parameter setup, triggers 
% the evaluation pipeline, streams status logs, and renders visual dashboard 
% summaries upon execution.
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

    % Expanded figure size (1280 x 680)
    fig = uifigure('Name', 'Fixation Classification Algorithm Evaluator', 'Position', [100 100 1280 680]);
    
    % Main 2-Column Grid: Left Column = Controls, Right Column = Dashboard
    mainGrid = uigridlayout(fig, [1, 2]);
    mainGrid.ColumnWidth = {420, '1x'};
    mainGrid.RowHeight = {'1x'};
    
    % --- Left Panel: Controls & Options ---
    leftPanel = uipanel(mainGrid, 'Title', 'Execution Controls');
    grid = uigridlayout(leftPanel, [9, 3]);
    grid.RowHeight = {55, 32, 32, 32, 32, 32, 32, 42, '1x'};
    grid.ColumnWidth = {130, '1x', 110};
    
    % --- Right Panel: Dashboard Container ---
    rightPanel = uipanel(mainGrid, 'Title', 'Participant Ranking Results Dashboard');
    
    selectedFiles = struct();
    
    % Instructions
    txtIntroLog = uitextarea(grid, 'Value', ...
        {'Select participant file for each algorithm and click Run. Each file should have a variable named "EyeData" which is a Nx4 matrix with [time, event label, x coordinates, y coordinates].'}, ...
        'Editable', 'off', ...
        'WordWrap', 'on');
    txtIntroLog.Layout.Column = [1 3];
    
    % Subject ID Input
    uilabel(grid, 'Text', 'Participant ID:', 'FontWeight', 'bold');
    efSubjID = uieditfield(grid, 'numeric', 'Value', 101);
    uilabel(grid, 'Text', '');
    
    uilabel(grid, 'Text', 'Min Fixation Dur (s):');
    efMinFixDur = uieditfield(grid, 'numeric', 'Value', 0.04);
    uilabel(grid, 'Text', '');
    
    % Algorithm File Selectors
    uilabel(grid, 'Text', 'I2MC File (.mat):');
    lblI2MC = uilabel(grid, 'Text', 'No file selected', 'FontAngle', 'italic');
    uibutton(grid, 'Text', 'Select File...', 'ButtonPushedFcn', @(~,~) pickFile('i2mc', lblI2MC, '*.mat'));
    
    uilabel(grid, 'Text', 'MNH File (.mat):');
    lblMNH = uilabel(grid, 'Text', 'No file selected', 'FontAngle', 'italic');
    uibutton(grid, 'Text', 'Select File...', 'ButtonPushedFcn', @(~,~) pickFile('mnh', lblMNH, '*.mat'));
    
    uilabel(grid, 'Text', 'REMoDNaV File (.mat):');
    lblREMO = uilabel(grid, 'Text', 'No file selected', 'FontAngle', 'italic');
    uibutton(grid, 'Text', 'Select File...', 'ButtonPushedFcn', @(~,~) pickFile('remo', lblREMO, '*.mat'));
    
    % Output Folder
    uilabel(grid, 'Text', 'Output Folder:', 'FontWeight', 'bold');
    efOutDir = uieditfield(grid, 'text', 'Value', fullfile(pwd, 'output'));
    uibutton(grid, 'Text', 'Browse...', 'ButtonPushedFcn', @(~,~) browseDir(efOutDir));
    
    % Run Execution Button
    btnRun = uibutton(grid, 'Text', 'RUN', 'FontWeight', 'bold', 'FontSize', 13, ...
        'BackgroundColor', [0.098 0.271 0.23], 'FontColor', 'w', ...
        'ButtonPushedFcn', @(~,~) executeSubjectPipeline());
    btnRun.Layout.Column = [1 3];
    
    % Log Console
    txtLog = uitextarea(grid, 'Value', {''}, ...
        'Editable', 'off', ...
        'WordWrap', 'on');
    txtLog.Layout.Column = [1 3];
    
    % --- Internal GUI Callbacks ---
    function browseDir(targetEditField)
        folder = uigetdir(targetEditField.Value, 'Select Folder');
        if ischar(folder), targetEditField.Value = folder; end
    end

    function pickFile(algoKey, labelObj, fileExt)
        [file, path] = uigetfile(fileExt, sprintf('Select %s file', algoKey), 'MultiSelect', 'off');
        if isequal(file, 0), return; end
        
        fullPath = fullfile(path, file);
        selectedFiles.(algoKey) = fullPath;
        labelObj.Text = file;
        labelObj.FontAngle = 'normal';
    end

    function executeSubjectPipeline()
        activeAlgos = {};
        fields = {'i2mc', 'mnh', 'remo'};
        
        for i = 1:length(fields)
            f = fields{i};
            if isfield(selectedFiles, f) && ~isempty(selectedFiles.(f))
                activeAlgos{end+1} = f; 
            end
        end
        if isempty(activeAlgos)
            uialert(fig, 'Please select a file for at least one algorithm.', 'Selection Error');
            return;
        end
        
        % Build Single-Subject Configuration
        cfg = struct();
        cfg.subjectID    = efSubjID.Value;
        cfg.outputDir    = efOutDir.Value;
        cfg.algos        = activeAlgos;
        cfg.files        = selectedFiles;
        cfg.samplingFreq = 120;
        cfg.B_per_worker = 25;
        cfg.minFixDur    = efMinFixDur.Value;
        
        btnRun.Enable = 'off';
        txtLog.Value = [txtLog.Value; {sprintf('Processing Participant %d...', cfg.subjectID)}];
        drawnow;
        
        try
            res = run_single_ranking_pipeline(cfg);
            
            % Log formatted text summary into GUI text area
            summaryLog = {
                sprintf('SUCCESS: Participant %d complete.', res.subjectID);
                sprintf('  Rank Winner: %s', upper(res.borda_winner));
                sprintf('  Majority Winner: %s (%d/4 metrics)', upper(res.majority_winner), res.max_wins);
            };
            for a = 1:length(res.algos)
                summaryLog{end+1} = sprintf('  • %s Mean Rank: %.2f', ...
                    upper(res.algos{a}), res.mean_ranks(a));
            end
            
            txtLog.Value = [txtLog.Value; summaryLog];
            
            % Render visual figures directly in the right panel
            display_participant_ranking_results(res, rightPanel);
            
        catch ME
            txtLog.Value = [txtLog.Value; {['Error: ' ME.message]}];
            uialert(fig, ME.message, 'Execution Error', 'Icon', 'error');
        end
        btnRun.Enable = 'on';
    end
end

function display_participant_ranking_results(results, parentContainer)
% Clears existing child graphics from the target container and builds a 2x2 tiled layout 
% visualizing participant evaluation outputs across algorithms. Plots a textual winner summary, 
% a mean metric rank bar chart, a grouped ordinal rank chart per metric, and a dual-axis chart 
% comparing total fixation counts with mean fixation durations.
% 
% Args:
%   results (struct or dict): Structure containing pipeline evaluation outputs:
%     subjectID (int): Participant identifier.
%     algos (list of str): Algorithm names evaluated for the participant.
%     borda_winner (str): Algorithm name winning the overall Borda rank count.
%     majority_winner (str): Algorithm name winning the majority vote.
%     max_wins (int): Number of first-place wins for the majority winner.
%     mean_ranks (numpy.ndarray or list): Array of average rank scores per algorithm.
%     ranks (numpy.ndarray): Matrix containing individual metric ordinal ranks.
%     metrics (struct): Structure containing `numFixations` and `meanFixDur`.
%   parentContainer (matlab.ui.container.Panel or matlab.ui.Figure): Graphics handle for 
%     the parent GUI container (e.g., `uipanel`, `uitab`, or `uifigure`).
% 
% Returns:
%     None
% 
% Raises:
%     MException: Propagates graphics generation exceptions if `parentContainer` is invalid.
%

    % Clear previous graphics in container
    delete(parentContainer.Children);
    
    % Create Tiled Layout inside parent UI panel
    t = tiledlayout(parentContainer, 2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
    
    algoNames = upper(results.algos);
    numAlgos  = length(algoNames);
    
    % Color mapping
    colorMap = containers.Map(...
        {'i2mc', 'mnh', 'remo'}, ...
        {'#009E73', '#E69F00', '#0072B2'});
    
    colors = zeros(numAlgos, 3);
    for k = 1:numAlgos
        algoKey = lower(results.algos{k});
        if colorMap.isKey(algoKey)
            colors(k, :) = validatecolor(colorMap(algoKey));
        else
            colors(k, :) = [0.5 0.5 0.5];
        end
    end
    
    % ================== Panel 1: Text Summary ============================
    ax1 = nexttile(t, 1);
    %axis(ax1, 'off');
    box(ax1, 'on');
    set(ax1, 'XTick', [], 'YTick', [], 'Color', 'w');

    summaryStr = {
        sprintf('\\bf Participant %d Summary Results', results.subjectID), ...
        ' --------------------------------------------------', ...
        sprintf('Rank Count Winner:  %s', upper(results.borda_winner)), ...
        sprintf('Majority Vote Winner: %s (%d/4 metrics)', upper(results.majority_winner), results.max_wins), ...
        '', ...
        'Mean Rank Scores (1 = Best):'
    };
    for a = 1:numAlgos
        summaryStr{end+1} = sprintf('%s: %.2f', algoNames{a}, results.mean_ranks(a));
    end
    % changed position coordinates from 0.05, 0.85 to 0.02, 0.98??
    text(ax1, 0.05, 0.92, summaryStr, 'Units', 'normalized', 'FontUnits', 'normalized', ...
        'VerticalAlignment', 'top', 'FontSize', 0.05, ... %FontSize is % of tile height so scales if user maximizes GUI
        'Interpreter', 'tex');
    % removed: 'EdgeColor', [0.098 0.271 0.23], ...
       % 'LineWidth', 1.5, 'BackgroundColor', [1 1 1], 'Margin', 8
        
    % =================== Panel 2: Mean Ranks Comparison ==================
    ax2 = nexttile(t, 2);
    b = bar(ax2, results.mean_ranks, 'FaceColor', 'flat');
    b.CData = colors(1:numAlgos, :);
    yline(ax2, 1, '--', 'Best');
    set(ax2, 'XTickLabel', algoNames);
    title(ax2, 'Mean Metric Rank (Lower = Better)', 'FontSize', 10, 'FontWeight', 'bold');
    ylabel(ax2, 'Mean Rank (1 = Best)');
    grid(ax2, 'off');
    
    % ============= Panel 3: Individual Metric Ranks Grouped Bar ==========
    ax3 = nexttile(t, 3);
    bMetrics = bar(ax3, results.ranks', 'grouped');
    for k = 1:numAlgos, bMetrics(k).FaceColor = colors(k, :); end
    set(ax3, 'XTickLabel', {'Sil.', 'C-H', 'D-B', 'Gap'});
    title(ax3, 'Metric-by-Metric Ordinal Ranks', 'FontSize', 10, 'FontWeight', 'bold');
    ylabel(ax3, 'Rank (1 = Best)');
    yline(ax3, 1, '--', 'Best');
    ylim(ax3, [0 3.5]);
    legend(ax3, algoNames, 'Location', 'southoutside', 'NumColumns', 3);
    grid(ax3, 'off');
    
    % ================= Panel 4: Fixation Count & duration ================
    ax4 = nexttile(t, 4);
    yyaxis(ax4, 'left');
    b = bar(ax4, 1:numAlgos, results.metrics.numFixations, 0.4, 'FaceColor', 'flat');
    b.CData = colors(1:numAlgos, :);
    ylabel(ax4, 'Total Fixations Identified');
    
    yyaxis(ax4, 'right');
    plot(ax4, 1:numAlgos, results.metrics.meanFixDur .* 1000, '-o', 'LineWidth', 2, 'MarkerSize', 8, 'Color', [0.8 0.2 0.2]);
    ylabel(ax4, 'Mean Duration (ms)');
    
    set(ax4, 'XTick', 1:numAlgos, 'XTickLabel', algoNames);
    title(ax4, 'Fixation Count & Duration', 'FontSize', 10, 'FontWeight', 'bold');
    grid(ax4, 'off');
end