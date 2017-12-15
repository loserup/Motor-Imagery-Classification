function [S,T,Mdl] = train_csp(EEG,Fs,mrk,wnd,f,nof,n)
% Train a CSP+LDA classifier
% [S,T,w,b] = train_csp(RawSignal, SampleRate, Markers, EpochWnd, SpectralFlt, FltNumber, FltLength)
%
% In:
%   RawSignal : raw data array [#samples x #channels]
%   SampleRate : sampling rate of the data, in Hz
%   Markers : marker channel (0 = no marker, 1 = first class, 2 = second class)
%   EpochWnd : time range of the epochs to extract relative to the marker
%              in seconds ([begin, end]), e.g. [0.5 3.5]
%   SpectralFlt : spectral filter specfication; this is a function of Frequency in Hz
%                 (e.g., f = @(x)x>7&x<30)
%   FltNumber : number of spatial filters pairs to compute (e.g., 3)
%   FltLength : length of the temporal filter, in samples (e.g., 200)
%
% Out:
%   S : spatial filter matrix [#channels x #filters]
%   T : temporal filter matrix [FltLength x FltLength]
%   w : linear classifier weights
%   b : linear classifier bias


% do frequency filtering using FFT
[t,c] = size(EEG); idx = reshape(1:t*c-mod(t*c,n),n,[]);
FLT = real(ifft(fft(EEG).*repmat(f(Fs*(0:t-1)/t)',1,c)));

% estimate temporal filter using least-squares
T = FLT(idx)/EEG(idx);

% extract data for all epochs of the first class concatenated (EPO{1}) and 
% all epochs of the second class concatenated (EPO{2})
% each array is [#samples x #channels]
wnd = round(Fs*wnd(1)) : round(Fs*wnd(2));
for k = 1:4
    EPO{k} = FLT(repmat(find(mrk==k),length(wnd),1) + repmat(wnd',1,nnz(mrk==k)),:);
end

% calculate the spatial filter matrix S using CSP (TODO: fill in)
C_1 = cov(EPO{1});
C_2 = cov(EPO{2});
C_3 = cov(EPO{3});
C_4 = cov(EPO{4});

%Form 3D cov matrix
R = zeros(size(EPO,2),size(C_1,1),size(C_1,1));
R(1,:,:)=C_1;
R(2,:,:)=C_2;
R(3,:,:)=C_3;
R(4,:,:)=C_4;

%Get projection matrix
S = MulticlassCSP(R,2*nof);

% Log-variance feature extraction
for k = 1:4
    X{k} = squeeze(log(var(reshape(EPO{k}*S', length(wnd),[],2*nof))));
end

class_1_target = ones(length(X{1}),1);
class_2_target = 2.*ones(length(X{2}),1);
class_3_target = 3.*ones(length(X{3}),1);
class_4_target = 4.*ones(length(X{4}),1);

class_targets = vertcat(class_1_target,class_2_target,class_3_target,class_4_target);
adj_train_data = vertcat(X{1},X{2},X{3},X{4});

% train LDA classifier (preferably with gradual outputs) (TODO: fill in)
t = templateLinear();
Mdl = fitcecoc(adj_train_data,class_targets,'Learners',t);



