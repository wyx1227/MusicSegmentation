function [mfcc,bts]=mfccbeatftrs(d, fs)
% frame2mfcc: Frame to MFCC conversion.
%	Usage: mfcc=frame2mfcc(frame, fs, filterNum, mfccNum, plotOpt)
%
%	For example:
%		waveFile='what_movies_have_you_seen_recently.wav';
%		[y, fs, nbits]=wavReadInt(waveFile);
%		startIndex=12000;
%		frameSize=512;
%		frame=y(startIndex:startIndex+frameSize-1);
%		frame2mfcc(frame, fs, 20, 12, 1);

%	Roger Jang 20060417

% if nargin<1, selfdemo; return; end
if nargin<2, fs=16000; end
filterNum=20; 
mfccNum=12;
plotOpt=0; 

tempomean = 240;
temposd = 1.5;
% Try beat tracking now for quick answer
bts = beat(d,fs,[tempomean temposd],[6 0.8],0);          %通过节拍追踪函数寻找节拍点
frameSize=fix(length(d)/length(bts));
k=0;
% frameSize=length(frame);
% ====== Preemphasis should be done at wave level
%a=0.95;
%frame2 = filter([1, -a], 1, frame);Mono
for j=1:frameSize:(length(d)-frameSize);
    k=k+1;
    frame2=d(j:j+frameSize-1);
% ====== Hamming windowing
    frame3=frame2.*hamming(frameSize);
% ====== FFT
[fftMag, fftPhase, fftFreq, fftPowerDb]=fftOneSide(frame3, fs);
% ====== Triangular band-pass filter bank
triFilterBankParam=getTriFilterBankParam(fs, filterNum);	% Get parameters for triangular band-pass filter bank
% Triangular bandpass filter.
    for i=1:filterNum
    	tbfCoef(i)=dot(fftPowerDb, trimf(fftFreq, triFilterBankParam(:,i)));
    end
% ====== DCT
    %mfcc=zeros(mfccNum, 1);
    for i=1:mfccNum
    	coef = cos((pi/filterNum)*i*((1:filterNum)-0.5))';
    	mfcc(i,k) = sum(coef.*tbfCoef');
    end
% ====== Log energy
%logEnergy=10*log10(sum(frame.*frame));
%mfcc=[logEnergy; mfcc];
end
%mfcc = beatavg(mel,bts);
if plotOpt
	subplot(2,1,1);
	plot(frame, '.-');
	set(gca, 'xlim', [-inf inf]);
	title('Input frame');
	subplot(2,1,2);
	plot(mfcc, '.-');
	set(gca, 'xlim', [-inf inf]);
	title('MFCC vector');
end

% ====== trimf.m (from fuzzy toolbox)
function y = trimf(x, params)
a = params(1); b = params(2); c = params(3);
y = zeros(size(x));
% Left and right shoulders (y = 0)
index = find(x <= a | c <= x);
y(index) = zeros(size(index));
% Left slope
if (a ~= b)
    index = find(a < x & x < b);
    y(index) = (x(index)-a)/(b-a);
end
% right slope
if (b ~= c)
    index = find(b < x & x < c);
    y(index) = (c-x(index))/(c-b);
end
% Center (y = 1)
index = find(x == b);
y(index) = ones(size(index));

function freq=getTriFilterBankParam(fs, filterNum, plotOpt)
% getTriFilterBankParam: Get the parameters of the triangular band-pass filter bank used in computing MFCC
%	Usage: freq=getTriFilterBankParam(fs, filterNum, plotOpt)

%	Roger Jang, 20060417

if nargin<1; selfdemo; return; end
if nargin<2, filterNum=20; end
if nargin<3, plotOpt=0; end

fLow=0;
fHigh=fs/2;
% Compute the frequencies of the triangular band-pass filters
for i=1:filterNum+2
	f(i)=mel2linFreq(lin2melFreq(fLow)+(i-1)*(lin2melFreq(fHigh)-lin2melFreq(fLow))/(filterNum+1));
end
freq=[];
for i=1:filterNum
	freq=[[f(i); f(i+1); f(i+2)], freq];
end

if plotOpt==1
	% Plot the triangular band-pass filters
	filter=[];
	for i=1:filterNum
		filter=[[0; 1; 0], filter];
	end
	subplot(2,1,1);
	plot(freq, filter);
	xlabel('Frequency (Hz)');
	title('Triangular filter bank');
	% Plot the normalized triangular band-pass filters
	filter=[];
	for i=1:filterNum
		filter=[[0; 2/(f(i+2)-f(i)); 0], filter];
	end
	subplot(2,1,2);
	plot(freq, filter);
	xlabel('Frequency (Hz)');
	title('Triangular filter bank (normalized)');
end

function linFreq=mel2linFreq(melFreq)
%mel2linFreq: Mel frequency to linear frequency conversoin

%	Roger Jang, 20020502

if nargin==0; selfdemo; return; end
linFreq=700*(exp(melFreq/1125)-1);			% melFreq=1125*ln(1+linFreq/700)

function melFreq=lin2melFreq(linFreq)
%lin2melFreq: Linear frequency to mel frequency conversion

%	Roger Jang, 20020502

if nargin==0; selfdemo; return; end
melFreq=1125*log(1+linFreq/700);
