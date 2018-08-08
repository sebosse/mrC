function [EEGData,EEGAxx,sourceDataOrigin,masterList,subIDs] = SimulateProject(projectPath,varargin)
    
    % Syntax: [EEGData,EEGAxx,sourceDataOrigin,masterList,subIDs] = SimulateProject(projectPath,varargin)
    % Description:	This function gets the path for a mrc project and simulate
    % EEG with activity (seed signal as input) in specific ROIs (input),
    % and pink and alpha noises (noise parameters can be set as input)
    %
    % Syntax:	[EEGData,EEGAxx,sourceDataOrigin,masterList,subIDs] = mrC.RoiDemo(projectPath,varargin)
    % 
%--------------------------------------------------------------------------    
% INPUT:
  % projectPath: a cell string, indicating a  path to mrCurrent project
  % folder with individual subjects in subfolders
    %             
    % 
    %
  %   <options>:
    %
  % (Source Signal Parameters)
    %       signalArray:    a NS x seedNum matrix, where NS is the number of
    %                       time samples and seedNum is the number of seed sources
    %                       [NS x 2 SSVEP sources] -> for these two, the
    %                       random ROIs in functional
    %                       roitype is selected
    %
    %       signalsf:       sampling frequency of the input source signal
    %
    %       signalType:     type of simulated signal (visualization might differ for different signals)
    %                       
    %       
    %       signalFF:       a seedNum x 1 vector: determines the fundamental
    %                       frequencis of sources
    %       nTrials:        Number of trials. Noise is redrawn for each trial.
  
  % (ROI Parameters)
    %       rois            a cell array of roi structure that can be
    %                       extracted from mrC.Simulate.GetRoiList for any
    %                       atlas. The roi structure contain .Type field
    %                       which is the type of atlas used:
    %                       (['func']/'wang'/'glass','kgs','benson')
    %                       the other field is .Name which should be the
    %                       name of ROI and .Hemi which indicates the
    %                       hemisphere, and can be 'L' or 'R' or 'B' for
    %                       both hemisphere.
    %                       Note that the cell array can contain ROIs from
    %                       different atlases
    %                       
    %       roiType:        THIS IS NOT NEEDED IF YOU GIVE THE rois INPUT.  
    %                       string specifying the roitype to use. 
    %                       'main' indicates that the main ROI folder
    %                       /Volumes/svndl/anatomy/SUBJ/standard/meshes/ROIs
    %                       is to be used. (['func']/'wang'/'glass','kgs','benson').
    %
    %
    %       roiSpatfunc     a string indicating which spatial function
    %                       will be used to put the seed signal in ROI
    %                       [uniform]/gaussian
    %       roiSize         number of vertices in each ROI
    %
    %       anatomyPath:  The folder should be for the same subject as
    %                       projectPath points to. It should have ROI forders, default
    %                       cortex file, ..
    
  % (Noise Parameters), all this parameters are defined inside "NoiseParam." structure
    %
    %       mu: This number determines the ratio of pink noise to alpha noise
    %
    %       lambda: This number determines the ratio of signal to noise
    %       
    %       alpha nodes: for now the only option is 'all' which means all visual areas  (maybe later a list of ROIs to put alpha in)
    %
    %       mixing_type_pink_noise: for now only 'coh' is implemented, which is default value
    %
    %       spatial_normalization_type: How to normalize noise and generated signal ['active_nodes']/ 'all_nodes'
    %
    %       distanceType: how to calculate source distances ['Euclidean']/'Geodesic', Geodesic is not implemented yet
    
  % (Plotting Parametes)
    %       sensorFig:      logical indicating whether to draw topo plots of
    %                       the simulated ROI data in sensor space. [true]/false
    %       figFolder:        string specifying folder in which to save sensor
    %                       figs. [Users' Desktop]
    

  % (Save Parameters)
    %       Save:           If true, save the simulated data in axx format
    %                       in project folder, for each subject like:
    %                       Projectfolder/nl-00xx/Exp_MATL_HCN_128_Avg/
    %                       The results of all subjects are also saved in a
    %                       file in project folder as Raw_c00x.mat the
    %                       condition number is according to cndNum
    %                       parameter
    %
    %       cndNum:         The condition number for simulated EEG
  
  % (Inverse Parameters) .... should be corrected
    %       inverse:        a string specifying the inverse name to use
    %                       [latest inverse]
    %       doSource:       logical indicating whether to use the inverse to push
    %                       the simulated ROI data back into source space
    %                       true/[false]
    %
% OUTPUT:
    %       EEGData:        a NS x e matrix, containing simulated EEG,
    %                       where NSs is number of time samples and e is the
    %                       number of the electrodes
    %
    %
    %       EEGAxx:         A cell array containing Axx structure of each
    %                       subject's simulated EEG. This output is
    %                       available if the signal type is SSVEP
    %
    %       sourceDataOrigin: a NS x srcNum matrix, containing simulated
    %                           EEG in source space before converting to
    %                           sensor space EEG, where srcNum is the
    %                           number of source points on the cortical
    %                           meshe
    %
    %       masterList:     a 1 x seedNum cell of strings, indicating ROI names
    %
    %       subIDs:         a 1 x s cell of strings, indicating subjects IDs
    %
%--------------------------------------------------------------------------
 % The function was originally written by Peter Kohler, ...
 % Latest modification: Elham Barzegaran, 03.26.2018
 % Modifications: Sebastian Bosse 8/2/2018
 % NOTE: This function is a part of mrC toolboxs

%% =====================Prepare input variables============================
 
%--------------------------set up default values---------------------------
opt	= ParseArgs(varargin,...
    'inverse'		, [], ...
    'rois'          , [], ...
    'roiType'       , 'wang',...
    'roiSpatfunc'   , 'uniform',...
    'roiSize'       , 200,...
    'signalArray'   , [],...
    'signalsf'      , 100 ,... 
    'signalType'    , 'SSVEP',...
    'signalFF'      , [],...
    'NoiseParams'   , struct,...
    'sensorFig'     , true,...
    'doSource'      , false,...
    'figFolder'     , [],...
    'anatomyPath'   , [],...   
    'plotting'      , 0 ,...
    'Save'          ,true,...
    'cndNum'        ,1, ...
    'nTrials'       ,1 ...
    );

% Roi Type, the names should be according to folders in (svdnl/anatomy/...)
if ~strcmp(opt.roiType,'main')% THIS SHOUDL BE CORRECTED
    switch(opt.roiType)
        case{'func','functional'} 
            opt.roiType = 'functional';
        case{'wang','wangatlas'}
            opt.roiType = 'wang';
        case{'glass','glasser'}
            opt.roiType = 'glass';
        case{'kgs','kalanit'}
            opt.roiType = 'kgs';
        case{'benson'}
            opt.roiType = 'benson';
        otherwise
            error('unknown ROI type: %s',opt.roiType);
    end
else
end


%-------Set folder for saving the results if not defined (default is desktop)----------
if isempty(opt.figFolder)
    if ispc,home = [getenv('HOMEDRIVE') getenv('HOMEPATH')];
    else home = getenv('HOME');end
    opt.figFolder = fullfile(home,'Desktop');
else
end

%------------------set anatomy data path if not defined ---------------------
if isempty(opt.anatomyPath)
    anatDir = getpref('mrCurrent','AnatomyFolder');
    if contains(upper(anatDir),'HEADLESS') || isempty(anatDir) %~isempty(strfind(upper(anatDir),'HEADLESS'))
        anatDir = '/Volumes/svndl/anatomy';
        setpref('mrCurrent','AnatomyFolder',anatDir);
    else
    end
else
    anatDir = opt.anatomyPath;
end

%------------------------Check ROIs class----------------------------------
if ~isempty(opt.rois)
    [opt.rois,FullroiNames,RSubID] = CheckROIsArray(opt.rois);
    if isempty(opt.rois)
        display('Simulation terminated');
        EEGData=[];EEGAxx=[];sourceDataOrigin=[];masterList=[];subIDs=[];
    end
else
    [Roi] = mrC.Simulate.GetRoiClass(projectPathfold,anatDir);
    Roi = cellfun(@(x) x.getAtlasROIs(opt.roiType),Roi,'UniformOutput',false);
end
% -----------------Generate default source signal if not given-------------
% Generate signal of interest
if isempty(opt.signalArray) 
    if isempty(opt.rois)
        [opt.signalArray, opt.signalFF, opt.signalsf]= mrC.Simulate.ModelSeedSignal('signalType',opt.signalType); % default signal (can be compatible with the number of ROIs, can be improved later)
    else 
        [opt.signalArray, opt.signalFF, opt.signalsf]= mrC.Simulate.ModelSeedSignal('signalType',opt.signalType,'signalFreq',round(rand(length(FullroiNames),1)*3+3));
    end
end

if isfield(opt,'signalFF')
    if ~iscolumn(opt.signalFF), opt.signalFF = opt.signalFF';end
end

%% ===========================GENERATE EEG signal==========================
projectPathfold = projectPath;
projectPath = subfolders(projectPath,1); % find subjects in the main folder

for s = 1:length(projectPath)
    %--------------------------READ FORWARD SOLUTION---------------------------  
    % Read forward
    [~,subIDs{s}] = fileparts(projectPath{s});
    disp (['Simulating EEG for subject ' subIDs{s}]);
    
    fwdPath = fullfile(projectPath{s},'_MNE_',[subIDs{s}]);
    
    % remove the session number from subjec ID
    SI = strfind(subIDs{s},'ssn');
    if ~isempty(SI)
        subIDs{s} = subIDs{s}(1:SI-2);% -2 because there is a _ before session number
    end
    
    % check if the ROIs and Wang atlas (used for alpha noise) exist for this subject
    alphaRoi = mrC.ROIs([],anatDir);alphaRoi = alphaRoi.loadROIs(subIDs{s},anatDir);
    alphaRoi = alphaRoi.getAtlasROIs('wang');
    
    if sum(strcmp(subIDs{s},RSubID)) || (alphaRoi.ROINum ==0)
        EEGData{s}=[];EEGAxx{s}=[];sourceDataOrigin{s}=[];
        warning(['Skip subject ' subIDs{s} '... ROIs can not be found for this subject! '])
        continue;
    end
    
    
    % To avoid repeatition for subjects with several sessions
    if s>1, 
        SUBEXIST = strcmpi(subIDs,subIDs{s});
        if sum(SUBEXIST(1:end-1))==1,
            disp('EEG simulation for this subject has been run before');
            continue
        end
    end
    
    if exist([fwdPath '-fwd.mat'],'file') % if the forward matrix have been generated already for this subject
        load([fwdPath '-fwd.mat']);
    else
        fwdStrct = mne_read_forward_solution([fwdPath '-fwd.fif']); % Read forward structure
        % Checks if freesurfer folder path exist
        if ~ispref('freesurfer','SUBJECTS_DIR') || ~exist(getpref('freesurfer','SUBJECTS_DIR'),'dir')
            %temporary set this pref for the example subject
            setpref('freesurfer','SUBJECTS_DIR',fullfile(anatDir,'FREESURFER_SUBS'));% check
        end
        srcStrct = readDefaultSourceSpace(subIDs{s}); % Read source structure from freesurfer
        fwdMatrix = makeForwardMatrixFromMne(fwdStrct ,srcStrct); % Generate Forward matrix
    end
    
    % ---------------------------Default ROIs----------------------------------
    seedNum = size(opt.signalArray,2); % Number of seed sources
    
    % Select Random ROIs 
    if isempty(opt.rois)
        % Initialized only for the first subject, then use the same for the rest
        RROI = randperm(Roi{1}.ROINum,seedNum);
        %BE careful about this part %%!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        opt.rois = cellfun(@(x) x.selectROIs(RROI),Roi,'UniformOutput',false);% Control for consistency
        [~,M] = max(cellfun(@(x) x.ROINum,opt.rois));
        disp (['Number of ROIs :' num2str(opt.rois{M}.ROINum)]);
        FullroiNames =opt.rois{M}.getFullNames;
        disp(['ROI Names : ' cat(2,FullroiNames{:}) ]);
    end
    masterList = FullroiNames; %cellfun(@(x) [x.Name '_' x.Hemi],opt.rois,'UniformOutput',false); 

%-------------------Generate noise: based on Sebastian's code------------------
    
    % -----Noise default parameters-----
    NS = size(opt.signalArray,1); % Number of time samples
    Noise = opt.NoiseParams;
    Noisefield = fieldnames(Noise);
    
    if ~any(strcmp(Noisefield, 'mu')),Noise.mu = 1;end % power distribution between alpha noise and pink noise ('noise-to-noise ratio')
    if ~any(strcmp(Noisefield, 'lambda')),Noise.lambda = 1/NS/2;end % power distribution between signal and 'total noise' (SNR)
    if ~any(strcmp(Noisefield, 'spatial_normalization_type')),Noise.spatial_normalization_type = 'all_nodes';end% 'active_nodes'/['all_nodes']
    if ~any(strcmp(Noisefield, 'distanceType')),Noise.distanceType = 'Euclidean';end
    if ~any(strcmp(Noisefield, 'Noise.mixing_type_pink_noise')), Noise.mixing_type_pink_noise = 'coh' ;end % coherent mixing of pink noise
    if ~any(strcmp(Noisefield, 'alpha_nodes')), Noise.alpha_nodes = 'all';end % for now I set it to all visual areas, later I can define ROIs for it

    % -----Determine alpha nodes: This is temporary?-----
    %alphaRoiDir = fullfile(anatDir,subIDs{s},'Standard','meshes','wang_ROIs');% alpha noise is always placed in wang ROIs
        alpharoiChunk = alphaRoi.ROI2mat(length(fwdMatrix));
    if strcmp(Noise.alpha_nodes,'all'), AlphaSrc = find(sum(alpharoiChunk,2)); end % for now: all nodes will show the same alpha power over whole visual cortex  

    disp ('Generating noise signal ...');
    
    % -----Calculate source distance matrix-----
    load(fullfile(anatDir,subIDs{s},'Standard','meshes','defaultCortex.mat'));
    surfData = msh.data; surfData.VertexLR = msh.nVertexLR;
    clear msh;
    spat_dists = mrC.Simulate.CalculateSourceDistance(surfData,Noise.distanceType);
    
    % -----This part calculate mixing matrix for coherent noise-----
    if strcmp(Noise.mixing_type_pink_noise,'coh')
        mixDir = fullfile(anatDir,subIDs{s},'Standard','meshes',['noise_mixing_data_' Noise.distanceType '.mat']);
        if ~exist(mixDir,'file')% if the mixing data is not calculated already
            noise_mixing_data = mrC.Simulate.GenerateMixingData(spat_dists);
            save(mixDir,'noise_mixing_data');
        else
            load(mixDir);
        end
    end
    
    % ----- Generate noise-----
    % this noise is NS x srcNum matrix, where srcNum is the number of source points on the cortical  meshe
    noise_signal = zeros(NS, size(spat_dists,1), opt.nTrials);
    for trial_id =1:opt.nTrials % this could be solved more elegantly in GenerateNoise as well..
        [thisNoiseSignal, pink_noise,~, alpha_noise] = mrC.Simulate.GenerateNoise(opt.signalsf, NS, size(spat_dists,1), Noise.mu, AlphaSrc, noise_mixing_data,Noise.spatial_normalization_type);   
        noiseSignal(:,:,trial_id) = thisNoiseSignal ;
    end
    %visualizeNoise(noiseSignal, spat_dists, surfData,opt.signalsf) % Just to visualize noise on the cortical surface 
    %visualizeNoise(alpha_noise, spat_dists, surfData,opt.signalsf)
    % 
%------------------------ADD THE SIGNAL IN THE ROIs--------------------------
    
    disp('Generating EEG signal ...'); 
 
    subInd = strcmp(cellfun(@(x) x.subID,opt.rois,'UniformOutput',false),subIDs{s});
    [EEGData{s},sourceDataOrigin{s}] = mrC.Simulate.SrcSigMtx(opt.rois{find(subInd)},fwdMatrix,surfData,opt.signalArray,noiseSignal,Noise.lambda,'active_nodes',opt.roiSize,opt.roiSpatfunc);%Noise.spatial_normalization_type);% ROIsig % NoiseParams
       
    %visualizeSource(sourceDataOrigin{s}, surfData,opt.signalsf,0)
    %% convert EEG to axx format
    if strcmp(opt.signalType,'SSVEP')
        EEGAxx{s}= mrC.Simulate.CreateAxx(EEGData{s},opt);% Converts the simulated signal to Axx format  
    end
    
%% write output to file 
    
    if (opt.Save)
        SavePath = projectPathfold;
        % prepare mrC simulation project
        if ~exist(fullfile(SavePath,subIDs{s}),'dir')
            mkdir(fullfile(SavePath,subIDs{s}));
        end
        
        % Write axx files
        if ~exist(fullfile(SavePath,subIDs{s},'Exp_MATL_HCN_128_Avg'),'dir')
            mkdir(fullfile(SavePath,subIDs{s},'Exp_MATL_HCN_128_Avg'))
        end
        EEGAxx{s}.writetofile(fullfile(SavePath,subIDs{s},'Exp_MATL_HCN_128_Avg',sprintf('Axx_c0%02d.mat',opt.cndNum)));
        
        % Copy Inverse files
        % copyfile(fullfile(projectPath{s},'Inverses'),fullfile(SavePath,subIDs{s},'Inverses'));
        
        % Write Original source Data
        if ~exist(fullfile(SavePath,subIDs{s},'Orig_Source_Simul'),'dir')
            mkdir(fullfile(SavePath,subIDs{s},'Orig_Source_Simul'));
        end
        SourceDataOrigin = sourceDataOrigin{s};
        save(fullfile(SavePath,subIDs{s},'Orig_Source_Simul',sprintf('Source_c0%02d.mat',opt.cndNum)),'SourceDataOrigin');
    end
end

%% save simulated EEG of all subjects in one file

save(fullfile(projectPathfold,sprintf('SimulatedEEG_c0%02d.mat',opt.cndNum)),'EEGData','EEGAxx','subIDs','masterList');

%% =======================PLOT FIGURES=====================================
if (opt.plotting==1) && strcmp(opt.signalType,'SSVEP')
    %-------------------Calculate EEG spectrum---------------------------------
    sub1 = find(~cellfun(@isempty,EEGAxx),1);
    freq = 0:EEGAxx{sub1}.dFHz:EEGAxx{sub1}.dFHz*(EEGAxx{sub1}.nFr-1); % frequncy labels, based on fft

    for s = 1:length(projectPath)
        if ~isempty(EEGData{s})
            ASDEEG{s} = EEGAxx{s}.Amp;% it is important which n is considered for fft

            % ------------------------FIRST PLOT: EEG and source spectra---------------
            WL = 1000/(EEGAxx{sub1}.dTms*EEGAxx{sub1}.dFHz); % window length for FFT, based on AXX file
            freq2 = (-0.5:1/(WL*4):0.5-1/(WL*4))*opt.signalsf;
            figure,
            subplot(3,1,1); % Plot signal ASD
            plot(freq2,abs(fftshift(fft(opt.signalArray,WL*4),1)));
            xlim([0,max(freq2)]);xlabel('Frequency(Hz)');
            ylabel('Source signal','Fontsize',14);

            subplot(3,1,2); % Plot noise ASD
            plot(freq2,abs(fftshift(fft(noiseSignal(:,1:500:end),WL*4),1)));
            xlim([0,max(freq2)]);xlabel('Frequency(Hz)');
            ylabel('Noise signal','Fontsize',14);

            subplot(3,1,3); % plot EEG ASD
            %plot(freq2,abs(fftshift(fft(EEGData,WL*4),1)));
            plot(freq,ASDEEG{s});
            xlim([0,max(freq2)]);xlabel('Frequency(Hz)');
            ylabel('EEG signal','Fontsize',14);

            input('Press enter to continue....');
            close all;
            % --------------SECOND PLOT: interactive head and spectrum plots-----------
            if isempty(opt.signalFF)
                opt.signalFF = 1;
            end

             % Plot individuals
             mrC.Simulate.PlotEEG(ASDEEG{s},freq,opt.figFolder,subIDs{s},masterList,opt.signalFF);
        end 
    end
    
    % Plot average over individuals
    MASDEEG = mean(cat(4,ASDEEG{:}),4);
    mrC.Simulate.PlotEEG(MASDEEG,freq,opt.figFolder,'average over all  ',masterList,opt.signalFF);

end
end

function [ROIsArr,FullroiNames,RSubID] = CheckROIsArray(ROIsArr)
    if sum(abs(diff(cellfun(@(x) x.ROINum,ROIsArr))))~=0
        warning ('Number of ROIs is not the same for all subjects');
        RSub = find(cellfun(@(x) x.ROINum,ROIsArr)==0);
        RSubID = cellfun(@(x) x.subID,ROIsArr(RSub),'UniformOutput',false);
        ROIsArr(RSub)=[];% remove the subjects
        
    else
        RSubID = [];
    end

    [~,M] = max(cellfun(@(x) x.ROINum,ROIsArr));
    disp ('Start simulating EEG...');
    disp (['Number of ROIs :' num2str(ROIsArr{M}.ROINum)]);
    FullroiNames =ROIsArr{M}.getFullNames;
    disp(['ROI Names : ' cat(2,FullroiNames{:}) ]);

    % check the order of ROIs in subjects and make them consistent
    FNames = cellfun(@(x) x.getFullNames,ROIsArr,'UniformOutput',false);
    comps = cellfun(@(x) strcmpi(cat(1,FNames{:}),x), FullroiNames,'UniformOutput',false);
    comps = cat(3,comps{:});comps = sum(comps.*repmat(1:numel(FullroiNames),[size(comps,1) 1 size(comps,3)]),3);
    comps = mat2cell(comps,ones(size(comps,1),1),size(comps,2))';
    ROIsArr = cellfun(@(x,y) x.selectROIs(y),ROIsArr,comps,'UniformOutput',false);
end
