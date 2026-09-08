# `get_data_by_trials.m` Documentation

## Overview
`get_data_by_trials` extracts and aligns trial-segmented eye-tracking and bimanual hand kinematic data for behavioral experiments. It synchronizes multimodal data streams (Tobii gaze trajectories, Presentation stimulus logs, and dual-hand movement kinematics) into common LSL (Lab Streaming Layer) time coordinates, segments data bounded by physical hand movement onsets and offsets, and outputs trial-structured cell arrays saved to a MATLAB `.mat` file.

---

## Function Signature

```matlab
[eyeTrialData, raw_eyeTrialData, handTrialData] = get_data_by_trials( ...
    baseFilePath, pilotPath, EyeParams, ui_group_str, ...
    ui_subjectID_int, ui_condition_str, ui_algo_str, ...
    ui_targetSize_int, numTrials)
```

---

## Arguments & Parameters

### Input Arguments

| Parameter | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `baseFilePath` | `char` / `string` | **Yes** | Root project output directory path. |
| `pilotPath` | `char` / `string` | **Yes** | Directory path containing raw data files and post-step 1 kinematic files. |
| `EyeParams` | `struct` | **Yes** | Display and acquisition parameter structure containing screen specs and sampling rate. |
| `ui_group_str` | `char` / `string` | **Yes** | Participant group identifier folder name (e.g., `'G01'`). |
| `ui_subjectID_int` | `char` / `string` / `integer` | **Yes** | Unique subject identifier (e.g., `101` or `'101'`). |
| `ui_condition_str` | `char` / `string` | **Yes** | Experimental condition tag (e.g., `'bln'`). |
| `ui_algo_str` | `char` / `string` | **Yes** | Eye classification algorithm tag (`'remo'`, `'mnh'`, or `'i2mc'`). |
| `ui_targetSize_int` | `integer` | **Yes** | Target size flag. Appends `_lg` suffix to file names if equal to `2` (otherwise set to `1`). |
| `numTrials` | `integer` | **Yes** | Total number of experimental trials to segment (e.g., `50`). |

#### `EyeParams` Structure Fields

| Field | Type | Unit | Description |
| :--- | :--- | :--- | :--- |
| `screenWidthInCm` | `double` | cm | Physical display screen width in centimeters. |
| `screenHeightInCm` | `double` | cm | Physical display screen height in centimeters. |
| `samplingFreq` | `double` | Hz | Eye-tracker acquisition sampling frequency in Hz. |

---

### Output Arguments

| Output Variable | Type | Dimensions | Description |
| :--- | :--- | :--- | :--- |
| `eyeTrialData` | `cell` array | $1 \times \text{numTrials}$ | Contains event-classified eye tracking matrices segmented per trial. |
| `raw_eyeTrialData` | `cell` array | $1 \times \text{numTrials}$ | Contains raw Tobii gaze trajectories `[relative_time, x_cm, y_cm]` segmented per trial. |
| `handTrialData` | `cell` array | $1 \times \text{numTrials}$ | Contains structs with `.left` and `.right` matrices containing hand trajectories `[rel_time, x, y]`. |

---

## File System & Path Resolutions

The function resolves cross-platform paths based on input naming parameters:

* **Algorithm Classification MAT File**:
  * Eye data file: `baseFilePath/post_step2/<ui_group_str>/<ui_algo_str>_results/data_<subj>_<cond><size>_<algo>_converted.mat`.
* **Kinematics MAT Files**:
  * Right Hand: `pilotPath/<ui_group_str>/post_step1/data_<subj>_<cond>_rh<size>.mat`.  
  * Left Hand: `pilotPath/<ui_group_str>/post_step1/data_<subj>_<cond>_lh<size>.mat`.
* **Raw Recording Files**:
  * LSL XDF Stream: `pilotPath/<ui_group_str>/raw/<subj>_<cond><size>.xdf`.  
  * Presentation Log: `pilotPath/<ui_group_str>/raw/<subj>_<cond><size>-Case 423.log`.
* **Output Destination File**:
  * Saved to `baseFilePath/post_step3/<ui_group_str>/<ui_algo_str>/data_<subj>_<cond><size>_<algo>.mat`.

---

## Processing Execution Flow

```
                      +---------------------------------------+
                      | 1. Parameter Standardization & Paths  |
                      |    - Format subject ID & target suffix|
                      |    - Resolve and validate file paths  |
                      +---------------------------------------+
                                          |
                                          v
                      +---------------------------------------+
                      | 2. Load Raw & Post-Processed Streams  |
                      |    - Load kinematics & eye mat files  |
                      |    - Parse XDF stream via helper      |
                      +---------------------------------------+
                                          |
                                          v
                      +----------------------------------------+
                      | 3. Spatial & Temporal Alignment        |
                      |    - Scale normalized gaze to cm       |
                      |    - Compute LSL clock offset          |
                      |    - Construct uniform LSL time vectors|
                      +----------------------------------------+
                                          |
                                          v
                      +---------------------------------------+
                      | 4. Trial Segmentation Loop (1..N)     |
                      |    - Check wrong_trial flags          |
                      |    - Determine t = 0 (min hand onset) |
                      |    - Segment hand kinematics          |
                      |    - Segment raw & classified eye data|
                      +---------------------------------------+
                                          |
                                          v
                      +---------------------------------------+
                      | 5. Output Serialization (.mat File)   |
                      |    - Save output cells & error vectors|
                      +---------------------------------------+
```

### Detailed Processing Steps

1. **Spatial Coordinates Conversion**:
   Normalizes raw Tobii gaze position relative to screen center $(0,0)$ and scales to physical centimeters:
   $$\text{xMean\_cm} = \left(\text{mean}(X_{\text{raw}}) - 0.5\right) \times \text{EyeParams.screenWidthInCm}$$
   $$\text{yMean\_cm} = \left(0.5 - \text{mean}(Y_{\text{raw}})\right) \times \text{EyeParams.screenHeightInCm}$$

2. **Temporal Alignment**:
   Calculates clock offset using David McFarlane's function `Presentation_to_LSL_offset` to align local Presentation time with LSL time coordinates:
   $$\text{time\_LSL} = \left(\frac{\text{kinematic\_time\_ms}}{1000}\right) + \text{offset}$$
   Constructs a uniform, double-precision timeline vector for raw eye-tracking samples using `EyeParams.samplingFreq`.

3. **Trial Segmentation & Alignment**:
   * Evaluates `wrong_trial` flags in both left and right hand data structures.
   * Identifies physical movement boundaries:
     $$\text{trial\_onset\_LSL} = \min\left(t_{\text{rh, start}}, t_{\text{lh, start}}\right)$$
     $$\text{trial\_offset\_LSL} = \max\left(t_{\text{rh, end}}, t_{\text{lh, end}}\right)$$
   * Normalizes timestamps relative to movement onset ($t = 0 \text{ s}$).
   * Extracts corresponding time windows for raw gaze, classified eye metrics, and left/right hand trajectories.

---

## Code Usage Example

This function is called by the GUI wrapper `gui_3_data_by_trials.m`. If you would like to call the function using a separate script, here is an exampe:
```matlab
% Set up paths and display parameters
baseFilePath = 'Z:\Data\Eyetracking\pilot\outputFolder';
pilotPath    = 'Z:\Data\Eyetracking\pilot';

EyeParams = struct();
EyeParams.screenWidthInCm  = 47.7;  % 47.7 cm wide monitor
EyeParams.screenHeightInCm = 26.8;  % 26.8 cm tall monitor
EyeParams.samplingFreq     = 120; % 120 Hz eye tracker

% Parameter configuration
ui_group_str      = 'G01';
ui_subjectID_int  = 101;
ui_condition_str  = 'bln';
ui_algo_str       = 'i2mc';
ui_targetSize_int = 1; % Standard target size, use 2 for lg
numTrials         = 50;

% Run segmentation pipeline
[eyeTrialData, raw_eyeTrialData, handTrialData] = get_data_by_trials( ...
    baseFilePath, pilotPath, EyeParams, ui_group_str, ...
    ui_subjectID_int, ui_condition_str, ui_algo_str, ...
    ui_targetSize_int, numTrials);

% Inspect segmented data for trial 1
trial1_left_hand = handTrialData{1}.left;   % [rel_time, x, y]
trial1_raw_eye   = raw_eyeTrialData{1};     % [rel_time, x_cm, y_cm]
trial1_algo_eye  = eyeTrialData{1};         % Classification event matrix
```

---

## Dependencies & Helper Functions

The function requires the following internal helper functions and toolboxes:

* `load_TobiiPresentation(lslFile)`: Custom function by David McFarlane to parse `.xdf` files into gaze trajectories and event markers.
* `Presentation_to_LSL_offset(pres_lslData, presLogFile)`: Custom function by David McFarlane to synchronize Presentation log events with LSL system clocks.