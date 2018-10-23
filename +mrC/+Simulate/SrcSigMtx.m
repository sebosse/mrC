function [EEGData,sourceData,roiSet] = SrcSigMtx(rois,fwdMatrix,surfData,signalArray,noise,lambda,spatial_normalization_type,RoiSize,funcType)% ROIsig %NoiseParams

    % Description:	Generate Seed Signal within specified ROIs
    %
    % Syntax: [EEGData,sourceData,roiSet] = SrcSigMtx(rois,fwdMatrix,surfData,signalArray,noise,lambda,spatial_normalization_type,RoiSize,funcType)
    
    % INPUT:
    %   roiDir - string, path to ROI directory
    %   
    %   masterList: a 1 x n cell of strings, indicating the ROIs to use
    %
    %   ROIsig: T x n array of doubles, indicating source signal %%%% TO BE ADDED
    %
    %   NoiseParams: Parameters for generating noise, should be a structure %%%% TO BE ADDED
    %
    %   fwdMatrix: ne x nsrc matrix: The subject's forward matrix
    %   
    %   signalArray: ns x n matrix: Containing the signals for the ROIs
    %   
    %   noise: ns x nsrc matrix: Containing the noises signal in source space
    %   
    %   lambda: Parameter for defining of SNR: How to add noise and signal
    %   
    %   spatial_normalization: how to nomalize the source signals...
    %
    % OUTPUT:
    % 	EEGData: ns x ne matrix: simulated EEG signal
    %   
    %   sourceData: ns x nsrc Matrix: simulated signal in source space
    %
    %	roiSet: a 1 x nROIs cell of node indices
    
    
  % Elham Barzegaran 2.27.2018
    
  % Updated EB, 6.5.2018
  
%%

if ~exist('RoiSize','var'), RoiSize = [];end
if ~exist('funcType','var'), funcType = [];end

if isempty(rois),% if roi is empty ofr this subject
    EEGData=[];sourceData=[];roiSet=[];
    warning('No ROI found, no simulated EEG is generated');
    return
end

roiChunk = zeros(size(fwdMatrix,2),rois.ROINum);
for r = 1:rois.ROINum % Read each Roi and check if they exist
    roiChunk(rois.ROIList(r).meshIndices,r)=1;
end

if size(roiChunk,2)~= size(signalArray,2)
        EEGData=[]; 
        sourceData=[];
        roiSet=[];
        warning('Number of ROIs is not equal to number of source signals');
        return;
        % error('Number of ROIs is not equal to number of source signals');
end

%
if ~isempty(roiChunk)
    %% seed ROIs
    % Note: I consider here that the ROI labels in shortList are unique (L or R are considered separetly)
    % Adjust Roi size, prepare spatial function (weights) and plot ROIs

    plotRoi = 0;
    %RoiSize = 200;
    spatfunc = RoiSpatFunc(roiChunk,surfData,RoiSize,[],funcType,plotRoi);

    % place seed signal array in source space
    sourceTemp = zeros(size(noise));
    for s = 1: size(signalArray,2)% place the signal for each seed 
        sourceTemp = sourceTemp + repmat (signalArray(:,s),[1 size(sourceTemp,2)]).*(repmat(spatfunc(:,s),[1 size(sourceTemp,1)])');
    end

    % Normalize the source signal
    if strcmp(spatial_normalization_type,'active_nodes')
    n_active_nodes_signal = sum(sum(abs(sourceTemp))~=0) ;
        sourceTemp = n_active_nodes_signal * sourceTemp/norm(sourceTemp,'fro') ;
    elseif strcmp(spatial_normalization_type,'all_nodes')
        sourceTemp = sourceTemp/norm(sourceTemp,'fro') ;
    else
        error('%s is not implemented as spatial normalization method', spatial_normalization_type)
    end
        
        
else
    sourceTemp = zeros(size(noise));
end

% Adds noise to source signal
pow = 1;
sourceData = ((lambda/(lambda+1))^pow)*sourceTemp + ((1/(lambda+1))^pow) *noise;
sourceData = sourceData/norm(sourceData,'fro') ;% signal and noise are correlated randomly (not on average!). dirty hack: normalize sum

% Generate EEG data by multiplication to forward matrix
EEGData = sourceData*fwdMatrix';

% there should be another step: add measurement noise to EEG?
end

function spatfunc = RoiSpatFunc(roiChunk,surfData,RoiSize,Hem,funcType,plotRoi)
%------------resize and plot ROIs on the 3D brain Surface------------------
RoiIdx = 1:size(roiChunk,2);
if ~exist('RoiSize','var')
    RoiSize = max(sum(full(roiChunk(:,RoiIdx))));
elseif isempty(RoiSize)
    RoiSize = max(sum(full(roiChunk(:,RoiIdx))));
end

if~exist('Hem','var')
    Hem='B';
elseif isempty(Hem)
    Hem = 'B';
end

if~exist('funcType','var')
    funcType = 'uniform';
end

%% ------------------------ prepare surface data --------------------------
vertices = surfData.vertices';
faces = (surfData.triangles+1)';
% adjustements for visualization purpose
vertices = vertices(:,[1 3 2]);vertices(:,3)=200-vertices(:,3);
spatfunc = zeros(size(roiChunk,1),numel(RoiIdx));

% ------------------------ spatial functions for ROIs----------------------
for i = 1:numel(RoiIdx)
    vertIdx_orig = find(roiChunk(:,RoiIdx(i)));
    [RoiV, RoiF,vertIdx] = SurfSubsample(vertices, faces,vertIdx_orig,'union');
    [RoiVertices{i}, RoiFaces{i},vertIdxR,~,RoiDist,radius] = ResizeRoi(RoiV,RoiF,vertIdx,RoiSize,'geodesic');
    if (~isempty(vertIdx)) && (~isempty(vertIdxR))
        switch funcType
            case 'uniform'
                spatfunc(vertIdx_orig((vertIdxR)),i)=1;
            case 'gaussian'
                Var = (radius/2)^2;
                spatfunc(vertIdx_orig((vertIdxR)),i)=exp(-(RoiDist.^2)/(2*Var));
            otherwise
                error([funType ' as a spatial function for ROI is not defined']);
        end
    end
end

if plotRoi ==1
    %--------------------------- plot surface------------------------------
    figure,
    switch Hem
        case 'L'
            Faces = faces(1:(size(FV2.faces,1))/2,:);
        case 'R'
            Faces = faces(((size(FV2.faces,1))/2)+1:end,:);
        case 'B'
            Faces = faces;
    end
    patch('faces',Faces,'vertices',vertices,'edgecolor','none','facecolor','interp','facevertexcdata',repmat([.7,.7,.7],size(vertices,1),1),...
         'Diffusestrength',.55,'AmbientStrength',.3,'specularstrength',.4,'FaceAlpha',.55,'facelighting','gouraud');
    shading interp
    lightangle(50,180)
    lightangle(50,0)
    view(90,0)
    axis  off vis3d equal
    set(gcf, 'Units', 'Normalized', 'OuterPosition', [0.2, 0.24, .30, 0.45]);
    %---------------------------- plot Rois -------------------------------
    cmap = colormap(hsv(256));
    for i = 1:numel(RoiIdx)
        C=cmap(i*floor(255/numel(RoiIdx)),:);
        if ~isempty(RoiFaces{i}),
            hold on; patch('faces',RoiFaces{i},'vertices',RoiVertices{i},'edgecolor','k','facecolor','interp','facevertexcdata',repmat(C,size(RoiVertices{i},1),1),...
                'Diffusestrength',.55,'AmbientStrength',.7,'specularstrength',.2,'FaceAlpha',1,'facelighting','gouraud');
            scatter3(RoiVertices{i}(:,1),RoiVertices{i}(:,2),RoiVertices{i}(:,3),30,C,'filled');
        end
    end
end
end

function [vertices, faces, vertIdx2, RoiC, dist, radius, area] = ResizeRoi(RoiV,RoiFaces,vertIdx,RoiSize, distanceType, RoiC)

% This function gets the vertices and faces in one ROI and returns a
% smaller ROI with the size determmined by RoiSize variable. It calculates
% the center of the surface and then select the vertices in a raduis from the
% center, so that a specific number of vertices are selected....

%INPUTS
    % RoiV: Nx3 matrix, containing the coordinates of vertices in ROI, where
            % N is the initial number of vertices in ROI          
    % RoiFaces: Px3 matrix containg the face information of the vertices in
            % ROI, the numbers in it should corresponds to the number of RoiV        
    % RoiSize: is the desired size (number of vertices) of ROI 
    % distanceType: ['geodesic']/'eulidean', an string which determines the
            % type of distance to calculates       
    % RoiC: <optional>, determines the index of central vertice, otherwise
            % it is calculated as a vertice with shortest distance to all other
            % vertices
            
%OUTPUTS
    % vertices: RoiSize x 3 matrix, containing the coordinates of vertices in "resized" ROI
    % faces: P2x3 matrix containg the face information of resized ROI, the 
            % numbers in it corresponds to the number of "vertices" matrix       
    % vertIdx2: the indexes that indicate which vertices in RoiV are selected   
    % area: area of the resized ROI
    % RoiC: the index that indicates the center of ROI ????
%%
if isempty(distanceType), distanceType='geodesic';end
if ~exist('RoiC','var'),RoiC = [];end

if RoiSize>numel(vertIdx)
    warning('RoiSize is bigger than the number of vertices in this ROI');
    RoiSize = numel(vertIdx);
end
if isempty(RoiSize)
    RoiSize = numel(vertIdx);
end

if isempty(vertIdx)
    warning('There is no vertices in this ROI');
end
if isempty(RoiFaces)
    vertices = RoiV(vertIdx);
    faces = RoiFaces;
    vertIdx = 1:numel(vertIdx);
    radius = 0;
    area = 0;
    RoiC = [];
    vertIdx2 = vertIdx;
    dist = [];
    return;
end

%%
switch distanceType
    case 'euclidean'
        RoiDist = squareform(pdist(RoiV(vertIdx,:)));% or Geodesic ditance
    case 'geodesic'
        for i= 1:numel(vertIdx)
            [RoiDist(:,i)] = perform_fast_marching_mesh(RoiV, RoiFaces,vertIdx(i)); % THIS IS FROM surfing toolbox
        end
        RoiDist = RoiDist(vertIdx,:);
    otherwise 
        error (['No ' distanceType ' is defined! please select geodesic or euclidean distance']);
end

% First find the center of ROIs (like center of mass)
RoiDist(RoiDist==inf) = 1000;
if isempty(RoiC), [~,RoiC] = min(sum(RoiDist));end

% select vertices with a specific distance from the center
[f,x] = ecdf(RoiDist(RoiC,:));
f = round(f*numel(vertIdx));
radius = x(f==(RoiSize));
vertIdx2 = find(RoiDist(RoiC,:)<=radius);
vertIdx2 = sort(vertIdx2);

if (isinf(radius)) || (radius >=1000)
    x(x>=1000)=0;
    radius = max(x); 
end

% select the faces that their three vertices is in the selected list
[vertices, faces] = SurfSubsample(RoiV, RoiFaces,vertIdx(vertIdx2),'intersect');

% distance of ROI vetrices from central vertice
dist = RoiDist(RoiC,vertIdx2);
%% surface area calculation

a = vertices(faces(:, 2), :) - vertices(faces(:, 1), :);
b = vertices(faces(:, 3), :) - vertices(faces(:, 1), :);
c = cross(a, b, 2);
area = 1/2 * sum(sqrt(sum(c.^2, 2)));

end

function [nvertices, nfaces,vertIdx2] = SurfSubsample(vertices, faces,vertIdx,type)

% This function selects a subset of vertices and their corresponding faces indicated by vertIdx 
% INPUT: 
    % type: can be 'union' or 'intersect', the criteria for including faces
%-------------------------------------------------------------------------
if ~exist('type','var'),type = 'intersect';end
%-------------------------------------------------------------------------
vertIdx = sort(vertIdx);
I1 = find(ismember(faces(:,1),vertIdx));
I2 = find(ismember(faces(:,2),vertIdx));
I3 = find(ismember(faces(:,3),vertIdx));

if strcmp(type,'intersect')
    FI  = intersect(intersect(I1,I2),I3);
    nfaces = faces(FI,:);
    vertIdx2 = unique(nfaces(:));
    nvertices = vertices(vertIdx,:);
    fnew = zeros(size(nfaces));
    for i = 1:numel(vertIdx)
        fnew(nfaces==vertIdx(i)) = i;
    end
    nfaces=fnew;
    [~,vertIdx2] = intersect(vertIdx2,vertIdx);

elseif strcmp(type,'union')
    FI = union(union(I1,I2),I3);
    nfaces = faces(FI,:);
    vertIdx2 = unique(nfaces(:));
    nvertices = vertices(vertIdx2,:);
    fnew = zeros(size(nfaces));
    for i = 1:numel(vertIdx2)
        fnew(nfaces==vertIdx2(i)) = i;
    end
    nfaces=fnew;
    [~,vertIdx2] = intersect(vertIdx2,vertIdx);

else
    error('Criteria is not defined');
end

end


