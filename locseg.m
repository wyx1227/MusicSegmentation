function [chorus, seggroup, scoretab] = locseg(bimar, index, bts, sdmar, mono, fs, debug)
%LOCSEG Locate interesting segmengs(which is likely to contain the
%chorus). A heuristic scoring method is adoptted to find the most likely
%segment.
%   bimar - binarized matrix
%   index - index for the diagonals
%   bts - beat for measuring time
%   debug - 0 for nothing, 1 for remove close segments, 2 for adding score 6,
%   3 for adding score 3, 4 for add both score 3 and score 6

if nargin < 7
    debug = 0;
end

chorus = zeros(1,4);
%find all the segments longer than 4s
count = 0;
segflg = 0;
for i = 1:length(index)
    temp = diag(bimar, -index(i));
    for j = 1:length(temp)
        %the beginning of one segment
        if temp(j) == 1 && segflg == 0
            chorus(1) = index(i)+j;
            chorus(2) = j;
            segflg = 1;
            continue;
        end
        %the end of one segment
        if temp(j) == 0 && segflg == 1
            chorus(3) = index(i)+j;
            chorus(4) = j;
            %determine whether this segment is longer than 4s
            if bts(chorus(3))-bts(chorus(1)) >= 4 && bts(chorus(4))-bts(chorus(2)) >= 4
                if count == 0
                    seggroup = chorus;
                else
                    seggroup = [seggroup;chorus];
                end
                count = count+1;
            end
            segflg = 0;
            continue;
        end
    end
end

if debug == 1
    %for each diagonal segment found in the binarized matrix, the method
    %looks for diagonal segments which are located close to it.
    clostab = zeros(count, count+2);
    for i = 1:count
        closrec = 3;
        for j = 1:count
            if i == j
                continue;
            end
            if seggroup(j,1)>=seggroup(i,1)-5 && seggroup(j,3)<=seggroup(i,3)+20 && abs(seggroup(j,2)-seggroup(i,2))<=20 && seggroup(j,4)<=seggroup(i,4)+5
                clostab(i,1) = clostab(i,1)+1;
                clostab(j,2) = clostab(j,2)+1;
                clostab(i,closrec) = j;
                closrec = closrec+1;
            end
        end
    end
    %Remove the extra segments
    %current not considering
end

%scoring scheme
scoretab = zeros(count,1);

%prework for 4th score
mono2 = (mono.^2);
aven = mean(mono2);
avedis = mean(mean(sdmar));

%prework for 5th score
if debug == 2 || debug == 4
    occurnum = zeros(count, 1);
    for i = 1:count
        for j = 1:count
            if j == i
                continue;
            elseif abs(seggroup(i,2)-seggroup(j,2))<=0.2*abs(seggroup(j,2)-seggroup(j,4)) && abs(seggroup(i,4)-seggroup(j,4))<=0.2*abs(seggroup(j,2)-seggroup(j,4))
                occurnum(i) = occurnum(i)+1;
            end
        end
    end
end

%prework for 2nd score
if debug == 3 || debug == 4
    %find the segment group - 3 segment with one locating under and one
    %locating right
    groupcount = 0;
    group = zeros(1,3);
    for i = 1:count
        for j = 1:count
            if j == i
                continue;
            elseif seggroup(j,1)>=seggroup(i,3) && ~(seggroup(i,4)<=seggroup(j,2)||seggroup(i,2)>=seggroup(j,4))
                for k = 1:count
                    if k == i || k == j
                        continue;
                    elseif ~(seggroup(j,3)<=seggroup(k,1)||seggroup(j,1)>=seggroup(k,3))
                        if groupcount == 0
                            group = [i,j,k];
                        else 
                            group = [group;i,j,k];
                        end
                    end
                end
            end
        end
    end
    [m,~] = size(group);
    sc3 = zeros(m,2);
    sc3(:,1) = group(:,2);
    for n = 1:m
        xb = seggroup(group(n,2),4)-seggroup(group(n,2),2);
        xu = seggroup(group(n,1),4)-seggroup(group(n,1),2);
        xr = seggroup(group(n,3),4)-seggroup(group(n,3),2);
        theta1 = 1-2*abs(seggroup(group(n,1),4)-seggroup(group(n,2),4))/(xb+xu);
        if seggroup(group(n,2),2)<seggroup(group(n,1),2)
            theta2 = 1-(seggroup(group(n,1),2)-seggroup(group(n,2),2))/xb;
        elseif seggroup(group(n,2),2)>=seggroup(group(n,1),4)
            theta2 = 1-(seggroup(group(n,2),2)-seggroup(group(n,1),4))/xb;
        else 
            theta2 = 1;
        end
        theta3 = 1-abs(xr-xb)/xb;
        theta4 = 1-2*min(abs(seggroup(group(n,2),1)-seggroup(group(n,3),1)),abs(seggroup(group(n,2),3)-seggroup(group(n,3),3)))/(xb+xr);
        theta = (theta1+theta2+theta3+theta4)/4;
        sc3(n,2) = theta;
    end
end

for i = 1:count
    %1st - position score
    s1 = 1-abs(seggroup(i,2)+0.5*(seggroup(i,3)-seggroup(i,1))-round(length(bts)/4))/(round(length(bts)/4));
    s2 = 1-abs(seggroup(i,1)+0.5*(seggroup(i,3)-seggroup(i,1))-round(3*length(bts)/4))/(round(length(bts)/4));
    %2nd - relation to other repetitions
    if debug == 3 || debug == 4
        if isempty(find(sc3(:,1)==i))
             s3 = 0;
        else 
            s3 = max(sc3(find(sc3(:,1)==i),2));
        end
    else
        s3 = 0;
    end
    
    %3rd - average energy
    s4 = avenergy(mono2, aven, fs, bts, seggroup, i);
    %4th - average distance
    s5 = distsc(avedis, sdmar, seggroup, i);
    %5th - number of times the repetition occurs
    if debug == 2 || debug == 4
        s6 = occurnum(i)/max(occurnum);
    else
        s6 = 0;
    end
    %fprintf('The %d th segment:\n', i);
    %fprintf('s1:%.2d, s2:%.2d, s3:%.2d, s4:%.2d, s5:%.2d, s6:%.2d,',s1,s2,s3,s4,s5,s6);
    scoretab(i) = 0.5*(s1+s2+s4+s6)+s3+s5;
    %fprintf('s:%.2d\n',scoretab(i));    
end

%the segment with the most score be considered for chorus
chorus = seggroup(scoretab == max(scoretab),:);
end

