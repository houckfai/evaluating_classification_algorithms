
% concatenate all analyzed BLN trials for methods project - predefined ROIs

algo = 'remo';

roiType = 'Predefined';

ui_group_str = 'G01';

location = 1;

if location == 1
    baseFilePath = ['C:\Users\Administrator\Documents\Local_Eyetracking_MNL\pilot\Tobii\et_analysis_pipeline\guiTest'];
    pilotPath = ['C:\Users\Administrator\Documents\Local_Eyetracking_MNL\pilot'];
elseif location == 2
    baseFilePath = ['Z:\Data\Eyetracking\pilot\Tobii'];
    pilotPath = ['Z:\Data\Eyetracking\pilot'];
end

% for condition level:
outFilePath = strcat(baseFilePath, '\post_step5\', ui_group_str);
% make sure a folder exists, if not, make one
% Ensure the output directory exists
if ~isfolder(outFilePath)
    mkdir(outFilePath);
end

outputFolder = '\post_step5\G01\';
outputFile = ([baseFilePath outputFolder 'group_data_bln_byCondition_predefined_rois_' algo '.mat']);




subject_list = [101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 114, 115, 116, 117, 118, 119, 120, 121];


% Get list of all participant files
inputFilePath = strcat(baseFilePath, '\post_step4\G01\', algo, '\');
%fileList = dir(fullfile(inputFilePath, 'data_*_bln_', algo, '.mat'));
fileList = dir(fullfile(inputFilePath, sprintf('data_*_bln_%s.mat', algo)));

fileNames = {fileList.name};
tokens = regexp(fileNames, 'data_(\d+)_', 'tokens');
% Convert extracted tokens to a numeric array
% Use cellfun to pull the string out of the nested cell and convert to double
fileIDs = cellfun(@(x) str2double(x{1}{1}), tokens);
% Create a logical mask: Keep if fileID is in your subject_list
keepMask = ismember(fileIDs, subject_list);
% overwrite fileList with only the valid participants
fileList = fileList(keepMask);

% faith's sanity checl
fprintf('Found %d total files. Keeping %d files based on subject_list.\n', ...
    length(keepMask), length(fileList));


allData = table(); % Initialize master table

%
for iFile = 1:length(fileList)
    % Load current participant
    filePath = fullfile(fileList(iFile).folder, fileList(iFile).name);
    dataLoad = load(filePath, 'predefinedData');

    % Extract Subject ID for this specific file again for the table column
    currentID_token = regexp(fileList(iFile).name, 'data_(\d+)_', 'tokens');
    currentID = str2double(currentID_token{1}{1});

    for c = 1:5
        condName = sprintf('c%d', c);
        res = dataLoad.predefinedData.ConditionLevel.(condName);
        
        newEntry = table();
        newEntry.ID = categorical(currentID);
        newEntry.Condition = categorical(c);

        newEntry.fixCountA = res.fixCountA;
        newEntry.tDwellA = res.tDwellA;
        newEntry.meanFixDurA = res.meanFixDurA;
        newEntry.mdc_A = res.mdcA;

        newEntry.fixCountB = res.fixCountB;
        newEntry.tDwellB = res.tDwellB;
        newEntry.meanFixDurB = res.meanFixDurB;
        newEntry.mdc_B = res.mdcB;
        
        newEntry.fixCountC = res.fixCountC;
        newEntry.tDwellC = res.tDwellC;
        newEntry.meanFixDurC = res.meanFixDurC;
        newEntry.mdc_C = res.mdcC;

        newEntry.pursCountA = res.pursCountA;
        newEntry.pursDurA = res.pursDurA;

        newEntry.pursCountB = res.pursCountB;
        newEntry.pursDurB = res.pursDurB;

        newEntry.pursCountC = res.pursCountC;
        newEntry.pursDurC = res.pursDurC;

        newEntry.roiTotalEngagement = res.roiTotalEngagement;


        newEntry.sparseSafetyCheck = res.sparseSafetyCheck;
        newEntry.matrixSum = res.matrixSum;

        if ~isempty(res.p_i)
            newEntry.p_i_A = res.p_i(1,1); % left roi probability
            newEntry.p_i_C = res.p_i(2,1); % center roi probability
            newEntry.p_i_B = res.p_i(3,1); % right roi probability 
        elseif isempty(res.p_i)
            newEntry.p_i_A = NaN;
            newEntry.p_i_C = NaN;
            newEntry.p_i_B = NaN;
        end

        if ~isempty(res.p_ij)
            % probabilty of coming from A to targets A, C, or B
            newEntry.p_ij_AA = res.p_ij(1,1); 
            newEntry.p_ij_AC = res.p_ij(1,2);
            newEntry.p_ij_AB = res.p_ij(1,3);
    
            % probability of coming from C to targets A, C, or B
            newEntry.p_ij_CA = res.p_ij(2,1);
            newEntry.p_ij_CC = res.p_ij(2,2);
            newEntry.p_ij_CB = res.p_ij(2,3);
    
            % probabilty of coming from B to targets A, C, or B
            newEntry.p_ij_BA = res.p_ij(3,1);
            newEntry.p_ij_BC = res.p_ij(3,2);
            newEntry.p_ij_BB = res.p_ij(3,3);

        elseif isempty(res.p_ij)
            newEntry.p_ij_AA = NaN; 
            newEntry.p_ij_AC = NaN;
            newEntry.p_ij_AB = NaN;
            newEntry.p_ij_CA = NaN;
            newEntry.p_ij_CC = NaN;
            newEntry.p_ij_CB = NaN;
            newEntry.p_ij_BA = NaN;
            newEntry.p_ij_BC = NaN;
            newEntry.p_ij_BB = NaN;
        end 

        newEntry.Hs = res.Hs;
        newEntry.Hs_rel = res.Hs_rel;
        newEntry.Ht = res.Ht;
        newEntry.Ht_rel = res.Ht_rel; 
      
        % Stack into master table
        allData = [allData; newEntry];

    end 

end

%

% Display check
disp('First 5 rows of the consolidated data:');
disp(head(allData(:, {'ID', 'Condition', 'Hs', 'matrixSum'})));

% save data
save(outputFile, "allData");
% prior: wrote statsPerSub
writetable(allData, [baseFilePath outputFolder 'group_data_bln_byCondition_predefined_rois_' algo '.xlsx']);
