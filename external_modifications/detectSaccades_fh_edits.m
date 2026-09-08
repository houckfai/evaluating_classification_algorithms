function [ET] = detectSaccades(ET)

%************************************************************************
%************************************************************************
%************************************************************************

% This work is licensed under a Creative Commons Attribution-NonCommercial
% -ShareAlike 3.0 United States License" 
% https://creativecommons.org/licenses/by-nc-sa/3.0/us/
%
%************************************************************************
%************************************************************************
%************************************************************************

%
% Detects start and end by velocity criteria
%
%global ET
%global Verbose_TF

%Verbose_TF=true;
%if Verbose_TF,
fprintf('\n%s\n','***************** in detectSaccades') %,end
%
% V = Radial Velocity
% A = Radial Acceleration
%
V = ET.Vectors.vel;
A = ET.Vectors.acc;

%%
% Create logical vector (0,1) where 1 indicates that the velocity signal is above the saccade peak velocity threshold
%
ET.Vectors.Is_Vel_GT_SaccadePkVelThresh  = V > ET.Scalars.Params.PeakVelocityThreshold;
%
% Each continous run of samples above the saccade peak velocity
% threshold is a Potential Saccade.  bwlabel numbers these potential saccades from 1 to N, 
% where N is the last Potential Saccade.
%
PotentialSaccadeBlocks   = bwlabel(ET.Vectors.Is_Vel_GT_SaccadePkVelThresh);

% If no saccades are detected, return
if isempty(PotentialSaccadeBlocks);
    return
end

N_GoodSaccades = 1; %Counts potential saccades that pass all tests
%
% Process one potential Potential Saccade at a time
%
for ThisPotentialSaccade = 1:max(PotentialSaccadeBlocks)

    Saccade_Decision{ThisPotentialSaccade}='Unknown';
    %----------------------------------------------------------------------  
    % Check the saccade peak samples
    %----------------------------------------------------------------------       
    %
    % The samples related to the current saccade
    %
    IndicesOfThisSaccadeBlock = find(PotentialSaccadeBlocks == ThisPotentialSaccade);
    IndicesOfThisSaccadeBlock=IndicesOfThisSaccadeBlock';
    SaccadeBlockStartsAt=IndicesOfThisSaccadeBlock(1);
    SaccadeBlockEndsAt  =IndicesOfThisSaccadeBlock(end);
    %if Verbose_TF
        fprintf('\nWorking on Potential Saccade %d, Potential Good Saccade Number = %d, Start = %d, End = %d\n',ThisPotentialSaccade,N_GoodSaccades-1,SaccadeBlockStartsAt,SaccadeBlockEndsAt);
    %end

    if SaccadeBlockStartsAt > ET.Scalars.Data.Length
        fprintf('Saccade Starts Beyond the data: SaccadeBlockStartsAt > ET.Scalars.Data.Length\n');
        Saccade_Decision{ThisPotentialSaccade}='Reject_Saccade_Starts_After_Data';
        fprintf('For Potential Saccade %d, Final Descision = %s\n',ThisPotentialSaccade,Saccade_Decision{ThisPotentialSaccade});
        continue
    end
    %
    % Check if there are NaNs in this potential Potential Saccade. If so, reject saccade.
    %
    CountNaNsInThisSaccade=sum(ET.Vectors.NaNIndex(SaccadeBlockStartsAt:SaccadeBlockEndsAt));
    if CountNaNsInThisSaccade > 0;
       Saccade_Decision{ThisPotentialSaccade}='Reject_NaNs_In_Saccade_Block';
       fprintf('For Potential Saccade %d, Final Descision = %s\n',ThisPotentialSaccade,Saccade_Decision{ThisPotentialSaccade})
       continue;
    end 
    %
    % If the peak consists of =< minPeakSamples consecutive samples, it is probably
    % noise (1/6 of the min saccade duration). For 1000 Hz and a minimum saccade duration of 10 msec, minPeakSamples = 2.
    %
    minPeakSamples = ceil((ET.Scalars.Params.minSaccadeDur/6)*ET.Scalars.Params.samplingFreq);
    if length(IndicesOfThisSaccadeBlock) <= minPeakSamples;
       Saccade_Decision{ThisPotentialSaccade}='Reject_N_Samples_in_Saccade_Block_Too_Small';
       fprintf('For Potential Saccade %d, Final Descision = %s\n',ThisPotentialSaccade,Saccade_Decision{ThisPotentialSaccade});
       continue;
    end
    %
    % Check whether this peak is already included in the previous saccade
    % (can be like this for PSOs)
    %
    if N_GoodSaccades > 1
         if ~isempty(intersect(IndicesOfThisSaccadeBlock,find(ET.Vectors.SaccadeIndex)))
            Saccade_Decision{ThisPotentialSaccade}='Reject_Some_Part_of_This_Saccade_Block_Already_Classified_as_Saccade';
            fprintf('For Potential Saccade %d, Final Descision = %s\n',ThisPotentialSaccade,Saccade_Decision{ThisPotentialSaccade});
            continue
         end
         if ~isempty(intersect(IndicesOfThisSaccadeBlock,find(ET.Vectors.PSOIndex)))
            Saccade_Decision{ThisPotentialSaccade}='Reject_Some_Part_of_This_Saccade_Block_Already_Classified_as_PSO';
            fprintf('For Potential Saccade %d, Final Descision = %s\n',ThisPotentialSaccade,Saccade_Decision{ThisPotentialSaccade});
            continue
         end       
    end
    %----------------------------------------------------------------------
    % DETECT SACCADE
    %----------------------------------------------------------------------       
    %
    % Initialize some indexes
    %
    SaccadeCrossedBelowSaccadeSubthresholdAt=[];
    FinalSaccadeStartIndex=[];
    SaccadeLocalMinEndIndex=[];
    FinalSaccadeEndIndex=[];
    %
    % Detect saccade start.
    %
    % Does the velocity before a saccade cross below the saccade subthreshold?
    % If so, which sample? (m)
    %
    for m = SaccadeBlockStartsAt:-1:1
         if V(m) < ET.Scalars.Params.SaccadeSubthreshold;
            SaccadeCrossedBelowSaccadeSubthresholdAt = m;
            break;
        end;
    end;
    %
    % If velocity signal never crosses below saccade subthreshold, reject saccade
    %
    if isempty(SaccadeCrossedBelowSaccadeSubthresholdAt)
        Saccade_Decision{ThisPotentialSaccade}='Reject_Velocity_Before_Saccade_Block_Start_Never_Below_Saccade_Subthreshold';
        fprintf('For Potential Saccade %d, Final Descision = %s\n',ThisPotentialSaccade,Saccade_Decision{ThisPotentialSaccade});
        continue
    end
    %
    % Find Velocity Local Minimum between the point where the saccade
    % crossed below the saccade subthreshold and the beginng of the 
    % recording.
    %
    for m = SaccadeCrossedBelowSaccadeSubthresholdAt:-1:2
        if V(m-1) > V(m);
            %
            % Found a local velocity minimum at m
            %
            % Final saccade start index is 5 msec after local velocity minimum.
            %
            FinalSaccadeStartIndex = m; %m+4; % FH removed '+4' on 10.28.2025. For 120 Hz, this is 0.033s. ------------------------------------------------------------------------------------------------
            break;
        end
    end
    %
    % If can't find a Local Velocity Minimum then reject.
    %
    if isempty(FinalSaccadeStartIndex)
        Saccade_Decision{ThisPotentialSaccade}='Reject_Could_Not_Find_Velocity_Local_Minimum_Before_Saccade_Block';
        fprintf('For Potential Saccade %d, Final Descision = %s\n',ThisPotentialSaccade,Saccade_Decision{ThisPotentialSaccade});
        continue
    end
    %
    % Detect end of saccade
    %
    % Starting from where the Potential Saccade ends, find a point
    % between this point and the end of the recording where the 
    % velocity signal drops below the saccade subthreshold
    %
    SaccadeCrossedBelowSaccadeSubthresholdAt=[];
    for m = SaccadeBlockEndsAt:1:ET.Scalars.Data.Length
         if V(m) < ET.Scalars.Params.SaccadeSubthreshold
            SaccadeCrossedBelowSaccadeSubthresholdAt = m;
            break;
         end
    end
    if isempty(SaccadeCrossedBelowSaccadeSubthresholdAt)
       Saccade_Decision{ThisPotentialSaccade}='Reject_Velocity_After_Saccade_Block_Never_Crosses_Below_Saccade_Subthreshold';
       fprintf('For Potential Saccade %d, Final Descision = %s\n',ThisPotentialSaccade,Saccade_Decision{ThisPotentialSaccade});
       continue
    end
    for m = SaccadeCrossedBelowSaccadeSubthresholdAt:1:ET.Scalars.Data.Length-1;
        if V(m) < V(m+1)
            SaccadeLocalMinEndIndex = m;
            break;
        end
    end
    if isempty(SaccadeLocalMinEndIndex)
       Saccade_Decision{ThisPotentialSaccade}='Reject_Could_Not_Find_Velocity_Local_Minimum_After_Saccade_Block';
       fprintf('For Potential Saccade %d, Final Descision = %s\n',ThisPotentialSaccade,Saccade_Decision{ThisPotentialSaccade});
       continue
    end
    %
    % Before call to detectPSO, declare these samples as a saccade temporarily
    %
    ET.Vectors.SaccadeIndex(FinalSaccadeStartIndex:SaccadeLocalMinEndIndex)=true;
    %
    % Begin searching for a PSO at SaccadeLocalMinEndIndex 
    %    
    [ET, IsPSO,Reject,PSOStartIndex,PSOEndIndex]=detectPSO(FinalSaccadeStartIndex,SaccadeLocalMinEndIndex,N_GoodSaccades, ET);
    %
    % After call to detectPSO, reverse coding these samples as a saccade
    % Will reset later, after all conditions met.
    %
    ET.Vectors.SaccadeIndex(FinalSaccadeStartIndex:SaccadeLocalMinEndIndex)=false;
    %
    % No PSO and No Need to Reject - A saccade without a PSO
    %
    if ~IsPSO && Reject
       %
       % In this case, the saccade end is 3 samples before the local velocity minimum
       %
       FinalSaccadeEndIndex=SaccadeLocalMinEndIndex; % FH removed 'FinalSaccadeEndIndex=SaccadeLocalMinEndIndex-3' on 11.5.2025: 3 samples for 1,000 Hz = 0.003s. For 120 Hz, this is 0.025s. ---------------------------------------------------
    else
        %
        % A saccade with a PSO ends at the SaccadeLocalMinEndIndex
        %
       FinalSaccadeEndIndex=SaccadeLocalMinEndIndex;
    end;
    %
    % Check if the saccade end index exists
    %
    if isempty(FinalSaccadeEndIndex)
        Saccade_Decision{ThisPotentialSaccade}='Reject_Could_Not_Determine_The_End_Of_This_Saccade';
        %
        % If PSO was found, now it must be unfound
        %
        if IsPSO
            [ET] = unFindPSO(PSOStartIndex,PSOEndIndex,ThisPotentialSaccade,N_GoodSaccades,ET); end;
        continue
    end
    %
    % Check if there are NaNs in this saccade
    %
    CountNaNsInThisSaccade=sum(ET.Vectors.NaNIndex(FinalSaccadeStartIndex:FinalSaccadeEndIndex));
    if CountNaNsInThisSaccade > 0;
        Saccade_Decision{ThisPotentialSaccade}='Reject_There_Are_NaNs_In_This_Saccade';
        %
        % If PSO was found, now it must be unfound
        %
        if IsPSO,
            [ET] = unFindPSO(PSOStartIndex,PSOEndIndex,ThisPotentialSaccade,N_GoodSaccades,ET); end;
        continue
    end
    %
    % Make sure the saccade duration exceeds the minimum duration.
    %
    saccadeLen = FinalSaccadeEndIndex - FinalSaccadeStartIndex+1;
    if saccadeLen/ET.Scalars.Params.samplingFreq < ET.Scalars.Params.minSaccadeDur;
        Saccade_Decision{ThisPotentialSaccade}='Reject_Saccade_Duration_Too_Short';
        %if Verbose_TF, 
            fprintf('For Potential Saccade %d, Final Descision = %s\n',ThisPotentialSaccade,Saccade_Decision{ThisPotentialSaccade});%end
        %
        % If PSO was found, now it must be unfound
        %
        if IsPSO
            [ET] = unFindPSO(PSOStartIndex,PSOEndIndex,ThisPotentialSaccade,N_GoodSaccades, ET); end;
        continue
    end
   
    % 
    % If all the above criteria are fulfilled, label it as a saccade.
    %
    Saccade_Decision{ThisPotentialSaccade}='Accept';
    %if Verbose_TF, 
        fprintf('For Potential Saccade %d, Final Descision = %s\n',ThisPotentialSaccade,Saccade_Decision{ThisPotentialSaccade});%end
    ET.Vectors.SaccadeIndex(FinalSaccadeStartIndex:FinalSaccadeEndIndex)=true;
    % 
    % Compute Saccade Measures
    %
    ET.Scalars.Data.SaccadeInfo(N_GoodSaccades).start = FinalSaccadeStartIndex/[ET.Scalars.Params.samplingFreq]; % in seconds  
    ET.Scalars.Data.SaccadeInfo(N_GoodSaccades).end   = FinalSaccadeEndIndex/[ET.Scalars.Params.samplingFreq]; % in seconds
    Xamp=ET.Vectors.Xsmo(FinalSaccadeEndIndex)-ET.Vectors.Xsmo(FinalSaccadeStartIndex);
    Yamp=ET.Vectors.Ysmo(FinalSaccadeEndIndex)-ET.Vectors.Ysmo(FinalSaccadeStartIndex);
    ET.Scalars.Data.SaccadeInfo(N_GoodSaccades).amplitude = sqrt(Xamp^2 + Yamp^2);
    ET.Scalars.Data.SaccadeInfo(N_GoodSaccades).peakVelocity = max(V(FinalSaccadeStartIndex:FinalSaccadeEndIndex)); 
    ET.Scalars.Data.SaccadeInfo(N_GoodSaccades).peakAcceleration = max(A(FinalSaccadeStartIndex:FinalSaccadeEndIndex)); 
    ET.Scalars.Data.SaccadeInfo(N_GoodSaccades).duration =ET.Scalars.Data.SaccadeInfo(N_GoodSaccades).end -ET.Scalars.Data.SaccadeInfo(N_GoodSaccades).start;

    N_GoodSaccades=N_GoodSaccades+1;
  
end
%
%Load N_PSOs in ET.Scalars.Data
%
ET.Scalars.Data.N_PSOs = length(ET.Scalars.Data.PSOInfo);
%
% Check Last PSO
%
qq=ET.Scalars.Data.N_PSOs;
%
% If last PSO is rejected, set its data descriptors to null []
%
if strcmp(Saccade_Decision{max(PotentialSaccadeBlocks)},'_Reject')
    [ET]= unFindPSO(PSOStartIndex,PSOEndIndex,ThisPotentialSaccade,N_GoodSaccades,ET);
end;

ET.Scalars.Data.N_PSOs = length(ET.Scalars.Data.PSOInfo);
ET.Scalars.Data.N_Saccades = length(ET.Scalars.Data.SaccadeInfo);

return

function [ET] = unFindPSO(PSOStartIndex,PSOEndIndex,ThisPotentialSaccade,N_GoodSaccades, ET)
    %global ET
    ET.Vectors.PSOIndex(PSOStartIndex:PSOEndIndex)=false;
    ET.Scalars.Data.PSOInfo(N_GoodSaccades).PSO_Type = [];
    ET.Scalars.Data.PSOInfo(N_GoodSaccades).start = [];  
    ET.Scalars.Data.PSOInfo(N_GoodSaccades).end   = [];
    ET.Scalars.Data.PSOInfo(N_GoodSaccades).peakVelocity = []; 
    ET.Scalars.Data.PSOInfo(N_GoodSaccades).peakAcceleration = []; 
    ET.Scalars.Data.PSOInfo(N_GoodSaccades).duration = [];
    %if Verbose_TF, 
        fprintf('Unfinding PSO for Potential Saccade %d, Potential Good Saccade Number = %d\n',ThisPotentialSaccade,N_GoodSaccades); %end
return

