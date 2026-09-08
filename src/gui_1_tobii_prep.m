function gui_1_tobii_prep()
% Launches the GUI for configuring and preprocessing raw Tobii eye tracking data.
%
% Creates an interactive user interface (uifigure) to collect participant
% parameters, display dimensions, and file directory paths. Constructs a
% configuration structure from user inputs and runs the function
% prepare_tobii_data to process raw LSL XDF and Presentation log files.
% Upon successful completion, this prompts the user to optionally launch
% the classification GUI. 
%
% Args:
%   None
%
% Returns:
%   None
%
% Raises:
%   None

    fig = uifigure('Name', 'Step 1: Setup Raw Tobii Data', 'Position', [150 150 660 600]);
    grid = uigridlayout(fig, [11, 3]);
    grid.RowHeight   = {30, 30, 30, 30, 30, 30, 30, 30, 30, 42, '1x'};
    grid.ColumnWidth = {140, '1x', 110};

    % Participant & Experiment Parameters
    uilabel(grid, 'Text', 'Participant ID:', 'FontWeight', 'bold');
    efSubjID = uieditfield(grid, 'text', 'Value', '101');
    uilabel(grid, 'Text', '');

    uilabel(grid, 'Text', 'Group Folder:');
    efGroup = uieditfield(grid, 'text', 'Value', 'G01');
    uilabel(grid, 'Text', '');

    uilabel(grid, 'Text', 'Condition:');
    efCond = uieditfield(grid, 'text', 'Value', 'bln');
    uilabel(grid, 'Text', '');

    uilabel(grid, 'Text', 'Target Size:');
    ddTargetSize = uidropdown(grid, 'Items', {'Small (1)', 'Large (2)'}, 'ItemsData', [1, 2]);
    uilabel(grid, 'Text', '');

    uilabel(grid, 'Text', 'Log Suffix:');
    efLogSuffix = uieditfield(grid, 'text', 'Value', 'Case 423');
    uilabel(grid, 'Text', '');

    % Display Dimensions
    uilabel(grid, 'Text', 'Screen Width (cm):');
    efWidth = uieditfield(grid, 'numeric', 'Value', 47.7);
    uilabel(grid, 'Text', '');

    uilabel(grid, 'Text', 'Screen Height (cm):');
    efHeight = uieditfield(grid, 'numeric', 'Value', 26.8);
    uilabel(grid, 'Text', '');

    % Path Selection (Raw Input & Processed Output)
    uilabel(grid, 'Text', 'Raw Data Dir:', 'FontWeight', 'bold');
    efRawDir = uieditfield(grid, 'text', 'Value', pwd);
    uibutton(grid, 'Text', 'Browse...', 'ButtonPushedFcn', @(~,~) selectDir(efRawDir, 'Select Raw Data Directory'));

    uilabel(grid, 'Text', 'Output Dir:', 'FontWeight', 'bold');
    efOutDir = uieditfield(grid, 'text', 'Value', fullfile(pwd, 'post_step1'));
    uibutton(grid, 'Text', 'Browse...', 'ButtonPushedFcn', @(~,~) selectDir(efOutDir, 'Select Output Directory'));

    % Action Button (Spartan green color)
    btnRun = uibutton(grid, 'Text', 'PREPROCESS RAW DATA', 'FontWeight', 'bold', 'FontSize', 13, ...
        'BackgroundColor', [0.098 0.271 0.23], 'FontColor', 'w', ...
        'ButtonPushedFcn', @(~,~) processData());
    btnRun.Layout.Column = [1 3];

    % Console Log Panel
    txtLog = uitextarea(grid, 'Value', {'Configure settings and select directories to start.'}, ...
        'Editable', 'off', 'WordWrap', 'on');
    txtLog.Layout.Column = [1 3];

    % Helper Callbacks
    function selectDir(efObj, dialogTitle)
        folder = uigetdir(efObj.Value, dialogTitle);
        if ischar(folder) || isstring(folder)
            efObj.Value = char(folder);
        end
    end

    function processData()
        cfg = struct();
        cfg.subjectID                  = efSubjID.Value;
        cfg.group                      = efGroup.Value;
        cfg.condition                  = efCond.Value;
        cfg.targetSize                 = ddTargetSize.Value;
        cfg.logSuffix                  = efLogSuffix.Value;
        cfg.rawDir                     = efRawDir.Value;
        cfg.outDir                     = efOutDir.Value;
        cfg.eyeParams.screenWidthInCm  = efWidth.Value;
        cfg.eyeParams.screenHeightInCm = efHeight.Value;
        cfg.viewGraphs                 = true;

        btnRun.Enable = 'off';
        txtLog.Value = [txtLog.Value; {sprintf('Preprocessing Participant %s...', cfg.subjectID)}];
        drawnow;

        try
            [~, savedFile] = prepare_tobii_data(cfg);
            msg = sprintf('Preprocessing completed successfully.\nFile saved to:\n%s', savedFile);
            txtLog.Value = [txtLog.Value; {sprintf('SUCCESS: Saved to %s', savedFile)}];
            
            choice = uiconfirm(fig, sprintf('%s\n\nLaunch Classification GUI now?', msg), ...
                'Processing Complete', 'Options', {'Launch Classifier', 'Done'}, 'DefaultOption', 1);
            
            if strcmp(choice, 'Launch Classifier')
                if exist('single_algo_pipeline_gui', 'file') == 2
                    single_algo_pipeline_gui();
                else
                    uialert(fig, 'single_algo_pipeline_gui.m was not found in path.', 'File Missing');
                end
            end
        catch ME
            txtLog.Value = [txtLog.Value; {['ERROR: ' ME.message]}];
            uialert(fig, ME.message, 'Processing Error', 'Icon', 'error');
        end
        btnRun.Enable = 'on';
    end
end