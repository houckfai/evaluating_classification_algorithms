
% concatenate all analyzed BLN trials for methods project - KDE ROIs

algo = 'i2mc';

roiType = 'KDE';

location = 1;

if location == 1
    baseFilePath = ['C:\Users\Administrator\Documents\Local_Eyetracking_MNL\pilot\Tobii\et_analysis_pipeline\guiTest'];
    pilotPath = ['C:\Users\Administrator\Documents\Local_Eyetracking_MNL\pilot'];
elseif location == 2
    baseFilePath = ['Z:\Data\Eyetracking\pilot\Tobii'];
    pilotPath = ['Z:\Data\Eyetracking\pilot'];
end

% for condition level:
group = 'G01';
outFilePath = strcat(baseFilePath, '\post_step5\', group);
% make sure a folder exists, if not, make one
% Ensure the output directory exists
if ~isfolder(outFilePath)
    mkdir(outFilePath);
end

outputFolder = ['\post_step5\' group '\'];
outputFile = ([baseFilePath outputFolder 'group_data_bln_byCondition_kde_rois_' algo '.mat']);


subject_list = [101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 114, 115, 116, 117, 118, 119, 120, 121];


% load primary KDE data
load([baseFilePath '\post_step4\' group '\' algo '\kdePrimaryROIs.mat']);

% Get list of all participant files
inputFilePath = strcat(baseFilePath, '\post_step4\G01\', algo, '\');
fileList = dir(fullfile(inputFilePath, sprintf('data_*_bln_%s_kde.mat', algo)));

        
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
    dataLoad = load(filePath, 'kdeData');

    % Extract Subject ID for this specific file again for the table column
    currentID_token = regexp(fileList(iFile).name, 'data_(\d+)_', 'tokens');
    currentID = str2double(currentID_token{1}{1});
    
    if primaryKde.nROIs == 3

        for c = 1:5
            condName = sprintf('c%d', c);
            res = dataLoad.kdeData.ConditionLevel.(condName);
    
            newEntry = table();
            newEntry.ID = categorical(currentID);
            newEntry.Condition = categorical(c);
    
            newEntry.fixCountA = res.insideROICount(1);
            newEntry.tDwellA = res.roiDwell(1);
            %newEntry.meanFixDurA = res.meanFixDurA;
            newEntry.mdc_A = res.mdc(1);
    
            newEntry.fixCountB = res.insideROICount(3); % rois ordered spatially L to R
            newEntry.tDwellB = res.roiDwell(3);
            %newEntry.meanFixDurB = res.meanFixDurB;
            newEntry.mdc_B = res.mdc(3);
            
            newEntry.fixCountC = res.insideROICount(2);
            newEntry.tDwellC = res.roiDwell(2);
            %newEntry.meanFixDurC = res.meanFixDurC;
            newEntry.mdc_C = res.mdc(2);

            newEntry.pursCountA = res.pursCount(1);
            newEntry.pursDurA = res.roiPursDwell(1);

            newEntry.pursCountB = res.pursCount(3);
            newEntry.pursDurB = res.roiPursDwell(3);
    
            newEntry.pursCountC = res.pursCount(2);
            newEntry.pursDurC = res.roiPursDwell(2);
    
            newEntry.roiTotalEngagement = sum(res.roiTotalEngagement);
    
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
end

% Display check
disp('First 5 rows of the consolidated data:');
disp(head(allData(:, {'ID', 'Condition', 'Hs', 'matrixSum'})));

% save data

save(outputFile, "allData");
% prior: wrote statsPerSub
writetable(allData, [baseFilePath outputFolder 'group_data_bln_byCondition_kde_rois_' algo '.xlsx']);

% 
% %% quick visuals:
% % Filter out sparse data for a cleaner visualization
% %cleanData = allData(allData.sparseSafetyCheck == 0, :);
% cleanData = allData;
% 
% % changed this to include all data, since i noticed some algos give
% % warnings and others do not. I want to see differences by algo.
% 
% %% quick visualis - entropy comparison by condition
% 
% % is there a difference between my conditions?
% fig = figure;
% subplot(1,2,1);
% boxplot(cleanData.Hs_rel, cleanData.Condition);
% title('Spatial Diversity (Hs Relative)'); % low vals = 1 roi dominated; high vals = gaze distibuted among rois
% xlabel('Condition'); ylabel('Entropy (0-1)');
% 
% subplot(1,2,2);
% boxplot(cleanData.Ht_rel, cleanData.Condition);
% title('Transition Complexity (Ht Relative)'); % low vals = predictable sequence; high vals = unpredictable sequence
% xlabel('Condition'); ylabel('Entropy (0-1)');
% sgtitle([algo ' ' roiType]);
% 
% figFile = ['C:\Users\Administrator\Documents\Local_Eyetracking_MNL\pilot\Tobii\methods_post_step5\algoFigs\entropy_byCondition_' algo '_' roiType '.jpg'];
% saveas(fig, figFile);
% 
% %% quick visuals - roi bias
% 
% % Group by condition and calculate mean probabilities
% grpMean = groupsummary(allData, 'Condition', 'mean', {'p_i_A', 'p_i_C', 'p_i_B'});
% 
% fig = figure;
% bar(grpMean.Condition, [grpMean.mean_p_i_A, grpMean.mean_p_i_C, grpMean.mean_p_i_B], 'stacked');
% legend({'ROI A', 'ROI C', 'ROI B'});
% title([algo ' ' roiType ' Mean Gaze Distribution by Condition']); % shows preference of rois across conditions
% xlabel('Condition'); ylabel('Proportion of Dwell Time');
% 
% figFile = ['C:\Users\Administrator\Documents\Local_Eyetracking_MNL\pilot\Tobii\methods_post_step5\algoFigs\gaze_distribution_' algo '_' roiType '.jpg'];
% saveas(fig, figFile);
% 
% %% quick visual - entropy scatter
% 
% % plot Hs vs Ht to see how different people cluster.
% % do some people have high spatial diversity but predictable transitions?
% 
% % low Ht but high Hs = predictable transitions but gaze is distributed
% % high Ht & high Hs = unpredictable transitions & gaze is distrubted
% % low Ht & low Hs = predictable transitions & 1 roi dominates
% % high Ht & low Hs = unpredictable tranisitons & 1 roi dominates
% 
% colors = jet(5);
% 
% fig = figure;
% g = gscatter(cleanData.Hs_rel, cleanData.Ht_rel, cleanData.Condition, colors);
% set(g, 'MarkerSize', 30);
% set(g, 'LineWidth', 1.5);
% hold on;
% plot([0 1], [0 1], '--k'); % Diagonal line for reference
% ylim([0 1]);
% xlim([0 1]);
% xlabel('Stationary Entropy (Hs)');
% ylabel('Transition Entropy (Ht)');
% title([algo ' ' roiType ' Gaze Strategy by Condition']);
% 
% figFile = ['C:\Users\Administrator\Documents\Local_Eyetracking_MNL\pilot\Tobii\methods_post_step5\algoFigs\gaze_strategy_byCondition_' algo '_' roiType '.jpg'];
% saveas(fig, figFile);
% 
% %% quick visuals - transition heatmap
% 
% fig = figure;
% subplot(3, 2, 1); % Condition 1
% c1_data = allData(allData.Condition == '1', :);
% avg_matrix = [mean(c1_data.p_ij_AA, 'omitnan'), mean(c1_data.p_ij_AC, 'omitnan'), mean(c1_data.p_ij_AB, 'omitnan');
%               mean(c1_data.p_ij_CA, 'omitnan'), mean(c1_data.p_ij_CC, 'omitnan'), mean(c1_data.p_ij_CB, 'omitnan');
%               mean(c1_data.p_ij_BA, 'omitnan'), mean(c1_data.p_ij_BC, 'omitnan'), mean(c1_data.p_ij_BB, 'omitnan')];
% h = heatmap({'A','C','B'}, {'A','C','B'}, avg_matrix);
% h.Title = ['Average Transition Probabilities (Cond 1)'];
% h.XLabel = 'To ROI'; 
% h.YLabel = 'From ROI';
% h.Colormap = colormap(flipud(hot));
% h.ColorLimits = [0 1];
% h.FontSize = 12;
% 
% subplot(3, 2, 3); % Condition 2
% c2_data = allData(allData.Condition == '2', :);
% avg_matrix = [mean(c2_data.p_ij_AA, 'omitnan'), mean(c2_data.p_ij_AC, 'omitnan'), mean(c2_data.p_ij_AB, 'omitnan');
%               mean(c2_data.p_ij_CA, 'omitnan'), mean(c2_data.p_ij_CC, 'omitnan'), mean(c2_data.p_ij_CB, 'omitnan');
%               mean(c2_data.p_ij_BA, 'omitnan'), mean(c2_data.p_ij_BC, 'omitnan'), mean(c2_data.p_ij_BB, 'omitnan')];
% h = heatmap({'A','C','B'}, {'A','C','B'}, avg_matrix);
% h.Title = ['Average Transition Probabilities (Cond 2)'];
% h.XLabel = 'To ROI'; 
% h.YLabel = 'From ROI';
% h.Colormap = colormap(flipud(hot));
% h.ColorLimits = [0 1];
% h.FontSize = 12;
% 
% subplot(3, 2, 4); %condiiton 3
% c3_data = allData(allData.Condition == '3', :);
% avg_matrix = [mean(c3_data.p_ij_AA, 'omitnan'), mean(c3_data.p_ij_AC, 'omitnan'), mean(c3_data.p_ij_AB, 'omitnan');
%               mean(c3_data.p_ij_CA, 'omitnan'), mean(c3_data.p_ij_CC, 'omitnan'), mean(c3_data.p_ij_CB, 'omitnan');
%               mean(c3_data.p_ij_BA, 'omitnan'), mean(c3_data.p_ij_BC, 'omitnan'), mean(c3_data.p_ij_BB, 'omitnan')];
% h = heatmap({'A','C','B'}, {'A','C','B'}, avg_matrix);
% h.Title = ['Average Transition Probabilities (Cond 3)'];
% h.XLabel = 'To ROI'; 
% h.YLabel = 'From ROI';
% h.Colormap = colormap(flipud(hot));
% h.ColorLimits = [0 1];
% h.FontSize = 12;
% 
% subplot(3, 2, 5); % condition 4
% c4_data = allData(allData.Condition == '4', :);
% avg_matrix = [mean(c4_data.p_ij_AA, 'omitnan'), mean(c4_data.p_ij_AC, 'omitnan'), mean(c4_data.p_ij_AB, 'omitnan');
%               mean(c4_data.p_ij_CA, 'omitnan'), mean(c4_data.p_ij_CC, 'omitnan'), mean(c4_data.p_ij_CB, 'omitnan');
%               mean(c4_data.p_ij_BA, 'omitnan'), mean(c4_data.p_ij_BC, 'omitnan'), mean(c4_data.p_ij_BB, 'omitnan')];
% h = heatmap({'A','C','B'}, {'A','C','B'}, avg_matrix);
% h.Title = ['Average Transition Probabilities (Cond 4)'];
% h.XLabel = 'To ROI'; 
% h.YLabel = 'From ROI';
% h.Colormap = colormap(flipud(hot));
% h.ColorLimits = [0 1];
% h.FontSize = 12;
% 
% 
% subplot(3, 2, 6); % condition 5
% c5_data = allData(allData.Condition == '5', :);
% avg_matrix = [mean(c5_data.p_ij_AA, 'omitnan'), mean(c5_data.p_ij_AC, 'omitnan'), mean(c5_data.p_ij_AB, 'omitnan');
%               mean(c5_data.p_ij_CA, 'omitnan'), mean(c5_data.p_ij_CC, 'omitnan'), mean(c5_data.p_ij_CB, 'omitnan');
%               mean(c5_data.p_ij_BA, 'omitnan'), mean(c5_data.p_ij_BC, 'omitnan'), mean(c5_data.p_ij_BB, 'omitnan')];
% h = heatmap({'A','C','B'}, {'A','C','B'}, avg_matrix);
% h.Title = ['Average Transition Probabilities (Cond 5)'];
% h.XLabel = 'To ROI'; 
% h.YLabel = 'From ROI';
% h.Colormap = colormap(flipud(hot));
% h.ColorLimits = [0 1];
% h.FontSize = 12;
% 
% sgtitle([algo ' ' roiType]);
% 
% figFile = ['C:\Users\Administrator\Documents\Local_Eyetracking_MNL\pilot\Tobii\methods_post_step5\algoFigs\gaze_transition_heatmap_' algo '_' roiType '.jpg'];
% saveas(fig, figFile);
% 
% %% quick visual - mdc
% 
% fig = figure;
% % 1 row, 3 columns for ROIs A, B, and C
% tlo = tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'normal');
% title(tlo, [algo ' ' roiType ' Group Precision (MDC) Comparison Across ROIs']);
% 
% % Define the ROIs and their corresponding table columns
% roiSuffix = {'A', 'C', 'B'};
% roiNames = {'Target A (Left)', 'Target C (Center)', 'Target B (Right)'};
% 
% for r = 1:3
%     nexttile;
% 
%     % Dynamically get the column name (e.g., 'mdc_A')
%     colName = ['mdc_' roiSuffix{r}];
% 
%     % 1. Plot the raw distribution (Swarm)
%     % We use 'Condition' as the X-axis to see the shift across tasks
%     s = swarmchart(allData.Condition, allData.(colName), 15, 'filled');
%     s.MarkerFaceAlpha = 0.4;
%     s.MarkerEdgeAlpha = 0.4;
% 
%     hold on;
% 
%     % 2. Overlay the summary (Boxchart)
%     % Using 'none' for BoxFaceColor keeps it from hiding the points
%     b = boxchart(allData.Condition, allData.(colName), 'BoxFaceColor', 'none', 'LineWidth', 1.2);
%     b.BoxWidth = 0.5; % Make boxes slightly slimmer for readability
% 
%     % 3. Formatting
%     title(roiNames{r});
%     ylim([0, max(allData{:, {'mdc_A','mdc_C','mdc_B'}}, [], 'all', 'omitnan') * 1.1]);
%     grid on;
% 
%     if r == 1
%         ylabel('MDC (Degrees)');
%     end
%     xlabel('Condition');
% end
% 
% figFile = ['C:\Users\Administrator\Documents\Local_Eyetracking_MNL\pilot\Tobii\methods_post_step5\algoFigs\mdc_byCondition_' algo '_' roiType '.jpg'];
% saveas(fig, figFile);
% 
% %% quick visual - mdc mean for all rois
% % Calculate means for all 3 ROIs
% mdcMeans = groupsummary(allData, 'Condition', 'mean', {'mdc_A', 'mdc_C', 'mdc_B'});
% 
% fig = figure;
% b = bar(mdcMeans.Condition, [mdcMeans.mean_mdc_A, mdcMeans.mean_mdc_C, mdcMeans.mean_mdc_B]);
% legend({'ROI A', 'ROI C', 'ROI B'});
% ylabel('Mean MDC (Degrees)');
% xlabel('Condition');
% title([algo ' ' roiType ' Average Targeting Precision by ROI']);
% 
% figFile = ['C:\Users\Administrator\Documents\Local_Eyetracking_MNL\pilot\Tobii\methods_post_step5\algoFigs\mean_mdc_byCondition_' algo '_' roiType '.jpg'];
% saveas(fig, figFile);
% 
% %% quick visual - look at tdwell & mdc together
% 
% fig = figure;
% % 1. Create the scatter plot
% g = gscatter(allData.tDwellA, allData.mdc_A, allData.Condition, turbo(5), 'o', 8);
% 
% hold on;
% % 2. Add the regression lines
% l = lsline; 
% 
% % 3. Sync the colors
% % Note: lsline usually returns handles in the REVERSE order of gscatter
% % (The last group plotted is the first handle in 'l')
% l = flipud(l); 
% 
% for i = 1:numel(g)
%     % 1. Match the color and thickness
%     set(l(i), 'Color', g(i).Color, 'LineWidth', 2);
% 
%     % 2. Hide the regression line from the legend (The Fix)
%     l(i).Annotation.LegendInformation.IconDisplayStyle = 'off';
% end
% 
% xlabel('Total Dwell Time (ms)');
% ylabel('Mean Distance from Center (Deg)');
% title([algo ' ' roiType ' Efficiency: Does longer processing lead to better centering?']);
% 
% figFile = ['C:\Users\Administrator\Documents\Local_Eyetracking_MNL\pilot\Tobii\methods_post_step5\algoFigs\mdc_vs_tDwell_' algo '_' roiType '.jpg'];
% saveas(fig, figFile);
% 
% %% quick visual - tDwell & mdc but each tile = condition 
% fig = figure;
% % Create a 2x3 layout (5 conditions + 1 empty or legend space)
% tlo = tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
% title(tlo, [algo ' ' roiType ' Gaze Efficiency: MDC vs Dwell Time per Condition']);
% 
% % Get your 5-color gradient
% myColors = turbo(5);
% conds = categories(allData.Condition);
% 
% for c = 1:5
%     nexttile;
% 
%     % 1. Filter data for just this condition
%     thisCondData = allData(allData.Condition == conds{c}, :);
% 
%     % 2. Plot the raw points
%     % Note: Using 'scatter' here is easier for single-color tiles
%     s = scatter(thisCondData.tDwellA, thisCondData.mdc_A, 30, ...
%                 myColors(c,:), 'filled', 'MarkerFaceAlpha', 0.5);
% 
%     hold on;
% 
%     % 3. Add and Format the Regression Line
%     if size(thisCondData, 1) > 1 % Only plot if there's enough data
%         l = lsline; 
%         set(l, 'Color', myColors(c,:), 'LineWidth', 2.5);
%     end
% 
%     % 4. Formatting each tile
%     title(['Condition ', conds{c}]);
%     grid on;
% 
%     % Important: Keep the axes consistent across all tiles
%     xlim([0, max(allData.tDwellA, [], 'omitnan') * 1.1]);
%     ylim([0, max(allData.mdc_A, [], 'omitnan') * 1.1]);
% 
%     if c == 1 || c == 4 % Only label Y-axis on the left tiles
%         ylabel('MDC (Deg)');
%     end
%     if c >= 3 % Only label X-axis on the bottom tiles
%         xlabel('Dwell Time (ms)');
%     end
% end
% 
% figFile = ['C:\Users\Administrator\Documents\Local_Eyetracking_MNL\pilot\Tobii\methods_post_step5\algoFigs\mdc_vs_tDwell_tiles_' algo '_' roiType '.jpg'];
% saveas(fig, figFile)
% 
% %% quick visual - tdwell mean for all rois
% % Calculate means for all 3 ROIs
% tDwellMeans = groupsummary(allData, 'Condition', 'mean', {'tDwellA', 'tDwellC', 'tDwellB'});
% 
% fig = figure;
% b = bar(tDwellMeans.Condition, [tDwellMeans.mean_tDwellA, tDwellMeans.mean_tDwellC, tDwellMeans.mean_tDwellB]);
% legend({'ROI A', 'ROI C', 'ROI B'});
% ylabel('Mean tDwell (Seconds)');
% xlabel('Condition');
% title([algo ' ' roiType ' Average Dwell Time by ROI']);
% 
% figFile = ['C:\Users\Administrator\Documents\Local_Eyetracking_MNL\pilot\Tobii\methods_post_step5\algoFigs\mean_tDwell_byCondition_' algo '_' roiType '.jpg'];
% saveas(fig, figFile);
% 
