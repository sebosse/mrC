
function [ForwardPath, AnatomyPath]  = PrepareProjectSimulate(ProjectPath,DestPath,varargin)
% This function get a mrC project folder and copy the necessary forward,
% ROI and surface data to another destination to make a smaller input data
% for mrC.simulate 
% INPUTS:
    % ProjectPath: the path to mrCProject, if [], you can select with
                    % user interface
    % DestPath:     the path to save results, if [], you can select with
                    % user interface
    % <options>
        % FwdFormat:  the format of the forward solution to be stored
        %             the reason for adding .mat is to reduce the size of the 
        %             files, .mat files are much smaller than fif files
        %             ['fif']/'mat'
    
% OUTPUTS:
    % ForwardPath: The path of Project that contains forward models
    % AnatomyPath: The path to the anatomy folder for ROIs, and brain surface
    
% -------------------------------------------------------------------------
% Author: Elham Barzegaran, 4/9/2018
%%
opt	= ParseArgs(varargin,...
    'FwdFormat'		, 'fif' ...
    );
display ('Copy project and anatomy files to a local folder...')

%% Get project and destination folder

ProjectPath2 = uigetdir(ProjectPath, 'Select a mrC source project forlder');
if ~strcmp(ProjectPath2,ProjectPath) && ischar(ProjectPath2)
    ProjectPath = ProjectPath2;
end
if isempty(ProjectPath) || ~ischar(ProjectPath2),
    disp('No project folder is selected, no file is copied.')
    ForwardPath=[]; AnatomyPath=[];
    return
end

DestPath2 = uigetdir([],'Select the destination forlder');% Get destination location
if ~strcmp(DestPath2,DestPath) && ischar(DestPath2)
    DestPath = DestPath2;
end

if isempty(DestPath) || ~ischar(DestPath2),
    disp('No destination folder is selected, no file is copied.')
    ForwardPath=[]; AnatomyPath=[];
    return
end
%% Copy Data

projectPath = subfolders(ProjectPath,1); % find subjects in the main folder

for s = 1:length(projectPath)
    
    [~,subIDs{s}] = fileparts(projectPath{s});
    
    disp(['Copying data for subject ' subIDs{s} ' ...']);
    % ---------------------Copy Froward matrixes---------------------------
    fwdPath = fullfile(projectPath{s},'_MNE_',[subIDs{s} '-fwd.fif']);
    % remove the session number from subjec ID
    SI = strfind(subIDs{s},'ssn');
    if ~isempty(SI)
        subIDs{s} = subIDs{s}(1:SI-2);% -2 because there is a _ before session number
    end  
    
    if s>1, % To avoid repeatition for subjects with several sessions
    SUBEXIST = strcmpi(subIDs,subIDs{s});
    if sum(SUBEXIST(1:end-1))==1,
        disp('Data for this subject has been copied before');
        continue
    end
    end
    
    fwdPathDest = fullfile(DestPath,'FwdProject',subIDs{s},'_MNE_');
    if ~exist(fwdPathDest,'dir')
        mkdir(fwdPathDest);
    end
    if strcmpi(opt.FwdFormat,'fif'),
        copyfile(fwdPath,fwdPathDest); %%%%% COPY forward matrix
    elseif strcmpi(opt.FwdFormat,'mat'),% I added this part to reduce the data size
        fwdStrct = mne_read_forward_solution(fwdPath); % Read forward structure
        srcStrct = readDefaultSourceSpace(subIDs{s}); % Read source structure from freesurfer
        fwdMatrix = makeForwardMatrixFromMne(fwdStrct ,srcStrct); % Generate Forward matrix
        %[~,name,~] = fileparts(fwdPath);
        save(fullfile(fwdPathDest,[subIDs{s} '-fwd.mat']),'fwdMatrix');
    end

    % ------------------------Copy Anatomy data----------------------------
    if strcmpi(opt.FwdFormat,'fif'),
        fsDir = getpref('freesurfer','SUBJECTS_DIR');
        subIDFS = subIDs{s};
        %append fs4 if not there
        if ~(strncmp(subIDFS(end-2:end),'fs4',3)),subIDFS = [subIDFS '_fs4'];end
        if ~exist('sourceId','var') || isempty(sourceId), sourceId = 'ico-5p';end

        SrcStrct=fullfile(fsDir,subIDFS,'bem',[subIDFS '-' sourceId '-src.fif']);
        SrcStrctDest = fullfile(DestPath,'anatomy','FREESURFER_SUBS',subIDFS,'bem');
        if ~exist(SrcStrctDest,'dir'),
            mkdir(SrcStrctDest);
        end
        copyfile(SrcStrct,SrcStrctDest); %%%%% COPY source struct file
    end
    % -------------------------Copy ROI data-------------------------------
    anatDir = getpref('mrCurrent','AnatomyFolder');
    if contains(upper(anatDir),'HEADLESS') || isempty(anatDir) %~isempty(strfind(upper(anatDir),'HEADLESS'))
        anatDir = '/Volumes/svndl/anatomy';
        setpref('mrCurrent','AnatomyFolder',anatDir);
    else
    end
    roiDir = fullfile(anatDir,subIDs{s},'Standard','meshes');
    roiDirsub = subfolders(roiDir,0);
    roiDirDest = fullfile(DestPath,'anatomy',subIDs{s},'Standard','meshes');
     
    for d = 1:numel(roiDirsub) % copy all available ROIs, except the folder containing all ROIs ("ROIs")
        if ~strcmpi(roiDirsub{d},'ROIs')
            if~exist(fullfile(roiDirDest,roiDirsub{d}),'dir'),
                mkdir(fullfile(roiDirDest,roiDirsub{d}));
            end
            copyfile(fullfile(roiDir,roiDirsub{d}),fullfile(roiDirDest,roiDirsub{d})); % copy ROIs
        end
    end
    
    copyfile(fullfile(roiDir,'defaultCortex.mat'),roiDirDest);
end

% OUTPUT variabless
AnatomyPath = fullfile(DestPath,'anatomy');
ForwardPath = fullfile(DestPath,'FwdProject');

end
