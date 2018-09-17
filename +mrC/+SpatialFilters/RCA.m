function [OutAxx,W,A,D] = RCA(InAxx,varargin)

% This function calculates finds a spatial filter based on the the RCA of
% InAxx. 

% INPUT:
    % InAxx: EEG data in Axx format
%   <options>:
    % freq_range: Frequnecies of signal considered. 
    %             Default: all, except 0 Hz
    % do_whitening: Apply whitening and dimensionality deflation prior to
    %               estimation of spatial filter. Default: true.
    % rank_ratio:   Threshold for dimensionality reduction based on 
    %               eigenvalue spectrum. Default: 10^-4
% OUTPUT:
    % OutAxx: Data in component space in Axx format
    % W: Spatial filter
    % A: Activation pattern
% 
% Written by Sebastian Bosse, 10.8.2018

opt	= ParseArgs(varargin,...
    'do_whitening', true, ...
    'rank_ratio', 10^-4, ... 
    'freq_range', InAxx.dFHz*[1:(InAxx.nFr-1)], ...
    'model_type','complex' ...
    );

freq_idxs = 1+opt.freq_range/InAxx.dFHz ; % shift as 0Hz has idx 1

n_trials = size(InAxx.Cos,3);
trial_pair_idxs = combnk(1:n_trials,2) ;
trial_pair_idxs = cat(1,trial_pair_idxs,trial_pair_idxs(:,[2,1]));


if strcmpi(opt.model_type,'complex')
    if freq_idxs(1)==1 % 0Hz is considered
        cmplx_signal = cat(1, InAxx.Cos(freq_idxs(2:end),:,:),InAxx.Cos(freq_idxs,:,:)) ... % even real part 
                    + 1i*cat(1, -InAxx.Sin(freq_idxs(2:end),:,:),InAxx.Sin(freq_idxs,:,:)); % odd imag part
    else
        cmplx_signal = cat(1, InAxx.Cos(freq_idxs,:,:),InAxx.Cos(freq_idxs,:,:)) ... % even real part 
                    + 1i*cat(1, -InAxx.Sin(freq_idxs,:,:),InAxx.Sin(freq_idxs,:,:)); % odd imag part    
    end
    % Note that this is different to ﻿Jacek's derivation and implementation as
    % it jointly considers real and imaginary values
    % Cross-trial correlation
    C_xy = conj(reshape(permute(cmplx_signal(:,:,trial_pair_idxs(:,1)),[2,1,3]),size(cmplx_signal,2),[]))*...
        reshape(permute(cmplx_signal(:,:,trial_pair_idxs(:,2)),[2,1,3]),size(cmplx_signal,2),[])'/...
        size(trial_pair_idxs(:,1),1) ;
    % Within-trial correlation
    C_xx = conj(reshape(permute(cmplx_signal(:,:,trial_pair_idxs(:,1)),[2,1,3]),size(cmplx_signal,2),[]))*...
        reshape(permute(cmplx_signal(:,:,trial_pair_idxs(:,1)),[2,1,3]),size(cmplx_signal,2),[])'/...
        size(trial_pair_idxs(:,1),1) ;
    C_yy = conj(reshape(permute(cmplx_signal(:,:,trial_pair_idxs(:,2)),[2,1,3]),size(cmplx_signal,2),[]))*...
        reshape(permute(cmplx_signal(:,:,trial_pair_idxs(:,2)),[2,1,3]),size(cmplx_signal,2),[])'/...
        size(trial_pair_idxs(:,1),1) ;
    
elseif strcmpi(opt.model_type,'cartesian')
    C_xy = reshape(permute(InAxx.Cos(freq_idxs,:,trial_pair_idxs(:,1)),[2,1,3]),size(InAxx.Cos,2),[])*...
           reshape(permute(InAxx.Cos(freq_idxs,:,trial_pair_idxs(:,2)),[2,1,3]),size(InAxx.Cos,2),[])' ;

    C_xx = reshape(permute(InAxx.Cos(freq_idxs,:,trial_pair_idxs(:,1)),[2,1,3]),size(InAxx.Cos,2),[])*...
           reshape(permute(InAxx.Cos(freq_idxs,:,trial_pair_idxs(:,1)),[2,1,3]),size(InAxx.Cos,2),[])' ;

    C_yy = reshape(permute(InAxx.Cos(freq_idxs,:,trial_pair_idxs(:,2)),[2,1,3]),size(InAxx.Cos,2),[])*...
           reshape(permute(InAxx.Cos(freq_idxs,:,trial_pair_idxs(:,2)),[2,1,3]),size(InAxx.Cos,2),[])' ;
end
    
    
if sum(abs(imag(C_xx(:))))/sum(abs(real(C_xx(:))))>10^-10
    error('RCA: Covariance matrix is complex')
end
if sum(abs(imag(C_yy(:))))/sum(abs(real(C_yy(:))))>10^-10
    error('RCA: Covariance matrix is complex')
end
if sum(abs(imag(C_xy(:))))/sum(abs(real(C_xy(:))))>10^-10
    error('RCA: Covariance matrix is complex')
end
C_xx = real(C_xx);
C_yy = real(C_yy);
C_xy = real(C_xy);

if opt.do_whitening % and deflate matrix dimensionality
    disp('whitening')
    [V, D] = eig(C_xy+C_xx+C_yy);
    [ev, desc_idxs] = sort(diag(D), 'descend');
    V = V(:,desc_idxs);
    
    dims = sum((ev/sum(ev))>opt.rank_ratio) ;
    P = V(:,1:dims)*diag(1./sqrt(ev(1:dims)));
else
    dims = size(C_xx,1) ;
    P = eye(dims );
end

C_xx_w = P' * C_xx * P;
C_yy_w = P' * C_yy * P;
C_xy_w = P' * C_xy * P;

[W,D] = eig(C_xy_w,C_xx_w+C_yy_w) ;

[D,sorted_idx] = sort(diag(D),'descend') ;
W = W(:,sorted_idx);
W = P * W;
if sum(abs(imag(W)))>10^-10
    error('RCA: W should not be complex!')
else
    W = real(W) ;
end

A = (C_xx+C_yy) * W * pinv(W'*(C_xx+C_yy)*W);

% project to rca domain
OutAxx = InAxx ;
temp = W'*reshape(permute(InAxx.Cos,[2,1,3]),size(InAxx.Cos,2),[]);
OutAxx.Cos = permute(reshape(temp,dims,size(InAxx.Cos,1),size(InAxx.Cos,3)),[2,1,3]);
temp = W'*reshape(permute(InAxx.Sin,[2,1,3]),size(InAxx.Sin,2),[]);
OutAxx.Sin = permute(reshape(temp,dims,size(InAxx.Sin,1),size(InAxx.Sin,3)),[2,1,3]);
OutAxx.Amp = abs(OutAxx.Cos +1i *OutAxx.Sin);