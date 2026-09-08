function gui_2_single_algo_pipeline()
% Launches the GUI for single-participant eye-tracking event classification.
%
% Creates an interactive user interface (uifigure) to configure participant 
% metadata, minimum fixation thresholds, algorithm selection (I2MC, MNH, or 
% REMoDNaV), and input file paths. Validates input consistency, sets default 
% display and acquisition parameters, and executes run_single_algorithm_pipeline.
%
% Args:
%     None
%
% Returns:
%     None
%
% Raises:
%     None

    fig = uifigure('Name', 'Step 2: Single Participant Classification', 'Position', [150 100 660 600]);
    grid = uigridlayout(fig, [11, 3]);
    grid.RowHeight = {30, 30, 30, 30, 30, 30, 30, 30, 42, '1x'};
    grid.ColumnWidth = {140, '1x', 110};

    % Input Fields
    uilabel(grid, 'Text', 'Participant ID:', 'FontWeight', 'bold');
    efSubjID = uieditfield(grid, 'text', 'Value', '101');
    uilabel(grid, 'Text', '');

    uilabel(grid, 'Text', 'Group Name:');
    efGroup = uieditfield(grid, 'text', 'Value', 'G01');
    uilabel(grid, 'Text', '');

    uilabel(grid, 'Text', 'Condition:');
    efCond = uieditfield(grid, 'text', 'Value', 'bln');
    uilabel(grid, 'Text', '');

    uilabel(grid, 'Text', 'Target Size:');
    ddTargetSize = uidropdown(grid, 'Items', {'Small (1)', 'Large (2)'}, 'ItemsData', [1, 2]);
    uilabel(grid, 'Text', '');

    uilabel(grid, 'Text', 'Min Fixation Dur (s):');
    numMinFixDur = uieditfield(grid, 'numeric', 'Value', 0.04);
    uilabel(grid, 'Text', '');

    uilabel(grid, 'Text', 'Algorithm:', 'FontWeight', 'bold');
    ddAlgo = uidropdown(grid, 'Items', {'I2MC', 'MNH', 'REMoDNaV'}, ...
        'ItemsData', {'i2mc', 'mnh', 'remo'});
    uilabel(grid, 'Text', '');

    % File Selectors
    uilabel(grid, 'Text', 'Input File (.mat):', 'FontWeight', 'bold');
    lblInputFile = uilabel(grid, 'Text', 'No file selected', 'FontAngle', 'italic');
    uibutton(grid, 'Text', 'Browse...', 'ButtonPushedFcn', @(~,~) selectFile(lblInputFile));

    uilabel(grid, 'Text', 'Base Directory:', 'FontWeight', 'bold');
    efBaseDir = uieditfield(grid, 'text', 'Value', pwd);
    uibutton(grid, 'Text', 'Browse...', 'ButtonPushedFcn', @(~,~) selectDir(efBaseDir));

    % run Execution Button (spartan green color go green etc)
    btnRun = uibutton(grid, 'Text', 'RUN PIPELINE', 'FontWeight', 'bold', 'FontSize', 13, ...
        'BackgroundColor', [0.098 0.271 0.23], 'FontColor', 'w', ...
        'ButtonPushedFcn', @(~,~) runPipeline());
    btnRun.Layout.Column = [1 3];

    % console log panel:
    txtLog = uitextarea(grid, 'Value', {'Configure parameters and click "RUN PIPELINE".'}, ...
        'Editable', 'off', 'WordWrap', 'on');
    txtLog.Layout.Column = [1 3];

    % helper Callbacks
    function selectFile(lblObj)
        [file, path] = uigetfile('*.mat', 'Select Participant MAT File');
        if ischar(file)
            lblObj.Text = fullfile(path, file);
            lblObj.FontAngle = 'normal';
        end
    end

    function selectDir(efObj)
        folder = uigetdir(efObj.Value, 'Select Base Output Directory');
        if ischar(folder), efObj.Value = folder; end
    end

    function runPipeline()
        if strcmp(lblInputFile.Text, 'No file selected') || ~isfile(lblInputFile.Text)
            uialert(fig, 'Please select a valid input MATLAB file.', 'File Missing');
            return;
        end

        % safety check - Validate Participant ID matches selected file name
        [~, fileName, fileExt] = fileparts(lblInputFile.Text);
        enteredID = strtrim(efSubjID.Value);
        
        if ~contains(fileName, enteredID)
            warnMsg = sprintf('The input file name ("%s%s") does not contain the entered Participant ID ("%s").\n\nDo you want to proceed anyway?', ...
                fileName, fileExt, enteredID);
            
            selection = uiconfirm(fig, warnMsg, 'ID Mismatch Warning', ...
                'Options', {'Proceed', 'Cancel'}, ...
                'DefaultOption', 2, ...
                'CancelOption', 2, ...
                'Icon', 'warning');
                
            if strcmp(selection, 'Cancel')
                return;
            end
        end

        % Build Configuration Object
        cfg = struct();
        cfg.subjectID  = efSubjID.Value;
        cfg.group      = efGroup.Value;
        cfg.condition  = efCond.Value;
        cfg.targetSize = ddTargetSize.Value;
        cfg.algo       = ddAlgo.Value;
        cfg.inputFile  = lblInputFile.Text;
        cfg.baseDir    = efBaseDir.Value;
        
        % Default Eye Tracking Parameters
        cfg.eyeParams.minFixDur             = numMinFixDur.Value;
        cfg.eyeParams.cmToPixel             = 40;
        cfg.eyeParams.pixelToDegrees        = 0.0226;
        cfg.eyeParams.samplingFreq          = 120;
        cfg.savgolSec                       = 0.042;
        cfg.savgolFl                        = 5;
        cfg.eyeParams.screenResolutionWidth = 1920;
        cfg.eyeParams.screenResolutionHeight = 1080;
        cfg.eyeParams.screenWidthInCm       = 47.7;
        cfg.eyeParams.screenHeightInCm      = 26.8;

        btnRun.Enable = 'off';
        txtLog.Value = [txtLog.Value; {sprintf('Running %s for Participant %s...', upper(cfg.algo), cfg.subjectID)}];
        drawnow;

        try
            results = run_single_algorithm_pipeline(cfg);
            %txtLog.Value = [txtLog.Value; {sprintf('SUCCESS: %s complete.', upper(cfg.algo))}];
            %uialert(fig, 'Pipeline execution completed successfully!', 'Done', 'Icon', 'success');

            msg = sprintf('SUCCESS: %s complete.', upper(cfg.algo));
            txtLog.Value = [txtLog.Value; {msg}];
            % 
            % % ask user if they want to move to next step: split into trials
            % choice = uiconfirm(fig, sprintf('%s\n\nLaunch Split into Trials GUI now?', msg), ...
            %     'Processing Complete', 'Options', {'Launch Next Step', 'Done'}, 'DefaultOption', 1);
            % 
            % if strcmp(choice, 'Launch Next Step')
            %     if exist('data_by_trials_gui', 'file') == 2
            %         data_by_trials_gui();
            %     else
            %         uialert(fig, 'data_by_trials_gui.m was not found in path.', 'File Missing');
            %     end
            % end
        
        catch ME
            txtLog.Value = [txtLog.Value; {['ERROR: ' ME.message]}];
            uialert(fig, ME.message, 'Execution Error', 'Icon', 'error');
        end
        btnRun.Enable = 'on';
    end
end