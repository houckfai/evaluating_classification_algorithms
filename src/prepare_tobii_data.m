function [tobiiData, savedFile] = prepare_tobii_data(cfg)
% Preprocesses raw LSL XDF, and Presentation log files.
%
% Loads raw eye tracking data (.xdf) and Presentation log files (.log) from
% the raw data directory, converts screen coordinates to centimeters
% relative to the screen center, and saves the preprocessed output to a
% .mat file.
%
% Args:
%   cfg (struct): Configuration parameters containing:
%       rawDir (str): Path to directory containing the raw data files (xdf file & log file).
%       outDir (str): Path to directory where output .mat file will be saved.
%       subjectID (str | int): Unique participant identified.
%       condition (str): Experimental condition tag.
%       logSuffix (str): Suffix appended to Presentation log file names.
%       targetSize (int): Experimental task target size flag (uses '_lg' suffix if equal to 2). If n/a to your data, use 1.
%       eyeParams (struct): The dispaly dimensions containing:
%           screenWidthInCm (float): Display screen width in centimeters.
%           screenHeightInCm (float): Display screen height in centimeters.
%
% Returns:
%       tuple: A tuple containing:
%           tobiiData (struct): eye tracking data struct containing timestamp series and computed centimeter gaze (xMean_cm, yMean_cm).
%           savedFile (str): Full file path of the saved preprocessed .mat file.
%
% Raises:
%   MException: If cfg.rawDir directory does not exist.
%   MException: If the raw LSL XDF file is missing.
%   MException: If the Presentation Log file is missing.





    % 1. Validate Input Directory
    if ~exist(cfg.rawDir, 'dir')
        error('Specified raw data directory does not exist: %s', cfg.rawDir);
    end

    if ~exist(cfg.outDir, 'dir')
        mkdir(cfg.outDir);
    end

    % 2. Format File Names
    sizeTag = '';
    if cfg.targetSize == 2
        sizeTag = '_lg';
    end

    if isnumeric(cfg.subjectID)
        subjStr = num2str(cfg.subjectID);
    else
        subjStr = char(cfg.subjectID);
    end

    % Resolve paths inside user-selected raw directory
    lslFile     = fullfile(cfg.rawDir, sprintf('%s_%s%s.xdf', subjStr, cfg.condition, sizeTag));
    presLogFile = fullfile(cfg.rawDir, sprintf('%s_%s%s-%s.log', subjStr, cfg.condition, sizeTag, cfg.logSuffix));

    % Check raw file existence
    if ~isfile(lslFile)
        error('Raw LSL XDF file missing: %s', lslFile);
    end
    if ~isfile(presLogFile)
        error('Presentation log file missing: %s', presLogFile);
    end

    % 3. Extract & Process Eye Tracking Stream
    [tobiiData, ~] = load_TobiiPresentation(lslFile);
    
    % Screen coordinate conversions (normalized to cm offset)
    tobiiData.xMean_cm = (mean(tobiiData.time_series([24 26], :), 'omitnan') - 0.5) * cfg.eyeParams.screenWidthInCm;
    tobiiData.yMean_cm = (0.5 - mean(tobiiData.time_series([25 27], :), 'omitnan')) * cfg.eyeParams.screenHeightInCm;

    % 4. Save Output Data
    outFileName = sprintf('data_%s_%s%s_preprocessed.mat', subjStr, cfg.condition, sizeTag);
    savedFile   = fullfile(cfg.outDir, outFileName);

    save(savedFile, 'tobiiData', 'cfg');
end