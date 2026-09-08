# `run_single_algorithm_pipeline.m` Documentation

## Overview

`run_single_algorithm_pipeline` executes single-participant eye-tracking event classification across three supported algorithms: **I2MC**, **MNH**, or **REMoDNaV**. It loads preprocessed Tobii gaze data, converts spatial coordinates into algorithm-specific input formats, invokes the classification engine, performs quality control (QC) by filtering short fixations, saves output files to disk, and displays quick diagnostic visual plots.

---

## Function Signature

```matlab
results = run_single_algorithm_pipeline(cfg)
```

---

## Configuration Parameter Structure (`cfg`)

The function accepts a single configuration struct `cfg` containing participant metadata, directory paths, algorithm specifications, and eye-tracking acquisition parameters.

| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `inputFile` | `string` / `char` | **Yes** | Path to preprocessed `.mat` file containing a `tobiiData` structure. |
| `baseDir` | `string` / `char` | **Yes** | Root project directory path. |
| `group` | `string` / `char` | **Yes** | Participant group identifier (e.g., `'G01'`). |
| `subjectID` | `string` / `char` | **Yes** | Unique participant identifier (e.g., `'101'`). |
| `condition` | `string` / `char` | **Yes** | Experimental condition tag (e.g., `'bln'`). |
| `algo` | `string` / `char` | **Yes** | Classification algorithm selection: `'i2mc'`, `'mnh'`, or `'remo'`. |
| `targetSize` | `integer` | **Yes** | Target size flag. Passing `2` appends `_lg` suffix to output files; `1` uses standard naming. |
| `savgolSec` | `double` | Conditional | Savitzky-Golay filter length in seconds (required for REMoDNaV input). |
| `eyeParams` | `struct` | **Yes** | Sub-structure defining display and tracker acquisition parameters. |

### `cfg.eyeParams` Fields

| Field | Type | Unit | Description |
| :--- | :--- | :--- | :--- |
| `samplingFreq` | `double` | Hz | Eye-tracker sampling frequency (e.g., `120`). |
| `cmToPixel` | `double` | px/cm | Spatial scaling conversion factor from centimeters to pixels. |
| `pixelToDegrees` | `double` | deg/px | Spatial scaling conversion factor from pixels to visual degrees. |
| `minFixDuration` / `minFixDur` | `double` | seconds | Minimum fixation duration threshold (e.g., `0.04` s). |

---

## Output Structure (`results`)

The returned `results` struct contains sample-by-sample classifications, algorithm-specific intermediate structures, and execution parameters:

| Field | Type | Applicable Algorithms | Description |
| :--- | :--- | :---: | :--- |
| `sampledData` | `matrix` | **All** | Standardized sample-by-sample output matrix `[time_sec, event_label, x_cm, y_cm, ...]`. |
| `labels` | `vector` | REMoDNaV | Sample-level event classification labels vector. |
| `ET` | `struct` | MNH | MNH event detection output structure. |
| `fix` | `struct` | I2MC | I2MC detected fixation events structure. |
| `data` | `struct` | I2MC | Formatted gaze input data structure for I2MC. |
| `opt` | `struct` | I2MC | I2MC algorithm options structure. |
| `ndata` | `struct` | I2MC | Downsampled/filtered data structure. |
| `npar` | `struct` | I2MC | Processing parameters utilized by I2MC. |
| `cfg` | `struct` | **All** | Exact copy of the input configuration struct. |

---

## Processing Execution Pipeline

```
                     +---------------------------------------+
                     | 1. Validate File & Load 'tobiiData'   |
                     +---------------------------------------+
                                         |
                                         v
                     +---------------------------------------+
                     | 2. Resolve Paths & Output Directories |
                     |    - post_step1/<group>/              |
                     |    - post_step2/<group>/<algo>_results|
                     +---------------------------------------+
                                         |
                                         v
                     +----------------------------------------+
                     | 3. Compute Timeline & Base Centimeters |
                     |    - Mean pupil & validity vectors     |
                     |    - Uniform time vector (msec)        |
                     +----------------------------------------+
                                         |
                                         v
                     +---------------------------------------+
                     | 4. Algorithm Preparation & Execution  |
                     |                                       |
                     |  +---------------------------------+  |
                     |  | REMoDNaV ('remo')               |  |
                     |  | - Convert cm to pixels          |  |
                     |  | - Export .txt to post_step1     |  |
                     |  | - System CLI call (remodnav)    |  |
                     |  | - Call convertRemoData()        |  |
                     |  +---------------------------------+  |
                     |  | MNH ('mnh')                     |  |
                     |  | - Convert cm to degrees         |  |
                     |  | - Export .csv to post_step1     |  |
                     |  | - Call mnhBeginEventDetection() |  |
                     |  | - Call convertMNHData()         |  |
                     |  +---------------------------------+  |
                     |  | I2MC ('i2mc')                   |  |
                     |  | - Build coordinate matrix       |  |
                     |  | - Call importTobiiProFusion()   |  |
                     |  | - Run I2MCfunc()                |  |
                     |  | - Call convertI2MCData()        |  |
                     |  +---------------------------------+  |
                     +---------------------------------------+
                                         |
                                         v
                     +---------------------------------------+
                     | 5. Quality Control: Minimum Fixations |
                     |    - qc_min_fixation_duration()       |
                     |    - Relabel short fixations to 4     |
                     +---------------------------------------+
                                         |
                                         v
                     +---------------------------------------+
                     | 6. Serialization & Plot Diagnostics   |
                     |    - Save output .mat in post_step2   |
                     |    - Call display_quick_plots()       |
                     +---------------------------------------+
```

---
## Quality Control (QC) Logic: Minimum Fixation Duration

The internal `qc_min_fixation_duration(res, cfg)` helper function enforces duration thresholds on detected fixations:

1. Identifies contiguous fixation segments where `event_label == 1` using `bwlabel`.
2. Computes duration $T_{\text{fix}}$ for each segment using sample timing and sampling frequency $f_s$:
   $$T_{\text{effective\_thresh}} = \text{minFixDur} - \frac{1}{2 f_s}$$
3. Any fixation segment with duration $T_{\text{fix}} < T_{\text{effective\_thresh}}$ is re-classified to event label `4` (Noise / Invalid).
4. Prints an informational log message detailing the count of relabeled fixations.

---

## Internal Helper Functions

### 1. `qc_min_fixation_duration(res, cfg)`
* **Input**: Results structure `res` containing `sampledData`, configuration `cfg`.
* **Output**: Modified results structure `clean_res` with updated event labels in `sampledData(:, 2)`.

### 2. `display_quick_plots(res)`
* **Input**: Results structure `res`.
* **Output**: Displays a $1 \times 2$ subplot figure showing:
  * **Left Plot**: 2D gaze trajectory $(X, Y)$ in centimeters.
  * **Right Plot**: Histogram of classified event label distributions.

---

## Example Usage

This is easiest to call by using the GUI wrapper `gui_2_single_algo_pipeline.m`. However, if you would like to call it without the GUI, here is an example:

```matlab
% Set up configuration struct
cfg = struct();
cfg.inputFile  = 'Z:\Data\Eyetracking\pilot\yourProjectFolder\post_step1\data_101_bln_preprocessed.mat';
cfg.baseDir    = 'Z:\Data\Eyetracking\pilot\yourProjectFolder';
cfg.group      = 'G01';
cfg.subjectID  = '101';
cfg.condition  = 'bln';
cfg.algo       = 'i2mc';
cfg.targetSize = 1;

% Configure acquisition & display parameters
cfg.eyeParams.samplingFreq = 120;
cfg.eyeParams.cmToPixel    = 40;
cfg.eyeParams.pixelToDegrees = 0.0226;
cfg.eyeParams.minFixDur    = 0.04; % for a 40 ms fixation minimum duration threshold

% Execute classification pipeline
results = run_single_algorithm_pipeline(cfg);

% Inspect sample classification output
sampled_matrix = results.sampledData; % [time_sec, label, x_cm, y_cm]
```

---

## System Requirements & External Dependencies

* **MATLAB Toolboxes**: Signal Processing Toolbox (for Savitzky-Golay filtering and array operations).
* **REMoDNaV**: Python `remodnav` package installed and accessible via system PATH (if `cfg.algo = 'remo'`).
* **MNH**: MNH functions on MATLAB path.
* **I2MC**: I2MC functions on MATLAB path.
* **Internal Functions**: `convertI2MCData`, `convertMNHData`, `convertRemoData` on MATLAB path.