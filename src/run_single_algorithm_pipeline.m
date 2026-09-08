function results = run_single_algorithm_pipeline(cfg)
% Executes eye tracking classification pipelines (I2MC, MNH, REMoDNaV).
%
% Loads preprocessed Tobii gaze data, prepares algorithm-specific input
% formats, runs the classification algorithm, performs quality control by
% enforcing minimum fixation duration constraints, saves output files, and
% displays quick visual diagnostic plots. 
%
% Args:
%   cfg (struct): Configuration parameters containing:
%       inputFile (str): Full path to preprocessed .mat input file containing tobiiData.
%       baseDir (str): Root project folder path.
%       group (str): Participant group folder name (e.g., 'G01').
%       subjectID (str): Unique participant identifier.
%       condition (str): Experimental condition tag (e.g., 'bln').
%       algo (str): Algorithm selector ('i2mc', 'mnh', or 'remo').
%       targetSize (int): Experimental task target size flag (uses '_lg' suffix if equal to 2). If n/a to your data, use 1.
%       savgolSec (float): Savitzky-Golay filter length in seconds (for
%       REMoDNaV input).
%       eyeParams (struct): Hardware settings containing:
%           samplingFreq (float): Eye tracker sampling frequency in Hz.
%           cmToPixel (float): Conversion factor from pixels to degrees.
%           pixelToDegrees (float): Conversion factor from pixels to degrees.
%           minFixDur (float): Minimum fixation duration threshold in seconds.
%
% Returns:
%   results (struct): Classification results containing:
%       sampledData (matrix): sample-by-sample output matrix, where every time step is 1/samplingFreq in duration.
%       labels (vector): Event labels (REMoDNaV only).
%       ET (struct): Event output structure from the MNH algorithm (MNH only).
%       fix (struct): Event output structure from the I2MC algorithm (I2MC only).
%       data (struct): Formatted gaze data input stucture for the I2MC algorithm (I2MC only). 
%       opt (struct): Input parameter structure for the I2MC algorithm (I2MC only). 
%       ndata (struct): Downsampled/filtered data (I2MC only).
%       npar (struct): Processing parameters by the I2MC algorithm (I2MC only).
%       cfg (struct): Copy of input configuration struct.
%
% Raises:
%   MException: If cfg.inputFile does not exist.
%   MException: If loaded file does not contain a 'tobiiData' struct.
%   MException: If REMoDNaV command line execution returns a non-zero exit status.

    % =============== Load Data ===========================================
    if ~isfile(cfg.inputFile)
        error('Input file not found: %s', cfg.inputFile);
    end
    loadedData = load(cfg.inputFile);
    if isfield(loadedData, 'tobiiData')
        tobii = loadedData.tobiiData;
    else
        error('The selected file must contain a "tobiiData" structure.');
    end

    % =============== 2. Setup Cross-Platform Paths =======================
    sizeTag = '';
    if cfg.targetSize == 2, sizeTag = '_lg'; end
    
    postStep1Dir = fullfile(cfg.baseDir, 'post_step1', cfg.group);
    postStep2Dir = fullfile(cfg.baseDir, 'post_step2', cfg.group, sprintf('%s_results', lower(cfg.algo)));
    
    if ~exist(postStep1Dir, 'dir'), mkdir(postStep1Dir); end
    if ~exist(postStep2Dir, 'dir'), mkdir(postStep2Dir); end

    % ===============3. Compute Time Base & Coordinates ===================
    tobii.pupilMean = mean(tobii.time_series([30 31], :), 'omitnan');
    tobii.valid     = mean(tobii.time_series([28 29], :), 'omitnan');
    timeStep        = 1 / cfg.eyeParams.samplingFreq;
    timeStop        = (length(tobii.pupilMean) - 1) * timeStep; 
    tobii.msec      = (0:timeStep:timeStop) * 1000;

    x = tobii.xMean_cm;
    y = tobii.yMean_cm;

    % =============== 4. Algorithm Data Prep & Execution ==================
    switch lower(cfg.algo)
        case 'remo'
            x_px = x * cfg.eyeParams.cmToPixel;
            y_px = y * cfg.eyeParams.cmToPixel;
            
            fileName = sprintf('data_%s_%s%s_remo.txt', cfg.subjectID, cfg.condition, sizeTag);
            step1File = fullfile(postStep1Dir, fileName);
            step2File = fullfile(postStep2Dir, fileName);
            
            writematrix([x_px', y_px'], step1File, 'Delimiter', '\t');
            
            % Cross-platform system call with quoted paths
            remodnav_params = sprintf('%f %f --savgol-length %f --min-fixation-duration %f', ...
                cfg.eyeParams.pixelToDegrees, cfg.eyeParams.samplingFreq, cfg.savgolSec, cfg.eyeParams.minFixDur);
            sysCmd = sprintf('remodnav "%s" "%s" %s', step1File, step2File, remodnav_params);
            
            [status, cmdout] = system(sysCmd);
            if status ~= 0
                error('REMoDNaV execution failed:\n%s', cmdout);
            end
            
            [sampledData, sampledLabels] = convertRemoData(cfg.baseDir, cfg.eyeParams, ...
                cfg.group, str2double(cfg.subjectID), cfg.condition, cfg.targetSize, tobii);
            
            results.sampledData = sampledData;
            results.labels = sampledLabels;

        case 'mnh' 

            x_deg = x * cfg.eyeParams.cmToPixel * cfg.eyeParams.pixelToDegrees;
            y_deg = y * cfg.eyeParams.cmToPixel * cfg.eyeParams.pixelToDegrees;
            
            fileName = sprintf('data_%s_%s%s_mnh.csv', cfg.subjectID, cfg.condition, sizeTag);
            step1File = fullfile(postStep1Dir, fileName);
            
            output_data = [tobii.msec', x_deg', y_deg', tobii.pupilMean', tobii.valid'];
            writematrix(output_data, step1File);
            
            [ET] = mnhBeginEventDetection(cfg.baseDir, cfg.eyeParams, cfg.group, ...
                str2double(cfg.subjectID), cfg.condition, cfg.targetSize, 'mnh');
            
            fileName = sprintf('data_%s_%s%s_mnh.mat', cfg.subjectID, cfg.condition, sizeTag);
            mnhOutputFile = fullfile(postStep2Dir, fileName);
            fprintf('MNH OutputFile: %s\n', mnhOutputFile);
            save(mnhOutputFile, 'ET');

            results.ET = ET;

            % --- CONVERT MNH RESULTS TO CM & STANDARDIZED MATRIX ---
            [sampledData] = convertMNHData(cfg.baseDir, cfg.eyeParams, ...
                cfg.group, cfg.subjectID, cfg.condition, cfg.targetSize, tobii);
            
            results.sampledData = sampledData;

        case 'i2mc'

            i2mc_matrix = [tobii.msec', tobii.time_series(24, :)', tobii.time_series(25, :)', ...
                tobii.time_series(16, :)', tobii.time_series(26, :)', ...
                tobii.time_series(27, :)', tobii.time_series(17, :)'];
            
            opt.xres           = 1920; 
            opt.yres           = 1080; 
            opt.missingx       = -opt.xres; 
            opt.missingy       = -opt.yres; 
            opt.freq           = cfg.eyeParams.samplingFreq;
            opt.scrSz          = [47.7 26.8];
            opt.disttoscreen   = 60; 
            opt.downsampFilter = 0;
            opt.minFixDur      = cfg.eyeParams.minFixDur * 1000; % i2mc has it in ms
            
            [data.time, data.left.X, data.left.Y, data.right.X, data.right.Y] = ...
                importTobiiProFusion(i2mc_matrix, 1, [opt.xres opt.yres], opt.missingx, opt.missingy);
            
            fileName = sprintf('data_%s_%s%s_i2mc.mat', cfg.subjectID, cfg.condition, sizeTag);
            
            [fix, ndata, npar] = I2MCfunc(data, opt);

            % SAVE FIXATION RESULTS BEFORE CONVERSION - next function loads
            % this file
            i2mcOutputFile = fullfile(postStep2Dir, fileName);
            save(i2mcOutputFile, 'fix');
            
            results.fix = fix;
            results.data = data;
            results.opt = opt;
            results.ndata = ndata;
            results.npar = npar;

            [sampledData] = convertI2MCData(cfg.baseDir, cfg.eyeParams, ...
                cfg.group, str2double(cfg.subjectID), cfg.condition, cfg.targetSize, tobii);
            results.sampledData = sampledData;
    end
    
    % call function to check for any fixation events that are <
    % cfg.eyeParams.minFixDur:
    results = qc_min_fixation_duration(results, cfg);

    results.cfg = cfg;
    save(fullfile(postStep2Dir, fileName), 'results');
    display_quick_plots(results);
end

% ============ helper function ============================================
function clean_res = qc_min_fixation_duration(res, cfg)
% Evaluates fixation segments & relabels fixations to noise if fixation is
% shorter than minFixDur threshold.
%
% Args:
%   res (struct): Classification results containing sampledData matrix.
%   cfg (struct): Configuration struct containing eyeParams.minFixDur.
%
% Returns:
%   clean_res (struct): Results struct with fixations shorter than threshold relabeled to 4.
%
% Raises: 
%   warning: if cfg structure does not contain an eyeParams.minFixDur variable.

    clean_res = res;
    
    % Return early if no sampledData exists
    if ~isfield(res, 'sampledData') || isempty(res.sampledData)
        return;
    end

    times = res.sampledData(:,1);
    labels = res.sampledData(:,2);

    % set minDur from cfg
    if isfield(cfg, 'eyeParams') && isfield(cfg.eyeParams, 'minFixDur')
        minDur = cfg.eyeParams.minFixDur;
    else
        warning('minFixDur not specified in cfg. Skipping QC check.');
        return;
    end

    dt   = 1 / cfg.eyeParams.samplingFreq;

    % at 120 Hz, floating point arithmetic may set it as 0.039s, set set a
    % buffer to lower threshold very slightly to preserve these fixations
    bufferSec = dt / 2; 
    effectiveMinDur = minDur - bufferSec;

    % find the contiguous fixation segments (label == 1)
    fix_ids = bwlabel(labels == 1);
    is_fix = (fix_ids > 0);

    if any(is_fix)
        % Calculate duration (in seconds) for each fixation ID
        durs = accumarray(fix_ids(is_fix), times(is_fix), [], @(x) max(x) - min(x)) + dt;
        
        % Find fixation IDs that fall below the minimum threshold
        invalid_ids  = find(durs < effectiveMinDur);
        invalid_rows = ismember(fix_ids, invalid_ids);

        % Calculate count of invalid fixations
        num_invalid = numel(invalid_ids);
        
        % print how many fixs < minDur to command window
        fprintf('[QC] Participant %s: Found %d fixation(s) below threshold (< %.3f s, eff. thresh: %.3f s) - relabeled to 4.\n', ...
            cfg.subjectID, num_invalid, minDur, effectiveMinDur);
        
        % Re-label short fixation samples to 4
        labels(invalid_rows) = 4;
        clean_res.sampledData(:, 2) = labels;
    end
end

function display_quick_plots(res)
% Generates quick diagnostic figure showing gaze coordinates & classified
% event distribution
%
% Args:
%   res (struct): Results struct containng sampledData & cfg parameters.
%
% Returns:
%   None
%
% Raises:
%   None

    fig = figure('Name', sprintf('Results Summary: %s (%s)', res.cfg.subjectID, upper(res.cfg.algo)), ...
        'Position', [150 150 800 450]);
    
    subplot(1, 2, 1);
    plot(res.sampledData(:, 3), res.sampledData(:, 4), 'b');
    title('Gaze Coordinates (cm)'); xlabel('X'); ylabel('Y');
    
    subplot(1, 2, 2);
    histogram(res.sampledData(:, 2));
    title('Event Labels'); xlabel('Event Type'); ylabel('Count'); 
           
end