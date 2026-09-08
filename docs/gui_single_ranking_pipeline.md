# `gui_single_ranking_pipeline` Documentation

This tool provides a graphical user interface for running single-participant fixation data through cluster metrics evaluation (Silhouette, Calinski-Harabasz, Davies-Bouldin, and Gap Statistic) and automatically ranks candidate event-detection algorithms.

This GUI wrapper calls the function `run_single_ranking_pipeline.m`.

---

## Annotated UI Layout & Workflow

![UI Example](algo_rank_example_annotated.png)

### Component Reference

| Identifier | UI Element | Function |
| :--- | :--- | :--- |
| **[A]** | Text Area | Displays required matrix variables (`eyeData`) and formatting instructions. |
| **[B]** | Numeric Fields | Edits numeric `Participant ID` and `Min Fixation Duration (s)`. |
| **[C]** | File Pickers | Browses and loads algorithm-specific `.mat` event classification files. |
| **[D]** | Directory Picker | Configures output folder path for saving analysis results. |
| **[E]** | Button | Triggers ranking pipeline execution and disables inputs during calculation. |
| **[F]** | Log | Console streaming real-time status, metric summaries, and warnings. |
| **[G]** | Dashboard Tile 1 | Displays text summary of overall rank and majority vote winners. |
| **[H]** | Dashboard Tile 2 | Bar plot rendering mean metric ranks across evaluated algorithms. |
| **[I]** | Dashboard Tile 3 | Grouped bar plot detailing metric-by-metric ordinal ranks. |
| **[J]** | Dashboard Tile 4 | Dual-axis plot comparing total fixation counts and mean durations. |

---

### Dependencies
* Statistics and Machine Learning Toolbox
* Parallel Computing Toolbox
* Image Processing Toolbox

| MATLAB Toolbox | Required for |
| :--- | :--- | 
| Statistics and Machine Learning | evalclusters, pdist2, accumarray, grp2idx |
| Parallel Computing | gcp, parpool, parfeval, parallel.FevalFuture, fetchOutputs |
| Image Processing | bwlabel |

---

## Expected Input/Output Schemas

### Input File Schema

* **File Type:** MATLAB Data (`.mat`)
* **Required Variable Name:** `eyeData`
* **Matrix Structure:** N x 4 numeric matrix (where N is total sample count)

| Column Index | Variable Name | Data Type | Description |
| :--- | :--- | :--- | :--- |
| **1** | Timestamps | `double` | Sample timestamps in seconds |
| **2** | Event Label | `double` / `integer` | Classification label (`1` = Fixation, `2` or other = Saccade / Pursuit / Noise / any non-Fixation event) |
| **3** | X Coordinates | `double` | Horizontal gaze position (cm) |
| **4** | Y Coordinates | `double` | Vertical gaze position (cm) |

---

### Output File Schema

* **Saved Location:** `<Output Folder>/algoEval_<subjectID>_results.mat`
* **Saved Structure:** `results`

```matlab
results = 
        subjectID: 101
            algos: {'i2mc', 'mnh', 'remo'}
          metrics: [1x1 struct]  % s, db, ch, gap, numFixations, meanFixDur
            ranks: [3x4 double]  % Ordinal ranks across 4 metrics
       mean_ranks: [1x3 double]  % Mean rank per algorithm
     borda_winner: 'i2mc'        % Rank count overall winner
  majority_winner: 'i2mc'        % Majority vote winner
         max_wins: 3             % Count of metric first-place finishes
```

---

## Default Parameters Table

| Parameter Field | Default Value | Allowed Range / Type | When to Alter |
| :--- | :--- | :--- | :--- |
| **Participant ID** | `101` | Integer (> 0) | Set to match the current participant. |
| **Min Fixation Dur (s)** | `0.04` (40 ms) | Numeric | Modify as needed. |
| **Sampling Frequency** | `120` Hz | Fixed numeric (> 0) | Eye tracker sampling rate in Hz (`cfg.samplingFreq`). Modify in code as needed. |
| **Gap Stat Reps (`B`)** | `25` | Integer (10 to 100) | Internal configuration for parallel processing (`cfg.B_per_worker`). Increase for quality; decrease for fast GUI testing. |
| **Output Folder** | `./output` | Valid path string | Change to save outputs to an external drive or root project directory. |