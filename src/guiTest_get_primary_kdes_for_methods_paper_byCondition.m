
% determine kde-derived ROIs to use for all participants

%%
clear

subject_list = [101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 114, 115, 116, 117, 118, 119, 120, 121];

%subjectID = 121;
showFigs = 1; % 1 = see graphs; 0 = don't see graphs
algo = 'remo'; 

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
numConditions = 5;

outputFile = [baseFilePath '\post_step4\' group '\' algo '\kdePrimaryROIs.mat'];




%% set kde params:

roiThreshold = 0.80; % increasing this lowers density threshold/includes more regions

% Define the grid for evaluation - based on cm of the monitor's screen 
%fov_width = 2.1;
x_min = -23.85;
x_max = 23.85;
y_min = -13.4;
y_max = 13.4;

% compute bandwidth
viewDist = 60;  % distance from screen in cm
sigma_deg = 1; % 1-degree visual angle gaussian kernel
sigma_cm = 2 * viewDist * tand(sigma_deg/2); % comes out to 1.0472 
% a fixation cluster will have an area proportional to the gaussian kernel

% compute grid spacing relative to bandwidth (not derived from area!)
dx = sigma_cm / 4;
dy = dx;

% construct grid
x_grid = x_min:dx:x_max;
y_grid = y_min:dy:y_max;

[X, Y] = meshgrid(x_grid, y_grid); % comes out to 103 x 183
positions = [X(:), Y(:)];

epsilon = 1e-10; % Small value to avoid log(0)
area_per_point = dx * dy; % Area represented by each grid point

circle_radius = 1;
target_radius = 2;
homeA_center = [-8.5, 0];
homeB_center = [8.5, 0];
% target coordinates for bln conditions:
targetA_center = [-8.5, 7.5];
targetB_center = [8.5, 7.5];


%% 1. Pool all the fixation data across participants & conditions
pooledFix = [];

for iSubject = 1:length(subject_list)
    subjectID = subject_list(iSubject);

    disp(['Working on subject: ' num2str(subjectID)]);
    
    % load participant's event matrix
    load([baseFilePath '\post_step4\' group '\' algo '\data_' num2str(subjectID) '_' condition '_' algo '.mat']);


    % get fixation matrix per condition
    for c = 1:numConditions
        condName = sprintf('c%d', c);
        fixRows = predefinedData.ConditionLevel.(condName).eventMatrix(:, 2) == 1;
        pooledFix = [pooledFix; predefinedData.ConditionLevel.(condName).eventMatrix(fixRows, :)];
    end 
end

%% KDE from Pooled data

% check for NaNs & 0s before KDE
validIdx = ~any(isnan(pooledFix(:, [3, 4, 5])), 2) & (pooledFix(:, 5) > 0);
cleanFix = pooledFix(validIdx, :);

f = ksdensity([cleanFix(:, 3), cleanFix(:, 4)], positions, ...
    'Bandwidth', sigma_cm, ...
    'Weights', cleanFix(:, 5));

% since i want to look dwell time and I created f by weighting duration,
% the non-normalized outputs represents the accumulated duration at each
% spatial point
% this represents the actual dwell time density
% when I derive ROIs, my threshold value is defined as a raw duration
% density

% normalizing this gives me a probability density function, which
% represents the probability of a person looking at one ROI vs another
% my threshold value represents % of scaled mass
% this accounts for differences in total trial length between people
% when I derive my ROIs, I know my total mass is 1, so my threshold truly 
% captures the top threshold% of mass (instead of duration)

% used scaled f for deriving rois:
f_norm = f / sum(f(:));
kde = reshape(f_norm, size(X)); % reshape to screen


figure();
imagesc(x_grid, y_grid, kde);
set(gca, 'YDir', 'normal'); % Correct y-axis direction
colormap('jet');
colorbar;
xlabel('X');
ylabel('Y');
title(['Primary KDE for ' algo]);

%% derive primary ROIs:

% get threshold
sorted_vals = sort(kde(:),'descend'); % sort descend first, if not threshold will give lowest density values first
cum_mass = cumsum(sorted_vals);

% find threshold value that cuts off the top x% of mass
idx = find(cum_mass >= roiThreshold, 1);
if isempty(idx)
    error('Couldnt find threshold! Check if kde sum = 1!');
end

threshold = sorted_vals(idx);
roi_mask = kde >= threshold;

% get connected components & number of rois identified
% -- https://www.mathworks.com/help/images/ref/bwconncomp.html
CC = bwconncomp(roi_mask);

% -- https://www.mathworks.com/help/images/ref/regionprops.html
stats = regionprops(CC,'Area','Centroid');
% only keep ROIs > 0.5 cm2
minAreaCm2 = 0.5; 
singleGridArea = dx * dy; % Area of a single grid cell in cm^2
minArea = minAreaCm2 / singleGridArea;

% 3. Find which ROIs meet the size requirement
keepIdx = [stats.Area] >= minArea;

% 4. Filter the Connected Components structure
% We remove the pixel lists for ROIs that are too small
CC.PixelIdxList = CC.PixelIdxList(keepIdx);
CC.NumObjects = sum(keepIdx);

stats = regionprops(CC, 'Area', 'Centroid'); % Re-calculate stats for clean indexing
labeled = labelmatrix(CC);
nROIs = CC.NumObjects;

fprintf('nROIs (after filtering < %.2f cm2): %d\n', ...
    minAreaCm2, nROIs);

if showFigs == 1

    % Plot 1: KDE + ROI Outlines + Fixations
    maxVal = max(kde(:));
    % threshold small values for visualization 
    thresh = 0.01 * maxVal;
    alphaMask = kde ./ maxVal;
    alphaMask(kde < thresh) = 0;
    alphaMask = imgaussfilt(alphaMask, 1.5);

    figure();
    imagesc(x_grid, y_grid, kde, 'AlphaData', alphaMask); hold on;
    set(gca, 'YDir', 'normal');
    colormap(gca, 'jet');
    colorbar;
    title(['# of KDE-Derived ROIs: ', num2str(nROIs)]);
end

%% sort ROIs spatially from left to right
% convert centroids from grid points to cm
centroids_cm = NaN(nROIs, 2);
for r = 1:nROIs
    % Centroid(1) is X (horizontal/column), Centroid(2) is Y (vertical/row)
    cx_pix = stats(r).Centroid(1);
    cy_pix = stats(r).Centroid(2);
    
    % Map back to cm using your grid definitions
    cx = interp1(1:length(x_grid), x_grid, cx_pix);
    cy = interp1(1:length(y_grid), y_grid, cy_pix);
    centroids_cm(r, :) = [cx, cy];
end

% sort rois spatially 
if nROIs > 1
    % 'order' tells us which OLD index goes into which NEW position
    % e.g., if order is [3, 1, 2], the old ROI 3 is now the new ROI 1
    [~, order] = sort(centroids_cm(:, 1)); 
    
    % Update the labeled matrix
    tempLabeled = labeled;
    newLabeled = zeros(size(tempLabeled));
    for i = 1:length(order)
        % Map old ROI ID (order(i)) to new ROI ID (i)
        newLabeled(tempLabeled == order(i)) = i;
    end
    % Update all associated metadata to match the new order!
    labeled = newLabeled;
    centroids_cm = centroids_cm(order, :); % Reorder the CM list
    stats = stats(order);       % Reorder the stats struct
else
    centroids_cm = centroids_cm;
end

% sanity check graph
figure;
imagesc(x_grid, y_grid, labeled);
hold on;
for r = 1:nROIs
    text(centroids_cm(r,1), centroids_cm(r,2), ...
        num2str(r), 'FontSize', 20, 'Color', 'white', 'HorizontalAlignment', 'center');
end
set(gca, 'YDir', 'normal');
title([algo 'Sorted ROI Labels (Left to Right)']);

%% save primary ROIs
primaryKde = struct();
primaryKde.dx = dx;
primaryKde.dy = dy;
primaryKde.x_grid = x_grid;
primaryKde.y_grid = y_grid;
primaryKde.roiThreshold = roiThreshold;
primaryKde.kde = kde;
primaryKde.nROIs = nROIs;
primaryKde.roi_mask = labeled > 0;
primaryKde.CC = CC;
primaryKde.stats = stats;
primaryKde.labeled = labeled;
primaryKde.centroids_cm = centroids_cm;

save(outputFile, 'primaryKde');
 

