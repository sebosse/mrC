function [results] = tSquaredFourierCoefs(xyData,varargin)
    % Syntax: [results] = tSquaredFourierCoefs(xyData,testMu,alphaVal)
    %
    % Returns the results of running Hotelling's t-squared test that the mean
    % of the 2D data in xyData is the same as the mean specified in testMu at
    % the specified alphaVal (0-1).
    %
    % Based on Anderson (1984) An Introduction to Multivariate Statistical 
    % Analysis, Wiley
    %
    % In:
    %   xyData - n x 2 x q matrix containing n data samples
    %            if q = 1, data will be tested against zero    
    %            if q = 2, a paired t-test will be performed,
    %            testing xyData(:,:,1) against xyData(:,:,2). 
    %            2 is the maximum length of the third dimension. 
    %            Function assumes that the 2D data in xyData(:,:,1)
    %            and the optional xyData(:,:,2) are Fourier 
    %            coefficients organized with the real coefficients 
    %            in the 1st column and the imaginary
    %            coefficients in the 2nd column. Rows = samples.
    % 
    % <options>:
    %   testMu - 2-element vector specifying the mean to test against ([0,0]) 
    % 
    %   alphaVal - scalar indicating the alpha value for testing ([0.05])
    %
    %   pdStyle - do PowerDiva style testing (true/[false])
    %
    % Out:
    %
    %   results - struct containing the following fields:
    %             alpha, tSqrdCritical, tSqrd, pVal, H (0 if can't reject null; 1 if
    %             rejected the null hypothesis)

    opt	= ParseArgs(varargin,...
        'testMu'		, [0,0], ...
        'alphaVal'		, 0.05	, ...
        'pdStyle',        false ...
        );

    dims = size(xyData);
    if dims(1) < 2
        error('input data must contain at least 2 samples');
    end
    if dims(2) ~= 2
        error('input data must be a matrix of 2D row samples');
    end
    if length(dims) < 3 % if no third dimension
        xyData(:,:,2) = zeros(size(xyData));
    elseif dims(3) > 2
         error('length of third dimension of input data may not exceed two')
    else
    end

    if length(opt.testMu) ~= 2
        error('testMu should be a 2D vector');
    end

    xyData = xyData(:,:,1) - xyData(:,:,2);
    
    % remove NaNs
    xyData = xyData(~any(isnan(xyData),2),:);
    
    N = size(xyData,1);
    
    try
        [sampMu,sampCovMat] = eigFourierCoefs(xyData);
    catch
        fprintf('The covariance matrix of xyData could not be calculated, probably your data do not contain >1 sample.');
    end

    if opt.pdStyle
        sampCovMat = eye(2);
    else
    end

    results.alpha = opt.alphaVal;

    p = 2; % number of variables
    df1 = p;  %Numerator degrees of freedom.
    df2 = N-p;  %Denominator degrees of freedom.
    
    % Eqn. 2 in Sec. 5.3 of Anderson (1984):
    t0Sqrd = ( (N-1) * p )/ ( N-p ) * finv( 1-opt.alphaVal, p, N - p ); 
    results.tSqrdCritical = t0Sqrd;
    
    try
        invSampCovMat = inv(sampCovMat);    
        % Eqn. 2 of Sec. 5.1 of Anderson (1984):
        tSqrd = N * (sampMu - opt.testMu) * invSampCovMat * (sampMu - opt.testMu)'; 

        tSqrdF = (N-p)/(p*(N-1)) * tSqrd; % F approximation 
        pVal = 1 - fcdf(tSqrdF, df1, df2);  % compute p-value

        results.tSqrd = tSqrd;
        results.pVal = pVal;
        results.H = tSqrd >= results.tSqrdCritical;
        results.df1 = df1;
        results.df2 = df2;
        results.testAmp = abs(complex(sampMu(1),sampMu(2)));
    catch
        fprintf('inverse of the sample covariance matrix could not be computed.')
    end
end

