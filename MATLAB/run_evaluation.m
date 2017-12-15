%% === load training data and train CSP classifier ===

%Load the dataset
%Set Data path
dir = '/Users/georgehanna/Projects/MATLAB/BCIComp2a/A01T.gdf';

%Fix Path error
x = fileparts( which('sopen') );
   rmpath(x);
   addpath(x,'-begin');

%Load Data
[cnt,h] = sload(dir, 0, 'OVERFLOWDETECTION:OFF');

%Select specific events and eliminate rejected trials
for i = 1:length(h.EVENT.TYP)
    if(i~=1)
        if (h.EVENT.TYP(i) ~= 1023)
            if (~((h.EVENT.TYP(i) ==769 || h.EVENT.TYP(i) ==770 || h.EVENT.TYP(i) ==771 || h.EVENT.TYP(i) ==772)  && h.EVENT.TYP(i-1) ~= 1023))
                h.EVENT.TYP(i)= NaN;
                h.EVENT.POS(i)= NaN;
            end
        end
    end
end
h.EVENT.TYP(1) = NaN;
h.EVENT.POS(1) = NaN;
idx = find(h.EVENT.TYP==1023);
h.EVENT.TYP(idx) = NaN;
h.EVENT.POS(idx) = NaN;
h.EVENT.TYP(isnan(h.EVENT.TYP)) = [];
h.EVENT.POS(isnan(h.EVENT.POS)) = [];

%Size of remaining markers array will be current size - rejected trials
markers = zeros(length(h.EVENT.TYP)-numel(find(h.EVENT.TYP ==1023)),2);
markers(:,1) = h.EVENT.TYP-768;
markers(:,2) = h.EVENT.POS;

%Bandpass filter between 7 and 30 Hz
flt = @(f)(f>7&f<30).*(1-cos((f-(7+30)/2)/(7-30)*pi*4));

%Train CSP features
[S,T,Mdl] = train_csp(single(cnt), h.SampleRate, sparse(1,markers(:,2),markers(:,1)),[0.5 3.5],flt,3,200);

%% == load test data and apply CSP classifier for each epoch ===
%load data_set_IVb_al_test
y = zeros(length(cnt),1);
for x=1:length(cnt)
    y(x) = test_csp(single(cnt(x,:)),S,T,Mdl);
end

% calculate loss
indices = true_y==-1 | true_y==1;
loss = eval_mcr(y(markers(:,2)),markers(:,1));
fprintf('The mis-classification rate on the test set is %.1f percent.\n',100*loss);

%% === run pseudo-online ===
oldpos = 1;         % last data cursor
t0 = tic;           % start time
y = []; t = [];     % prediction and true label time series
figure;             % make a new figure
len = 3*nfo.fs;     % length of the display window
speedup = 2;        % speedup over real time
while 1
    % determine data cursor (based on current time)
    pos = 1+round(toc(t0)*nfo.fs*speedup);
    % get the chunk of data since last query
    newchunk = single(cnt(oldpos:pos,:));
    % make a prediction (and also read out the current label)
    y(oldpos:pos) = test_csp(newchunk,S,T,w,b);
    t(oldpos:pos) = true_y(pos);
    % plot the most recent window of data
    if pos > len
        plot(((pos-len):pos)/nfo.fs,[y((pos-len):pos); true_y((pos-len):pos)']);
        line([pos-len,pos]/nfo.fs,[0 0],'Color','black','LineStyle','--');
        axis([(pos-len)/nfo.fs pos/nfo.fs -2 2]);
        xlabel('time (seconds)'); ylabel('class');
        drawnow;
    end
    oldpos = pos;
end