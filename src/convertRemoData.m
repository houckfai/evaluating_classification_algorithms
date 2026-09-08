function [sampledData, sampledData_RemoLabels] = convertRemoData(baseFilePath, EyeParams, ui_group_str, ui_subjectID_int, ui_condition_str, ui_targetSize_int, tobii)
% Converts REMoDNaV string event labels to standardized numeric integer codes.
%
% Loads the sample-wise REMoDNaV output .csv tables (from modified REMoDNaV
% clf.py file). Converts gaze coordinates from pixels back to centimeters,
% aligns timestamps with raw Tobii data timestamps. Maps raw REMoDNaV
% string event labels to integer codes. Constructs a remapped label matrix
% aligned with the MNH categorization scheme.
%
% ARgs:
%   baseFilePath (str): Root project directory path.
%   EyeParams (struct): Display & setup parameters containing:
%       cmToPixel (float): Conversion factor from centimeters to pixels.
%       samplingFreq (float): Eye tracker sampling rate in Hz. 
%   ui_group_str (str): Participant group identifier (e.g., 'G01').
%   ui_subjectID_int (str | int): Unique participant identifier (e.g., '101' or 101).
%   ui_condition_str(str): Experimental condition tag.
%   ui_targetSize_int (int): Experimental task target size flag (uses '_lg' suffix if equal to 2). If n/a to your data, use 1.
%   tobii (struct): Tobii eyetracking struct containing time_stamps array.
%
% Returns:
%   tuple: A tuple containing:
%       sampledData (matrix): N-by-4 matrix of [time_sec, MNH_label, x_cm, y_cm] where MNH_label uses 1=Fixation, 2=Saccade, 3=PSO, 4=Noise/Artifact. Any REMoDNaV Smooth Pursuits are labeled as 8.
%       sampledData_RemoLabels (matrix): N-by-4 matrix of [time_sec, remo_label, x_cm, y_cm] using integer version of REMoDNaV's event label scheme (1=FIXA, 2=SACC, 3=ISAC, 4 = LPSO, 5=HPSO, 6=ILPS, 7=IHPS, 8=PURS, 9=UNKN).
%
% Raises:
%   MException: If sample length mismatch between Tobii data & REMoDNaV
%   output exceeds 2 samples.

    % Initialize outputs to prevent unassigned output crashes on early exit
    sampledData = [];
    sampledData_RemoLabels = [];

    % Normalize Subject ID string
    if isnumeric(ui_subjectID_int)
        subjStr = num2str(ui_subjectID_int);
    else
        subjStr = char(ui_subjectID_int);
    end

    % ================1. Construct Cross-Platform File Paths===============
    sizeTag = '';
    if ui_targetSize_int == 2, sizeTag = '_lg'; end

    dataTitle = sprintf('data_%s_%s%s_remo', subjStr, ui_condition_str, sizeTag);
    remoDir = fullfile(baseFilePath, 'post_step2', ui_group_str, 'remo_results');
    
    remoFile = fullfile(remoDir, [dataTitle, '.txt']);
    remoOutputTable = fullfile(remoDir, [dataTitle, '_events_samplewise.csv']);

    % Validate existence of input files
    if ~isfile(remoFile) || ~isfile(remoOutputTable)
        warning('REMoDNaV output file not found for %s in %s', dataTitle, remoDir);
        return;
    end

    % ==================2. Load Table and Convert Event Labels ============
    remoTable = readtable(remoOutputTable);
    remoTable.label = string(remoTable.label);

    % Convert coordinates from pixels back to centimeters
    x_cm = remoTable.x / EyeParams.cmToPixel;
    y_cm = remoTable.y / EyeParams.cmToPixel;

    % Relabel REMoDNaV text labels to integer codes
    remoIntLabels = zeros(height(remoTable), 1);
    
    remoIntLabels(strcmp(remoTable.label, 'FIXA')) = 1;
    remoIntLabels(strcmp(remoTable.label, 'SACC')) = 2;
    remoIntLabels(strcmp(remoTable.label, 'ISAC')) = 3;
    remoIntLabels(strcmp(remoTable.label, 'LPSO')) = 4;
    remoIntLabels(strcmp(remoTable.label, 'HPSO')) = 5;
    remoIntLabels(strcmp(remoTable.label, 'ILPS')) = 6;
    remoIntLabels(strcmp(remoTable.label, 'IHPS')) = 7;
    remoIntLabels(strcmp(remoTable.label, 'PURS')) = 8;
    remoIntLabels(strcmp(remoTable.label, 'UNKN')) = 9;

    % Remap integer labels to match MNH categorization scheme:
    % 1 = Fixation, 2 = Saccade types, 3 = PSO types, 4 = Noise/Artifact
    remoLabels_MNH = remoIntLabels;
    remoLabels_MNH(remoIntLabels == 3) = 2; % ISAC -> Saccade
    remoLabels_MNH(ismember(remoIntLabels, 4:7)) = 3; % PSO types -> PSO
    remoLabels_MNH(remoIntLabels == 9) = 4; % UNKN -> Noise/Artifact

    % ==========3. Align Time Vector and Prevent Dimension Crashes ========
     % create uniform time grid starting at first tobii time sample:
    N = length(tobii.time_stamps);
    timeSec = tobii.time_stamps(1) + (0:N-1)' / EyeParams.samplingFreq;
    timeSec = timeSec(:); % force column vector

    x_cm = x_cm(:);
    y_cm = y_cm(:);

    % Trim to shortest array length to prevent matrix concatenation crashes
    minLen = min([length(timeSec), length(remoIntLabels), length(x_cm)]);
    if length(timeSec) ~= length(x_cm)
        lenDiff = length(timeSec) - length(remoIntLabels);
        if lenDiff > 2
            error('Length difference between Tobii & REMoDNaV results: %d', minLen);
        else 
            warning('Length discrepancy detected! Truncating arrays to min length (%d samples).', minLen);
        end 
    end

    time_seconds   = timeSec(1:minLen);
    remoIntLabels  = remoIntLabels(1:minLen);
    remoLabels_MNH = remoLabels_MNH(1:minLen);
    x_cm           = x_cm(1:minLen);
    y_cm           = y_cm(1:minLen);

    % Assemble final numeric matrices
    sampledData_RemoLabels = [time_seconds, remoIntLabels,  x_cm, y_cm];
    sampledData            = [time_seconds, remoLabels_MNH, x_cm, y_cm];

    % ============= 4. Cross-Platform Output Saving========================
    if ~exist(remoDir, 'dir'), mkdir(remoDir); end
    output_name = fullfile(remoDir, [dataTitle, '_converted.mat']);
    save(output_name, 'sampledData', 'sampledData_RemoLabels');
end