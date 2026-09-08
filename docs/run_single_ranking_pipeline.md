# `run_single_ranking_pipeline.m` Documentation

## Overview

`run_single_ranking_pipeline` is a high-performance MATLAB function designed to evaluate, validate, and rank eye-tracking gaze fixation classification algorithms for a single participant. By treating fixation clusters as spatial-temporal data partitions, the pipeline computes four standard cluster validation metrics: **Silhouette Score**, **Calinski-Harabasz Index**, **Davies-Bouldin Index**, and a parallelized **Gap Statistic**.

Algorithms are evaluated based on their ability to group raw gaze points into cohesive, distinct fixation events. The pipeline subsequently applies multi-criteria ranking decision rules, including **Borda count aggregation** and **majority voting**, with a multi-stage hierarchical tie-breaking protocol.

---

## Function Signature

```matlab
results = run_single_ranking_pipeline(cfg)
```

---

## Input Argument: `cfg` (Configuration Structure)

The input argument `cfg` is a scalar `struct` containing all necessary configuration settings, file locations, sampling specs, and execution hyperparameters.

| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `subjectID` | `integer` / `double` | **Yes** | Unique participant identifier (e.g., `101`). Used in console logging and output file naming. |
| `outputDir` | `char` / `string` | **Yes** | Target directory path where the output `.mat` results file will be saved. Directory is created if it does not exist. |
| `samplingFreq` | `double` | **Yes** | Sampling frequency of the eye-tracker in Hertz (Hz) (e.g., `120`). |
| `minFixDur` | `double` | **Yes** | Minimum duration threshold for valid fixations in seconds (e.g., `0.040` for 40 ms). |
| `B_per_worker` | `integer` | **Yes** | Number of null reference distribution bootstrap samples computed per parallel worker during the Gap Statistic calculation. |
| `algos` | `cell` array of `char` | **Yes** | Cell array containing the names of the active algorithms to evaluate (e.g., `{'i2mc', 'mnh', 'remo'}`). |
| `files` | `struct` | **Yes** | Nested structure mapping each algorithm name in `algos` to its corresponding MAT file path (e.g., `cfg.files.i2mc = 'data/p101_i2mc.mat'`). |

---

## Output Argument: `results` (Results Structure)

The function returns a `struct` containing raw metrics, full rank matrices, derived aggregate rankings, and identified top-performing algorithms.

| Field | Type | Dimensions | Description |
| :--- | :--- | :--- | :--- |
| `subjectID` | `double` | $1 x 1$ | Participant ID passed in `cfg.subjectID`. |
| `algos` | `cell` array | $1 x N$ | List of algorithm names evaluated ($N = \text{number of algorithms}$). |
| `metrics` | `struct` | Scalar | Nested structure containing computed raw metrics across all algorithms: |
| `metrics.s` | `double` | $1 x N$ | Silhouette scores for each algorithm. |
| `metrics.db` | `double` | $1 x N$ | Davies-Bouldin index values for each algorithm. |
| `metrics.ch` | `double` | $1 x N$ | Calinski-Harabasz index values for each algorithm. |
| `metrics.gap` | `double` | $1 x N$ | Gap Statistic values ($Gap(k) = E^*\{\log(W_k)\} - \log(W_k)$). |
| `metrics.numFixations` | `double` | $1 x N$ | Total count of valid fixation events detected by each algorithm. |
| `metrics.meanFixDur` | `double` | $1xN$ | Mean duration (in seconds) of valid fixation events for each algorithm. |
| `ranks` | `double` | $Nx4$ | Rank matrix across 4 metrics. Columns: `[Silhouette, Calinski-Harabasz, Davies-Bouldin, Gap]`. Rank 1 is best. |
| `mean_ranks` | `double` | $1xN$ | Borda count scores (mean rank across the 4 metrics per algorithm). |
| `borda_winner` | `char` | Vector | Name of the algorithm winning the Borda count evaluation (after hierarchical tie-breaking). |
| `majority_winner` | `char` | Vector | Name of the algorithm winning the most 1st-place ranks across the 4 metrics. |
| `max_wins` | `double` | $1x1$ | Highest number of 1st-place ranks achieved by `majority_winner`. |

---

## Workflow & Processing Steps

```
 +-----------------------------------------------------------------------+
 |                     Initialization & Warning Management               |
 |  - Disable 'stats:pdist2:DataConversion' warning                      |
 |  - Setup onCleanup handle to ensure warning state restoration         |
 |  - Initialize/Attach Parallel Pool (gcp / parpool)                    |
 +-----------------------------------------------------------------------+
                                     |
                                     v
 +-----------------------------------------------------------------------------+
 |                     STEP 1: Algorithm Evaluation Loop                       |
 |  For each algorithm in cfg.algos:                                           |
 |   1. Validate .mat file existence                                           |
 |   2. Load eyeData matrix [Time, Label, X, Y]                                |
 |   3. Call process_algo_data() -> Clean, filter < min duration, normalize    |
 |   4. Set data and cluster IDs to single precision (memory conservation)     |
 |   5. Compute Silhouette, Davies-Bouldin, and Calinski-Harabasz              |
 |   6. Compute Parallel Gap Statistic via parfeval across pool workers        |
 +-----------------------------------------------------------------------------+
                                     |
                                     v
 +-----------------------------------------------------------------------+
 |                     STEP 2: Algorithm Ranking & Voting                |
 |  1. Construct N x 4 Rank Matrix across Silhouette, CH, DB, Gap        |
 |  2. Compute mean rank vector (Borda score)                            |
 |  3. Compute first-place win counts per algorithm                      |
 |  4. Resolve winner using 3-stage hierarchical tie-breaking:           |
 |      a. Minimum mean rank                                             |
 |      b. Highest 1st-place win count                                   |
 |      c. Highest relative Gap Statistic score                          |
 |  5. Determine Majority Vote winner                                    |
 +-----------------------------------------------------------------------+
                                     |
                                     v
 +-----------------------------------------------------------------------+
 |                     STEP 3: Output                                    |
 |  - Construct results struct                                           |
 |  - Ensure output directory exists                                     |
 |  - Save to <outputDir>/algoEval_<subjectID>_results.mat               |
 +-----------------------------------------------------------------------+
```

---

## Detailed Step-by-Step Execution Breakdown

### Step 1: Environment Setup & Warning Handling
- Suppresses the MATLAB warning `stats:pdist2:DataConversion` which occurs when casting metrics to `single`. This is to keep command window clean.
- Registers an `onCleanup` guard object `restoreWarn` to ensure that warning settings are restored even if execution terminates unexpectedly or fails.
- Checks for an active parallel pool using `gcp('nocreate')`. If none exists, initializes a default parallel pool via `parpool()`.

### Step 2: Data Loading & Preprocessing
For each algorithm listed in `cfg.algos`:
1. Checks whether the MAT file path specified in `cfg.files.(algo)` exists. Raises an error if missing.
2. Loads the MAT file expecting an `eyeData` variable formatted as:
   - `eyeData(:, 1)`: Timestamp vector (seconds or milliseconds).
   - `eyeData(:, 2)`: Event labels (`1` = Fixation, non-1 = Non-fixation / Saccade / Noise).
   - `eyeData(:, 3:4)`: Gaze coordinates ($X, Y$).
3. Passes data into the helper function `process_algo_data`:
   - Re-labels non-fixations to label `2`.
   - Identifies contiguous fixation segments using `bwlabel`.
   - Computes segment durations via `accumarray` and eliminates noise segments shorter than 40 ms.
   - Filters fixations exceeding `cfg.minFixDur`.
   - Strips `NaN` values across coordinates and timestamps.
   - Applies min-max normalization to spatial-temporal columns $[X, Y, T]$, scaling data to $[0, 1]^3$.
4. Converts normalized features $n$ and cluster indices $ids$ to `single` data type to optimize memory overhead and distance computations.

### Step 3: Cluster Metric Evaluation
The function computes four intrinsic clustering validation indexes using MATLAB's `evalclusters`:

1. **Silhouette Value ($s$)**: Measures how similar an object is to its own cluster compared to other clusters.
   * Measures how well each data points fits its assigned cluster compared to the next nearest cluster. 
   * It is computed below, where $a_i$ is intra cluster (cohesion) and $b_i$ is nerest cluster (separation):

      $S = \frac{b_i - a_i} {max(a_i b_i)}$

   * Scores Range from -1 to 1. Higher scores reflect precise data point to event assignment: 

      $\text{Criterion}:\text{Maximize}$


2. **Davies-Bouldin Index ($db$)**: Measures average similarity ratio of each cluster with its most similar cluster.
   * Measures the ratio of within-cluster dispersion to the distance between each cluster and its most similar neighbor.
   * It is computed below, where $k$ represents the number of clusters, $S$ represnets internal dispersion, and $M_{ij}$ represents the distance between centroid $i$ and centroid $j$. 

      $DB=\frac{1}{k} \Sigma^k_{i=1} \text{max}_{j \neq i} (D_{i,j})$

   * Lower values indicate better clustering, with the ideal value being 0:

      $\text{Criterion}:\text{Minimize}$


3. **Calinski-Harabasz Index ($ch$)**: Ratio of sum of between-cluster dispersion to within-cluster dispersion.
   * Ratio of global between-cluster sum of squares, $BCSS$, and within-cluster sum of squares, $WCSS$, normalized by degrees of freedom.
   * Computed below, where $n$ is the total number of data points and $k$ represents number of clusters:

      $CHI = \frac{BCSS}{WCSS} \times \frac{(N-k)}{(k-1)}$

   * Higher values indicate better defined clusters:

      $\text{Criterion}:\text{Maximize}$


4. **Parallel Gap Statistic ($gap$)**: Compares total intra-cluster variation with expected null reference distribution.
   * Assesses if clustering structure is more meaningful than a random distribution. 
   * Computed below, where $W_k$ is the within-cluster sum of squares for $k$ number of clusters, and $E^*_n$ is the expected value of $log(W-k)$ from the reference distribution:

      $G = E^*_n log (W+k) - log(W_k)$

   * A value of zero indiactes structure is no more meaningful than if we assigned points to a clauster at random, while a higher value indicates robust structure:

      $\text{Criterion}:\text{Maximize}$

   * Executed in parallel using asynchronous `parfeval` worker tasks across all available workers in the parallel pool.
   * Each worker computes `cfg.B_per_worker` reference distributions.
   * Results are fetched and aggregated:
    
     $\text{Gap}(k) = \overline{\log(W_k^*)}_{\text{workers}} - \log(W_k^{\text{observed}})$

---

## Ranking Engine & Hierarchical Tie-Breaking

The algorithms are ranked independently on each metric. A rank of `1` represents the highest performing algorithm for that metric.

### Metric Sorting Directives
| Metric | Sort Order | Optimal Direction |
| :--- | :--- | :--- |
| **Silhouette** | Descending | Higher is better |
| **Calinski-Harabasz** | Descending | Higher is better |
| **Davies-Bouldin** | Ascending | Lower is better |
| **Gap Statistic** | Descending | Higher is better |

### Borda Count & Tie-Breaking Hierarchy

The primary evaluation criterion is the Borda Count, represented by `mean_ranks = mean(ranks, 2)`. The algorithm with the lowest mean rank is selected as `borda_winner`. 

In the event of a tie in mean ranks, the tie is broken using the following strict hierarchy:

```
                  +-----------------------------------+
                  |      Evaluate Mean Ranks          |
                  +-----------------------------------+
                                    |
                        Is min mean rank unique?
                        /                      \
                       /                        \
                     YES!                       NO...
                     /                            \
        +-------------------------+    +----------------------------------+
        | Declare Winner          |    | Stage 1 Tie-Break:               |
        +-------------------------+    | Compare 1st-Place Win Counts     |
                                       +----------------------------------+
                                                        |
                                          Is highest win count unique?
                                          /                        \
                                       YES!                         NO...
                                        /                            \
                           +-------------------------+  +-------------------------------+
                           | Declare Winner          |  | Stage 2 Tie-Break:            |
                           +-------------------------+  | Compare Relative Gap          |
                                                        | Statistic Score               |
                                                        +-------------------------------+
                                                                        |
                                                        +-------------------------------+
                                                        | Declare Winner                |
                                                        +-------------------------------+
```

1. **Stage 1 (Primary Score)**: Select algorithm(s) with the minimum `mean_ranks`.
2. **Stage 2 (First-Place Wins)**: If multiple algorithms share the minimum mean rank, select the algorithm with the highest number of 1st-place metric ranks (`first_place_wins`).
3. **Stage 3 (Gap Statistic Priority)**: If a tie still persists, select the candidate with the highest raw Gap Statistic value (`metrics.gap`) among the remaining tied algorithms.

### Majority Vote Winner
`majority_winner` is determined directly by selecting the algorithm with the maximum count of 1st-place ranks across the 4 cluster metrics:

   $\text{majority\_winner} = \text{arg}\max_{a} \sum_{m=1}^{4} \mathbb{I}(\mathbf{R}_{a, m} = 1)$

---

## Helper Function: `process_algo_data`

An internal helper function that cleans and prepares time-series gaze data for cluster analysis.

```matlab
[norm_data, clean_ids, meanFixDur] = process_algo_data(time, coors, labels, fs, minFixDur)
```

### Input Arguments
- `time` (`vector`): Raw sample timestamps.
- `coors` (`matrix`): $N 	imes 2$ matrix of $(X, Y)$ gaze coordinates.
- `labels` (`vector`): Event classification vector ($1 =\text{Fixation}$).
- `fs` (`double`): Eyetracker sampling frequency in Hz.
- `minFixDur` (`double`): Minimum fixation threshold (seconds).

### Processing Steps & Quality Control
1. **Binarization**: Maps labels non-equal to 1 as 2 (non-fixations).
2. **Event Extraction**: Uses `bwlabel` on `labels == 1` to index continuous fixation segments.
3. **Min Duration Noise Floor**: Calculates durations via `accumarray` ($Duration = \max(T) - \min(T) + rac{1}{f_s}$). Fixations shorter than the threshold ms (example: $0.040\text{ s}$) are flagged as invalid noise and discarded.
4. **Threshold Filtering**: Keeps fixations with $Duration \ge \text{minFixDur}$. Computes `meanFixDur` only on valid fixations.
5. **NaN Removal**: Filters out rows containing `NaN` in $X, Y$, or timestamp channels.
6. **Contiguous Indexing**: Re-indexes valid fixation groups sequentially from $1 \dots K$ using `grp2idx`.
7. **Min-Max Normalization**: Scales feature matrix $[X, Y, T]$ into range $[0, 1]$ using:
   
   $X_{\text{norm}} = \frac{X - X_{\min}}{X_{\max} - X_{\min}}$
   *(If $X_{\max} - X_{\min} = 0$, range is set to 1 to prevent division-by-zero).*

---

## Code Example

Code can be executed by using the GUI wrapper `gui_single_ranking_pipeline`. If you would like to call this function without using the GUI wrapper, below is a complete script demonstrating how to configure and execute `run_single_ranking_pipeline`.

```matlab
% Set up configuration structure
cfg = struct();
cfg.subjectID    = 101;
cfg.outputDir    = './output_results';
cfg.samplingFreq = 120;          % 120 Hz eye tracker
cfg.minFixDur    = 0.040;        % 40 ms minimum fixation duration
cfg.B_per_worker = 10;           % Gap stat bootstrap samples per worker
cfg.algos        = {'i2mc', 'mnh', 'remo'};

% Define input data file paths for each algorithm
cfg.files = struct();
cfg.files.i2mc = './data/data_101_i2mc.mat';
cfg.files.mnh  = './data/data_101_mnh.mat';
cfg.files.remo = './data/data_101_remo.mat';

% Execute pipeline
results = run_single_ranking_pipeline(cfg);

% Inspect results
fprintf('
===== Evaluation Summary for Participant %d =====
', results.subjectID);
fprintf('Borda Winner:    %s
', results.borda_winner);
fprintf('Majority Winner: %s (Wins: %d/4)
', results.majority_winner, results.max_wins);

% Display detailed rank table
disp('Rank Matrix (Rows: Algos, Cols: [S, CH, DB, Gap]):');
disp(array2table(results.ranks, 'RowNames', results.algos, ...
    'VariableNames', {'Silhouette', 'CalinskiHarabasz', 'DaviesBouldin', 'Gap'}));
```

---

## Required Toolboxes & Dependencies

To execute `run_single_ranking_pipeline.m`, the following MATLAB Toolboxes must be installed and licensed:

- **Statistics and Machine Learning Toolbox**: Required for `evalclusters`, `pdist2`, `accumarray`, and `grp2idx`.
- **Parallel Computing Toolbox**: Required for `gcp`, `parpool`, `parfeval`, `parallel.FevalFuture`, and `fetchOutputs`.
- **Image Processing Toolbox**: Required for `bwlabel` continuous event extraction.

---

## Input File Requirements

Input `.mat` files specified in `cfg.files.(algo)` must contain a variable named `eyeData` with 4 columns:

   $\mathbf{eyeData} = \left[ \begin{array}{cccc}
   t_1 & l_1 & x_1 & y_1 \\ 
   t_2 & l_2 & x_2 & y_2 \\
   \vdots & \vdots & \vdots & \vdots \\ 
   t_n & l_n & x_n & y_n 
   \end{array}\right]$

- **Column 1 (`time`)**: Monotonic timestamp values.
- **Column 2 (`labels`)**: Event label integer ($1 =\text{Fixation}$, any other value = non-fixation).
- **Column 3 (`X`)**: Horizontal gaze position coordinates.
- **Column 4 (`Y`)**: Vertical gaze position coordinates.
