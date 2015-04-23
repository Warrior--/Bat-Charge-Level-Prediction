function userBatSeq = cleanData(userBatSeq, iterations, duplicate, Dataset)
%This function does pre-processing on the set of input records as follow:
%{
1- Replaces charging status by 0 or 1 depending on previous rows and
columns and the time between the records

%}

%% Remove duplicate records
windowSize = 40;
for j=1:iterations
    seq = 1:windowSize:size(userBatSeq, 1);
    seq = [seq, seq(end)+mod(size(userBatSeq, 1), windowSize)-1]; %To account for the remaining rows of data that do not belong to the last interval in "seq"
    if(seq(end) == seq(end-1))
       seq = seq(1:end-1); 
    end
    for i=1:length(seq)-1
       [cleanedRecords, ~, ~] = unique(userBatSeq(seq(i):seq(i+1), :), 'rows', 'stable');
       if(length(cleanedRecords(:, 1)) ~= length(userBatSeq(seq(i):seq(i+1), 1)))
           difference = length(userBatSeq(seq(i):seq(i+1), 1)) - length(cleanedRecords(:, 1));
           if(seq(i) == 1)
               userBatSeq(1:seq(i+1), :) = [];
               userBatSeq = [cleanedRecords; userBatSeq];
           else
    %            tempData = userBatSeq(1:seq(i)-1, :);
               userBatSeq = [userBatSeq(1:seq(i)-1, :); cleanedRecords; userBatSeq(seq(i+1)+1:end, :)];

           end
           seq(i+1:end) = seq(i+1:end) - difference;
       end
%        i = i + 1;
    end
end
clear cleanedRecords seq windowSize difference

if(duplicate == true)
   return; 
end

%% Number the days for which data has been recorded
%This piece of code numbers the days in which data has been recorded.
%{
Check the possibility of not recording any data for more than two days. If
there are more than one day of data not recorded then the following
algorithm will fail to do its job
%}
dayNum = 1;
flag = 0;
days = ones(length(userBatSeq(:, 1)), 1);
i = 2;
% for i=2:length(userBatSeq(:, 1))
while(i <= length(userBatSeq(:, 1)))
    time1 = userBatSeq(i-1, 1) * 60 + userBatSeq(i - 1, 2);
    time2 = userBatSeq(i, 1) * 60 + userBatSeq(i, 2);
    if(abs(userBatSeq(i - 1, 5) - userBatSeq(i, 5)) >= 4)
        for j=i+1:min(i+6, length(userBatSeq(:, 1)))
            tempTime = userBatSeq(j, 1) * 60 + userBatSeq(j, 2);
           if(abs(userBatSeq(i - 1, 5) - userBatSeq(j, 5)) >= 4 || tempTime < time1)
%               flag = 1;
           end
           if(abs(userBatSeq(i - 1, 5) - userBatSeq(j, 5)) > 4)
              flag = 1;
           elseif(abs(tempTime - time1) <= 10 && abs(userBatSeq(i - 1, 5) - userBatSeq(j, 5)) <= 4)
               userBatSeq = [userBatSeq(1:i-1, :); userBatSeq(j:end, :)];
               days = [days(1:i-1, :); days(j:end, :)];
               flag = 0;
               break;
           end
        end
        if(flag == 1)
            tempTime = userBatSeq(i + 1, 1) * 60 + userBatSeq(j, 2);
            if(round(std(userBatSeq(i-1:min(i+5, length(userBatSeq(:, 1))), 5))) <= 5 || time2 >= time1)
                flag = 0;
            end
            if(round(std(userBatSeq(i-1:min(i+5, length(userBatSeq(:, 1))), 5))) <= 5 || tempTime >= time1)
%                 flag = 0;
            end
        end
    end
    if(time1 > time2 || flag == 1)
        dayNum = dayNum + 1;
    end
    if(dayNum == 66)
        
    end
    flag = 0;

    days(i) = dayNum;
    i = i + 1;
end

userBatSeq = [days, userBatSeq];
clear dayNum days

%% This part deals with disconnectivy issues of charger/socket causing 0s and 1 repeat for the "being charged" attribute
i = 1;
zeroIndex = 0;
while(i <= length(userBatSeq(:, 1))-1)
    
    if(userBatSeq(i, 7) == 1 && userBatSeq(i, 7) ~= userBatSeq(i + 1, 7)) 
        for j=i+1:min(i+5, size(userBatSeq, 1)-1) %Go over the next 5 records
            if(userBatSeq(j, 7) ~= userBatSeq(j + 1, 7)) %This condition will not be met until the "being charged" attribute changes to a new value (goes from being discharged to being charged and vice versa)
                dayDiff2 = double(userBatSeq(i + 1, 1)) - double(userBatSeq(i, 1));
                timeDiff2 = ((dayDiff2 * 24 + double(userBatSeq(j + 1, 2))) * 60 + double(userBatSeq(j + 1, 3))) - (double(userBatSeq(i + 1, 2)) * 60 + double(userBatSeq(i + 1, 3))); % In minutes
                chargeLvlDiff2 = userBatSeq(j + 1, 6) - userBatSeq(i + 1, 6);
                if(timeDiff2 <= 1 && chargeLvlDiff2 <= 1)
                    userBatSeq(i+1:j, 7) = userBatSeq(i, 7);
                    userBatSeq(i+1:j, 4) = userBatSeq(i, 4);
                    i = i - 2;
                    if(i <= 0)
                        i = 1;
                        zeroIndex = 1;
                    end
                    break;
                elseif(timeDiff2 > 1  && timeDiff2 <= 4 && chargeLvlDiff2 <= 1)
                    if(userBatSeq(i, 7) == userBatSeq(j + 1, 7))
                        userBatSeq(i + 1:j, 7) = userBatSeq(i, 7);
                        userBatSeq(i + 1:j, 4) = userBatSeq(i, 4);
                    end
                end
            end
        end
    end

    if(userBatSeq(i, 4) == 1 && userBatSeq(i, 7) == 0) %If the "fully charged" attribute was set to 1 incorrectly although the phone has not been charged
       userBatSeq(i, 4) = 0; 
    end
    if(zeroIndex == 0)
        i = i + 1;
    else
        i = 1;
        zeroIndex = 0;
    end
end
clear timeDiff2 chargeLvlDiff2 dayDiff2

%% Find any abnormal change in the battery charge level and fix them

abnorms1 = []; %Stores indices of records showing a sign of phone shut down/die out
abnorms2 = []; %
abnorms3 = [];
abnorms4 = []; %Stores indices of records for when the charge level increases without the phone being charged
abnorms5 = [];
zeroIndex = 0;
% for i=1:length(userBatSeq(:, 1))-1
i = 1;

%battery charge levels must not be averaged if the phone is fully charged

%battery charge levels must be averaged if there are more records of phone charging after

%battery charge level must be adjusted if there are more records of phone
%charging after (exeption for the time that the battery charge level
%decreases and does not increase to the charge level before starting to
%decrease)
while(i <= length(userBatSeq(:, 1))-1)
    dayDiff = double(userBatSeq(i + 1, 1)) - double(userBatSeq(i, 1));
    timeDiff = ((dayDiff * 24 + double(userBatSeq(i + 1, 2))) * 60 + double(userBatSeq(i + 1, 3))) - (double(userBatSeq(i, 2)) * 60 + double(userBatSeq(i, 3))); % In minutes
    chargeLvlDiff = userBatSeq(i, 6) - userBatSeq(i + 1, 6);
    
    
    %This section merges records having the same battery charge level when
    %the phone is being charged)
    if(chargeLvlDiff == 0 && userBatSeq(i, 7) == 1 && userBatSeq(i + 1, 7) == 1 && userBatSeq(i, 4) == userBatSeq(i + 1, 4) && timeDiff <= 15)
       firstIndex= i + 1;
       tempIndex = firstIndex;
       lastIndex = min(i+5, size(userBatSeq, 1) - 4); %initial assignment
       while(tempIndex <= size(userBatSeq, 1) - 1)
           if(userBatSeq(tempIndex, 6) ~= userBatSeq(i, 6) || userBatSeq(tempIndex, 4) ~= userBatSeq(i, 4) || tempIndex >= length(userBatSeq(:, 1)))
               lastIndex = tempIndex;
              break;
           end
           tempIndex = tempIndex + 1;
       end
      for j=firstIndex:lastIndex %Check the next records having the same charge level
          if(userBatSeq(j, 6) ~= userBatSeq(i, 6) || userBatSeq(j, 4) ~= userBatSeq(i, 4)) %When encountered a new charge level or the phone is "fully charged"
            %% This part computes a new time stamp to be used for the time stamp of the new record to be replaced with all continuous records having the same battery charge level
            dayDiff2 = double(userBatSeq(j - 1, 1)) - double(userBatSeq(i, 1));
            timeDiff2 = ((dayDiff2 * 24 + double(userBatSeq(j - 1, 2))) * 60 + double(userBatSeq(j - 1, 3))) - (double(userBatSeq(i, 2)) * 60 + double(userBatSeq(i, 3))); % In minutes
            timeDiff2 = timeDiff2 / 2;
            tempMin = userBatSeq(i, 3) + timeDiff2;
            if(tempMin >= 60)
                tempHour = userBatSeq(i, 2) + floor(tempMin/60);
                tempMin = mod(tempMin, 60);
                if(tempHour >= 24)
                   tempDay = userBatSeq(i, 1) + floor(tempHour/24);
                   tempHour = mod(tempHour, 24);
                else
                    tempDay = userBatSeq(i, 1);
                end
            else
                tempHour = userBatSeq(i, 2);
                tempDay = userBatSeq(i, 1);
            end
            userBatSeq = [userBatSeq(1:i-1, :); tempDay, tempHour, tempMin, userBatSeq(i, 4), mean(userBatSeq(i:j-1, 5)), userBatSeq(i, 6), userBatSeq(i, 7); userBatSeq(j:end, :)];
            i = max(1, i - 1);
            if(i - 1 <= 0)
                i = 1;
                zeroIndex = 1; 
            end
            break;
          end
       end
    end
    
    
    %Detects when the battery charge level increases (due to noise) when the phone is not being charged
    chargeLvlDiff = userBatSeq(i, 6) - userBatSeq(i + 1, 6);
    if(i <= size(userBatSeq, 1)-1 && chargeLvlDiff < 0 && chargeLvlDiff >= -1 && userBatSeq(i, 7) == 0 && userBatSeq(i + 1, 7) == 0) %The 2nd condition (chargeLvlDiff >= -1) is there because sometimes the phone turns off and the difference between two consecutive records will be more than 2 percent (-2%) when the phone is turned back on
        userBatSeq(i, 6) = userBatSeq(i + 1, 6); %Replace it with the next record's battery charge level
        i = max(1, i - 2);
        if(i - 1 <= 0)
            i = 1;
            zeroIndex = 1; 
        end
    end
    
    %Merges all back to back records having the same battery charge levels
    chargeLvlDiff = userBatSeq(i, 6) - userBatSeq(i + 1, 6);
    if(chargeLvlDiff == 0 && userBatSeq(i, 7) == 0 && userBatSeq(i + 1, 7) == 0 && userBatSeq(i, 4) == userBatSeq(i + 1, 4) && timeDiff <= 120)
       firstIndex= i + 1;
       tempIndex = firstIndex;
       lastIndex = min(i+5, size(userBatSeq, 1) - 4); %initial assignment
       while(tempIndex <= size(userBatSeq, 1))
           if(userBatSeq(tempIndex, 6) ~= userBatSeq(i, 6) || userBatSeq(i, 7) ~= userBatSeq(tempIndex, 7) || tempIndex >= length(userBatSeq(:, 1)))
               if(tempIndex < length(userBatSeq(:, 1)))
                   lastIndex = tempIndex - 1;
               else
                   lastIndex = tempIndex;
               end
              break;
           end
           tempIndex = tempIndex + 1;
       end
        %% This code snippet computes a new time stamp to be used for the time stamp of the new record to be replaced with all continuous records having the same battery charge level
        abnorms3 = [abnorms3; i];
        dayDiff2 = double(userBatSeq(lastIndex, 1)) - double(userBatSeq(i, 1));
        timeDiff2 = ((dayDiff2 * 24 + double(userBatSeq(lastIndex, 2))) * 60 + double(userBatSeq(lastIndex, 3))) - (double(userBatSeq(i, 2)) * 60 + double(userBatSeq(i, 3))); % In minutes
        timeDiff2 = timeDiff2 / 2;
        tempMin = userBatSeq(i, 3) + timeDiff2;
        if(tempMin >= 60)
            tempHour = userBatSeq(i, 2) + floor(tempMin/60);
            tempMin = mod(tempMin, 60);
            if(tempHour >= 24)
               tempDay = userBatSeq(i, 1) + floor(tempHour/24);
               tempHour = mod(tempHour, 24);
            else
                tempDay = userBatSeq(i, 1);
            end
        else
            tempHour = userBatSeq(i, 2);
            tempDay = userBatSeq(i, 1);
        end
        fullyCharged = sum(userBatSeq(i:lastIndex, 4));
        userBatSeq = [userBatSeq(1:i-1, :); tempDay, tempHour, tempMin, fullyCharged >= (lastIndex - i + 1) / 2, mean(userBatSeq(i:lastIndex, 5)), userBatSeq(i, 6), userBatSeq(i, 7); userBatSeq(lastIndex + 1:end, :)];
        i = max(1, i - 1);
        if(i - 1 <= 0)
            i = 1;
            zeroIndex = 1; 
        end
    end
    
    chargeLvlDiff = userBatSeq(i, 6) - userBatSeq(i + 1, 6);
    if(timeDiff == 0 && chargeLvlDiff == 0 && userBatSeq(i, 7) == userBatSeq(i + 1, 7))
        if(userBatSeq(i, :) == userBatSeq(i + 1, :)) %remove the record if it is identical to the next one(detection of the noise related to "fully charged" attribute above may have made the rows identical)
            userBatSeq(i + 1, :) = [];
            i = max(1, i - 1);
            if(i - 1 <= 0)
                i = 1;
                zeroIndex = 1; 
            end
        elseif(userBatSeq(i, 4) == 1 && userBatSeq(i, 7) == 0 && userBatSeq(i + 1, 4) == 0) %When the phone is unplugged and the "fully charged" attribute is still set to 1 (which should be zero)
            userBatSeq(i, :) = [];
            i = max(1, i - 1);
            if(i - 1 <= 0)
                i = 1;
                zeroIndex = 1; 
            end
        elseif(size(find(userBatSeq(i, :) == userBatSeq(i + 1, :) == 0), 2) == 1 && find(userBatSeq(i, :) == userBatSeq(i + 1, :) == 0) == 5) %only the temperature has changed
            userBatSeq(i, :) = [];
            i = max(1, i - 1);
            if(i - 1 <= 0)
                i = 1;
                zeroIndex = 1; 
            end
        end
    end
    
    
    %{
        This code snippet clears out the charge level jumping up noise occured in
        the data. For instance, the charge level may go up to 69 and then 
        decrease to 66 from 47 all of the sudden in just 5 minutes and 
        without the phone plugged into charge. Then the charge level may go
        down to 46 in, say, 40 minutes. Clearly the true charge level has 
        been 47 at the beginning and the records in between must be removed.
    %}
    chargeLvlDiff = userBatSeq(i, 6) - userBatSeq(i + 1, 6);
    if(i < length(userBatSeq(:, 1)) -2 && chargeLvlDiff < 0 && (userBatSeq(i, 7) | userBatSeq(i + 1, 7)) == 0)
       firstIndex= i + 1;
       tempIndex = firstIndex;
       lastIndex = firstIndex; %initial assignment
       while(tempIndex <= min(i+6, size(userBatSeq, 1) - 4))
            dayDiff2 = double(userBatSeq(tempIndex + 1, 1)) - double(userBatSeq(i, 1));
            timeDiff2 = ((dayDiff2 * 24 + double(userBatSeq(tempIndex + 1, 2))) * 60 + double(userBatSeq(tempIndex + 1, 3))) - (double(userBatSeq(i, 2)) * 60 + double(userBatSeq(i, 3))); % In minutes
            chargeLvlDiff2 = userBatSeq(i, 6) - userBatSeq(tempIndex + 1, 6);
           if(userBatSeq(tempIndex + 1, 7) == userBatSeq(i, 7) && chargeLvlDiff2 >= 0 && chargeLvlDiff2 < 6 && timeDiff2 < 60 + abs(round(normrnd(5, .4))))
               lastIndex = tempIndex + 1;
              break;
           end
           tempIndex = tempIndex + 1;
       end
       userBatSeq = [userBatSeq(1:i, :); userBatSeq(lastIndex:end, :)];
       i = max(1, i - (lastIndex - firstIndex - 1));
       if(i - (lastIndex - firstIndex - 1) <= 0)
          i = 1;
          zeroIndex = 1; 
       end
    end
    
    %{
        This code snippet clears out the charge level jumping down noise occured in
        the data. For instance, the charge level may go down to 35 and then 
        decrease to 34 from 69 all of the sudden in a relatively short time and 
        without the phone plugged into charge. Then the charge level may go
        down to 68 in, say, 40 minutes. Clearly the true charge level has 
        been 69 at the beginning and the records in between must be removed.
    %}
    chargeLvlDiff = userBatSeq(i, 6) - userBatSeq(i + 1, 6);
    if(i < length(userBatSeq(:, 1)) -2 && chargeLvlDiff > 3 && timeDiff <= 120)
       firstIndex= i + 1;
       tempIndex = firstIndex;
       lastIndex = firstIndex; %initial assignment
       if(userBatSeq(tempIndex, 7) == 1)
            dayDiff2 = double(userBatSeq(tempIndex + 1, 1)) - double(userBatSeq(i, 1));
            timeDiff2 = ((dayDiff2 * 24 + double(userBatSeq(tempIndex + 1, 2))) * 60 + double(userBatSeq(tempIndex + 1, 3))) - (double(userBatSeq(i, 2)) * 60 + double(userBatSeq(i, 3))); % In minutes
            if(userBatSeq(tempIndex + 1, 7) == 0 && timeDiff2 <= 2)
               userBatSeq(tempIndex, 7) = 0; 
            end
       end
        if((userBatSeq(i, 7) | userBatSeq(i + 1, 7)) == 0)
           while(tempIndex <= min(i+6, size(userBatSeq, 1) - 1))
                dayDiff2 = double(userBatSeq(tempIndex + 1, 1)) - double(userBatSeq(i, 1));
                timeDiff2 = ((dayDiff2 * 24 + double(userBatSeq(tempIndex + 1, 2))) * 60 + double(userBatSeq(tempIndex + 1, 3))) - (double(userBatSeq(i, 2)) * 60 + double(userBatSeq(i, 3))); % In minutes
                chargeLvlDiff2 = userBatSeq(i, 6) - userBatSeq(tempIndex + 1, 6);
                chargeLvlDiff = userBatSeq(tempIndex, 6) - userBatSeq(tempIndex + 1, 6);
               if(userBatSeq(tempIndex + 1, 7) == userBatSeq(i, 7) && chargeLvlDiff < 0 && chargeLvlDiff2 <= 4 && chargeLvlDiff2 > 0 && timeDiff2 < 105 + abs(round(normrnd(5, .4))))
                   lastIndex = tempIndex + 1;
                  break;
               elseif(userBatSeq(tempIndex + 1, 7) ~= userBatSeq(i, 7))
%                    lastIndex = i;
%                    break;
               end
               tempIndex = tempIndex + 1;
           end
           userBatSeq = [userBatSeq(1:i, :); userBatSeq(lastIndex:end, :)];
           if(lastIndex ~= firstIndex)
               i = max(1, i - 1);
           end
           if(i - 1 <= 0)
              i = 1;
              zeroIndex = 1; 
           end
           
        else
            while(tempIndex <= min(i+6, size(userBatSeq, 1) - 1))
                dayDiff2 = double(userBatSeq(tempIndex + 1, 1)) - double(userBatSeq(i, 1));
                timeDiff2 = ((dayDiff2 * 24 + double(userBatSeq(tempIndex + 1, 2))) * 60 + double(userBatSeq(tempIndex + 1, 3))) - (double(userBatSeq(i, 2)) * 60 + double(userBatSeq(i, 3))); % In minutes
                chargeLvlDiff2 = userBatSeq(i, 6) - userBatSeq(tempIndex + 1, 6);
                chargeLvlDiff = userBatSeq(tempIndex, 6) - userBatSeq(tempIndex + 1, 6);
               if(userBatSeq(tempIndex + 1, 7) == userBatSeq(i, 7) && chargeLvlDiff < 0 && chargeLvlDiff2 <= 0 && chargeLvlDiff2 >= -3 && timeDiff2 < 40 + abs(round(normrnd(5, .4))))
                   lastIndex = tempIndex + 1;
                  break;
               elseif(userBatSeq(tempIndex + 1, 7) ~= userBatSeq(i, 7))
%                    lastIndex = i;
%                    break;
               end
               tempIndex = tempIndex + 1;
           end
           userBatSeq = [userBatSeq(1:i, :); userBatSeq(lastIndex:end, :)];
           if(lastIndex ~= firstIndex)
               i = max(1, i - 1);
           end
           if(i - 1 <= 0)
              i = 1;
              zeroIndex = 1; 
           end
        end
    end

    
    %Detect when the charger is plugged into the phone for a very short
    %period (maybe even less than 10 seconds)
    chargeLvlDiff2 = userBatSeq(i, 6) - userBatSeq(min(i + 2, length(userBatSeq(:, 1))), 6);
    dayDiff2 = double(userBatSeq(min(i + 2, length(userBatSeq(:, 1))), 1)) - double(userBatSeq(i, 1));
    timeDiff2 = ((dayDiff2 * 24 + double(userBatSeq(min(i + 2, length(userBatSeq(:, 1))), 2))) * 60 + double(userBatSeq(min(i + 2, length(userBatSeq(:, 1))), 3))) - (double(userBatSeq(i, 2)) * 60 + double(userBatSeq(i, 3))); % In minutes
    if(i <= length(userBatSeq(:, 1)) && abs(chargeLvlDiff2) <= 2 && timeDiff2 <= 120 && userBatSeq(i, 7) ~= userBatSeq(min(i + 1, size(userBatSeq, 1)), 7) && userBatSeq(i, 7) == userBatSeq(min(i + 2, size(userBatSeq, 1)), 7))
        userBatSeq(i + 1, 7) = userBatSeq(i, 7);
        i = i - 1;
        if(i <= 0)
            i = 1;
            zeroIndex = 1;
        end
    end

    if(zeroIndex == 0)
        i = i + 1;
    else
        i = 1;
        zeroIndex = 0;
    end
    if(i >= 7468)
        
    end
end

% userBatSeq = cleanData(userBatSeq, 2, true);

clear abnorms1 abnorms2 dayDiff timeDiff chargeLvlDiff timeDiff2 chargeLvlDiff2 dayDiff2 tempDay tempHour tempMin i j firstIndex lastIndex maxCharge fullyChargedStat flag tempTime


end