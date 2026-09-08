function results = run_single_ranking_pipeline(cfg)
% Evaluates clustering quality metrics and ranks eye-tracking algorithms for a single subject.
% 
% Processes gaze fixation data across multiple event-detection algorithms to compute 
% clustering metrics (Silhouette, Davies-Bouldin, Calinski-Harabasz, and parallel 
% Gap Statistic). Ranks candidate algorithms using Borda count and majority voting with 
% hierarchical tie-breaking before saving output metrics to .mat file.
% 
% Args:
%   cfg (struct or dict): Configuration structure containing pipeline parameters:
%       subjectID (int): Participant identifier.
%       outputDir (str): Directory path where the output results file will be saved.
%       samplingFreq (float): Eye-tracker sampling frequency in Hz.
%       minFixDur (float): Minimum duration threshold for valid fixations in seconds.
%       B_per_worker (int): Number of reference distribution samples per parallel worker for Gap Statistic calculation.
%       algos (list of str): List or cell array of active algorithm names (e.g., ['i2mc', 'mnh', 'remo']).
%       files (struct or dict): Structure mapping algorithm names to their respective MAT file paths.
% 
% Returns:
%   struct or dict: Summary structure containing raw clustering metrics (`s`, `db`, `ch`, `gap`), full rank matrix, mean ranks, Borda count winner, majority vote winner, and total win counts.
% 
% Raises:
%   MException / FileNotFoundError: If an input data file specified in `cfg.files` does not exist on disk.
%

    % turn off pdist2 single-conversion warning
    % 1. Turn off pdist2 single-conversion warning
    warning('off', 'stats:pdist2:DataConversion');
    % 2. Automatically restore warning settings when function exits or fails
    restoreWarn = onCleanup(@() warning('on', 'stats:pdist2:DataConversion'));

    % ================== Environment & Parallel Pool Setup ================
    pool = gcp('nocreate');
    if isempty(pool), pool = parpool(); end
    numWorkers = pool.NumWorkers;
    
    numAlgos = length(cfg.algos);
    
    % pre-allocate storage for this participant's metrics across algorithms
    metrics = struct();
    metrics.s              = zeros(1, numAlgos);
    metrics.db             = zeros(1, numAlgos);
    metrics.ch             = zeros(1, numAlgos);
    metrics.gap            = zeros(1, numAlgos);
    metrics.numFixations   = zeros(1, numAlgos);
    metrics.meanFixDur     = zeros(1, numAlgos);

    % ================== STEP 1: Process Each Algorithm ===================
    for a = 1:numAlgos
        algo = cfg.algos{a};
        matPath = cfg.files.(algo);
        fprintf('Processing Participant %d | Algorithm: %s\n', cfg.subjectID, algo);

        if ~exist(matPath, 'file')
            error('Missing file for algorithm %s: %s', algo, matPath);
        end
        tmp_data = load(matPath);

        % Extract fixation data via helper
        [n, ids, meanDur] = process_algo_data(tmp_data.eyeData(:,1), ...
            tmp_data.eyeData(:,3:4), tmp_data.eyeData(:,2), cfg.samplingFreq, cfg.minFixDur);

        metrics.meanFixDur(a)   = meanDur;
        metrics.numFixations(a) = max(ids);

        n = single(n); ids = single(ids);

        % Compute Clustering Metrics
        e = evalclusters(n, ids, 'silhouette');       metrics.s(a)  = e.CriterionValues;
        e = evalclusters(n, ids, 'DaviesBouldin');    metrics.db(a) = e.CriterionValues;
        e = evalclusters(n, ids, 'CalinskiHarabasz');   metrics.ch(a) = e.CriterionValues;

        % Compute Parallel Gap Statistic
        f(1:numWorkers) = parallel.FevalFuture;
        for w = 1:numWorkers
            f(w) = parfeval(@evalclusters, 1, n, @(X,K) ids, 'gap', 'KList', max(ids), 'B', cfg.B_per_worker);
        end 
        
        ref_logW = [];
        for w = 1:numWorkers
            res = fetchOutputs(f(w));
            if w == 1, base_logW = res.LogW; end
            ref_logW = [ref_logW; res.ExpectedLogW]; %#ok<AGROW>
        end
        metrics.gap(a) = mean(ref_logW) - base_logW;
    end

    % ================== STEP 2: Rank Algorithms ==========================
    ranks = zeros(numAlgos, 4);
    [~, idx] = sort(metrics.s, 'descend');   ranks(idx, 1) = 1:numAlgos; % Silhouette (Max)
    [~, idx] = sort(metrics.ch, 'descend');  ranks(idx, 2) = 1:numAlgos; % Calinski-Harabasz (Max)
    [~, idx] = sort(metrics.db, 'ascend');   ranks(idx, 3) = 1:numAlgos; % Davies-Bouldin (Min)
    [~, idx] = sort(metrics.gap, 'descend'); ranks(idx, 4) = 1:numAlgos; % Gap Stat (Max)

    % Count Winner
    mean_ranks = mean(ranks, 2);
    first_place_wins = sum(ranks == 1, 2);
    tied_borda = find(mean_ranks == min(mean_ranks));

    if numel(tied_borda) == 1 % if ranks are tied...
        borda_winner_idx = tied_borda;
    else
        tied_wins = first_place_wins(tied_borda);
        tied_after_wins = tied_borda(tied_wins == max(tied_wins));
        if numel(tied_after_wins) == 1 % if ranks are still tied...
            borda_winner_idx = tied_after_wins;
        else
            [~, max_gap_rel_idx] = max(metrics.gap(tied_after_wins));
            borda_winner_idx = tied_after_wins(max_gap_rel_idx);
        end
    end

    % Majority Vote Winner
    [max_wins, majority_winner_idx] = max(first_place_wins);

    % store Results
    results = struct();
    results.subjectID       = cfg.subjectID;
    results.algos           = cfg.algos;
    results.metrics         = metrics;
    results.ranks           = ranks;
    results.mean_ranks      = mean_ranks';
    results.borda_winner    = cfg.algos{borda_winner_idx};
    results.majority_winner = cfg.algos{majority_winner_idx};
    results.max_wins        = max_wins;

    % ================== STEP 3: Save Participant .mat File================
    if ~exist(cfg.outputDir, 'dir'), mkdir(cfg.outputDir); end
    outFile = fullfile(cfg.outputDir, sprintf('algoEval_%d_results.mat', cfg.subjectID));
    save(outFile, 'results');
    fprintf('Saved single-subject results to: %s\n', outFile);
end

% ================== helper function ======================================
function [norm_data, clean_ids, meanFixDur] = process_algo_data(time, coors, labels, fs, minFixDur)
% Cleans data (qc check) and normalizes time-series eye-tracking data for a single algorithm.
% 
% Identifies continuous fixation events, filters out fixations shorter than the 
% specified duration threshold, removes rows containing NaN values, re-indexes event IDs, 
% and applies min-max normalization to spatial coordinates and timestamps.
% 
% Args:
%   time (vector): Column vector of timestamps for eye-tracking samples.
%   coors (matrix): Two-column matrix containing X and Y gaze coordinates.
%   labels (vector): Column vector of event labels (1 for fixations, other values for non-fixations).
%   fs (float): Eyetracker sampling frequency in Hz.
%   minFixDur (float): Minimum duration threshold for valid fixations in seconds.
% 
% Returns:
%     tuple: A tuple containing:
%         norm_data (matrix): Min-max normalized matrix of spatial coordinates and timestamps.
%         clean_ids (vector): Categorical group indices corresponding to valid fixation events.
%         meanFixDur (float): Mean duration of valid fixations in seconds, or 0 if no valid fixations exist.
% 
% Raises:
%   None
%
    labels(labels ~= 1) = 2;
    event_ids = bwlabel(labels == 1);
    is_fix = (event_ids > 0);
    
    durs = accumarray(event_ids(is_fix), time(is_fix), [], @(x) max(x)-min(x)) + (1/fs);
    invalid_ids = find(durs < 0.040); % minimum fixation duration
    
    valid_rows = ~ismember(event_ids, invalid_ids) & is_fix;
    valid_durs = durs(durs >= minFixDur); % 40 ms = min fixation duration
    if isempty(valid_durs), meanFixDur = 0; else, meanFixDur = mean(valid_durs); end
    
    combined = [coors(valid_rows, :), time(valid_rows)];
    clean_mask = ~any(isnan(combined), 2);
    clean_data = combined(clean_mask, :);
    
    raw_ids = event_ids(valid_rows);
    clean_ids = grp2idx(raw_ids(clean_mask)); 
    
    range_val = max(clean_data) - min(clean_data);
    range_val(range_val == 0) = 1; 
    norm_data = (clean_data - min(clean_data)) ./ range_val;
end