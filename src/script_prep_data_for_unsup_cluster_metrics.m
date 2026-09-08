clear

%% filter I2MC coordinates & save as 'eyeData' before analyzing w/ cluster metrics
clear

subjectID = 101;

load(['C:\Users\Administrator\Documents\Local_Eyetracking_MNL\pilot\Tobii\et_analysis_pipeline\guiTest\post_step2\G01\i2mc_results\data_', num2str(subjectID), '_bln_i2mc_converted.mat']);

[b,g] = sgolay(2,5);   % Calculate S-G coefficients
delay = (5 - 1) / 2; % 2 samples
Xsmo = filter(g(:,1),1,sampledData(:,3));
Xsmo = [Xsmo(delay+1:end); NaN(delay,1)]; % Shift to align
Ysmo = filter(g(:,1),1,sampledData(:,3));
Ysmo = [Ysmo(delay+1:end); NaN(delay,1)]; % Shift to align
i2mcLen = length(sampledData(:,1));
%tmp_data.sampledData(:, 3:4) = [Xsmo(1:i2mcLen), Ysmo(1:i2mcLen)];

eyeData = [sampledData(:,1:2),Xsmo, Ysmo];

save(['C:\Users\Administrator\Documents\Local_Eyetracking_MNL\pilot\Tobii\et_analysis_pipeline\guiTest\post_step2\G01\i2mc_results\data_', num2str(subjectID), '_bln_i2mc_converted.mat'], ...
    "eyeData", "sampledData");

%% load mnh & save as 'eyeData'

clear

subject_list = [101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 114, 115, 116, 117, 118, 119, 120, 121];

for i = 1:length(subject_list)
    subjectID = subject_list(i);

    load(['C:\Users\Administrator\Documents\Local_Eyetracking_MNL\pilot\Tobii\et_analysis_pipeline\guiTest\post_step2\G01\mnh_results\data_', num2str(subjectID), '_bln_mnh_converted.mat']);
    eyeData = sampledData;

    save(['C:\Users\Administrator\Documents\Local_Eyetracking_MNL\pilot\Tobii\et_analysis_pipeline\guiTest\post_step2\G01\mnh_results\data_', num2str(subjectID), '_bln_mnh_converted.mat'], ...
    "eyeData", "sampledData");
end 

%% load REMoDNaV & save as 'eyeData'

clear

subject_list = [101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 114, 115, 116, 117, 118, 119, 120, 121];

for i = 1:length(subject_list)
    subjectID = subject_list(i);
    load(['C:\Users\Administrator\Documents\Local_Eyetracking_MNL\pilot\Tobii\et_analysis_pipeline\guiTest\post_step2\G01\remo_results\data_', num2str(subjectID), '_bln_remo_converted.mat']);
    eyeData = sampledData;
    save(['C:\Users\Administrator\Documents\Local_Eyetracking_MNL\pilot\Tobii\et_analysis_pipeline\guiTest\post_step2\G01\remo_results\data_', num2str(subjectID), '_bln_remo_converted.mat'], ...
    "eyeData", "sampledData");
end 