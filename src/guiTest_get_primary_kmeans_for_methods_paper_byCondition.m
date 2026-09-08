% determines optimal k-value & k-means derived ROIs for all participants


subject_list = [101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 114, 115, 116, 117, 118, 119, 120, 121];
%subjectID = 101;

location = 1;

if location == 1
    baseFilePath = ['C:\Users\Administrator\Documents\Local_Eyetracking_MNL\pilot\Tobii\et_analysis_pipeline\guiTest'];
    pilotPath = ['C:\Users\Administrator\Documents\Local_Eyetracking_MNL\pilot'];
elseif location == 2
    baseFilePath = ['Z:\Data\Eyetracking\pilot\Tobii'];
    pilotPath = ['Z:\Data\Eyetracking\pilot'];
end

run eye_params.m

group = 'G01';
condition = 'bln';
algo = 'remo';


outputFile = [baseFilePath '\post_step4\' group '\' algo '\kMeansPrimaryROIs.mat'];


numConditions = 5;

%% 1. Pool all the fixation data across participants & conditions
pooledFix = [];

for iSubject = 1:length(subject_list)
    subjectID = subject_list(iSubject);

    disp(['Working on subject: ' num2str(subjectID)]);
    
    % load participant's event matrix:
    load([baseFilePath '\post_step4\' group '\' algo '\data_' num2str(subjectID) '_' condition '_' algo '.mat']);


    % get fixation matrix per condition
    for c = 1:numConditions
        condName = sprintf('c%d', c);
        fixRows = predefinedData.ConditionLevel.(condName).eventMatrix(:, 2) == 1;
        pooledFix = [pooledFix; predefinedData.ConditionLevel.(condName).eventMatrix(fixRows, :)];
    end 
end

%% 2. Optimization
% I need to mathematically justify why I chose a specific number of
% clusters (k). I can use the Silhouette Score to measure how well
% separated the clusters are.

% Silhouette score ranges from -1 to 1
% high value means fixation is well-matched to its own clusters and poorly
% matched to the neighboring clusters. 

X = pooledFix(:, 3:4); % Extract X and Y coordinates
maxK = 10; % Maximum number of ROIs to test
eva = zeros(maxK, 1); 

fprintf('Optimizing k... please wait.\n');

for k = 2:maxK
    % Run kmeans with multiple replicates to ensure stability
    [idx, ~] = kmeans(X, k, 'Replicates', 5, 'MaxIter', 1000);
    
    % Calculate silhouette scores
    s = silhouette(X, idx);
    eva(k) = mean(s);
    
    fprintf('Tested k=%d: Silhouette Score = %.3f\n', k, eva(k));
end

% Find the k that produced the highest score
[~, optimalK] = max(eva);

% Visualize the optimization
figure;
plot(1:maxK, eva, '-o', 'LineWidth', 2);
xlabel('Number of Clusters (k)');
ylabel('Mean Silhouette Value');
title(['Optimization for k-Means Cluster-Derived ROIs for ' algo]);

%% Use optimal k to run final k-means

% Run final k-means with the optimized k
[idx, primaryCentroids] = kmeans(X, optimalK, 'Replicates', 10);

% sort primaryCentroids left to right by the x coord (1st col)
[sortedX, sortedIdx] = sort(primaryCentroids(:, 1));
primaryCentroids = primaryCentroids(sortedIdx, :);

newIdx = zeros(size(idx));
for k = 1:optimalK
    newIdx(idx == sortedIdx(k)) = k;
end 

idx = newIdx;

% sanity check:
fprintf('Sorted Centroid Coordinates (Left to Right):\n');
for k = 1:optimalK
    fprintf('ROI %d: X = %.2f, Y = %.2f\n', k, primaryCentroids(k,1), primaryCentroids(k,2));
end

%% Define the spatial boundaries for the ROIs

% voronoi tessellation 
% this method partitions the entire screen so that every coordinate can 
% belong to an ROI

% get roi boundaries
[vx, vy] = voronoi(primaryCentroids(:,1), primaryCentroids(:,2));


%% Define Screen Boundaries (centered at 0,0)

screenX = [-EyeParams.screenWidthInCm/2, EyeParams.screenWidthInCm/2];
screenY = [-EyeParams.screenHeightInCm/2, EyeParams.screenHeightInCm/2];
% rectangle('Position', [screenX(1), screenY(1), EyeParams.screenWidthInCm, EyeParams.screenHeightInCm], ...
%     'EdgeColor', [0.5 0.5 0.5], 'LineStyle', '--', 'LineWidth', 1.5);
targets = [EyeParams.targetA_bln;  EyeParams.targetC_bln; EyeParams.targetB_bln;];
names = {'Target A', 'Fix Cross', 'Target B'};
colors = [1 0 0; 0 0.8 0; 0 0 1]; % Red, Blue, Green

figure();

plot(vx, vy, 'k-', 'LineWidth', 2); % This shows the edges of ROIs
hold on;
plot(primaryCentroids(:,1), primaryCentroids(:,2), 'ko', 'MarkerSize', 15);

% add targets & fixation cross
alphaVal = 0.5; % Define transparency level

% Offset for text (adjust based on your cm scale, e.g., 0.5 cm to the right)
xOffset = 0.8; 
yOffset = 0.5;

% label the Primary Centroids (Data-Driven)
for k = 1:size(primaryCentroids, 1)
    text(primaryCentroids(k,1) + xOffset, primaryCentroids(k,2) + yOffset, ...
        sprintf('Centroid %d', k), 'FontSize', 10, 'FontWeight', 'bold', 'Color', 'k');
end

% label the Targets/Cross (Ground Truth)
for i = 1:3
    % Scatter plot already exists in your loop...
    scatter(targets(i).X_cm, targets(i).Y_cm, 100, colors(i,:), 'filled', ...
        'MarkerFaceAlpha', alphaVal, 'MarkerEdgeColor', 'k');
    
    % Add the specific target name
    text(targets(i).X_cm + xOffset, targets(i).Y_cm - yOffset, ...
        names{i}, 'FontSize', 10, 'Color', colors(i,:), 'FontAngle', 'italic');
end

% Create dummy plots for the legend to avoid repeating "Target" 3 times

%hCentroid = plot(nan, nan, 'ko', 'MarkerSize', 10, 'LineWidth', 2);
%hTarget = scatter(nan, nan, 100, [0.5 0.5 0.5], 'filled', 'MarkerFaceAlpha', 0.5);

hold off

%legend([hCentroid, hTarget], {'Data-Driven Centroid', 'Ground Truth Target'}, ...
  %  'Location', 'northeastoutside');

title(['Voronoi ROIs for ' algo]);
axis equal;
xlabel('Horizontal (cm)'); ylabel('Vertical (cm)');
% Set axis limits to match the screen size
xlim([screenX(1)-2, screenX(2)+2]);
ylim([screenY(1)-2, screenY(2)+2]);

%%
% 1. Extract target coordinates into a matrix
targetCoords = [[targets.X_cm]', [targets.Y_cm]'];

% 2. Initialize a results table
distResults = table('Size', [3 3], ...
    'VariableTypes', {'string', 'double', 'double'}, ...
    'VariableNames', {'TargetName', 'CentroidID', 'Distance_cm'});

for i = 1:3
    % Calculate distance from this target to all centroids
    % Formula: sqrt((x1-x2)^2 + (y1-y2)^2)
    diffs = primaryCentroids - targetCoords(i,:);
    allDistances = sqrt(sum(diffs.^2, 2));
    
    % Find the closest centroid
    [minDist, closestIdx] = min(allDistances);
    
    % Store results
    distResults.TargetName(i) = names{i};
    distResults.CentroidID(i) = closestIdx;
    distResults.Distance_cm(i) = minDist;
end

% Display the results in the Command Window
disp('--- ROI Validation: Distance Error ---');
disp(distResults);

% Calculate Mean Error
fprintf('Mean Spatial Error: %.3f cm\n', mean(distResults.Distance_cm));

% check in degrees of visual angle
viewDist = 60; % Distance to screen in cm
errorDeg = 2 * atand(distResults.Distance_cm / (2 * viewDist));
disp('Error in Degrees:');
disp(errorDeg);

%% Save data!
save(outputFile, 'primaryCentroids', 'optimalK', 'vx', 'vy', 'distResults', 'errorDeg');

