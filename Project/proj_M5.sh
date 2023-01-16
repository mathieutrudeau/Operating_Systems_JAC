#!/bin/bash
set +euo pipefail



function Process_Logins(){
    
    
    local names=($(cat /etc/passwd | awk -F ":" '{print $5 " -"}' | sed '1,26d')) # get list of names
    local studentIDs=($(cat /etc/passwd | awk -F ":" '{print $1}'| sed '1,26d')) # get list of student id
    

    local nIndex=0      # keeps track of current student

    for (( i=0; i < ${#studentIDs[@]}; i++ )); do           # Process all students
        set -euo pipefail
        printf "%0s" "Processing "
        printf "\e[32m"
        set +euo pipefail
        # Show student name
        while [ "${names[$nIndex]}" != "-" ]; do 
            printf "%0s" "${names[$nIndex]} "
            ((nIndex++))
        done
        ((nIndex++))
        set -euo pipefail

        #Show student ID
        printf "\e[39m"
        printf "%0s" "(${studentIDs[$i]}), "

        set +euo pipefail
        # Fetch ALL logins for that student 
        local allLogins=($(last -f /var/log/wtmp-20190502 -F | grep $(echo ${studentIDs[$i]}) | grep -v 'crash' | grep -v 'still logged in' | awk '{print $4 " " $5 " " $6 " " $7 " " $8 " " $9 " " $10 " " $11 " " $12 " " $13 " " $14 " "w $15}'))  
        set -euo pipefail

        #Start and end time of individual logins
        local currStartTime=0
        local currEndTime=0
        #start and end time of session
        local sessionStartTime=0
        local sessionEndTime=0
        #total session time
        local totalTime=0
        # Logins that overlap
        local combinedLogins=0

        set +euo pipefail
        # Number of valid logins found
        local sessionsNum=$(last -F | grep $(echo ${studentIDs[$i]})| grep -v 'crash' | grep -v 'still logged in'  | wc -l)
        set -euo pipefail

        # Total time that a student was logged on.
        local sessionTime=0
        # Go to next login
        local jumpVal=12
        
        # That student never logged in.
        if [ $sessionsNum -eq 0 ]; then
            printf "%0s" "found 0 logins"
            printf "\n"
            continue
        fi

        
        # Inspect all logins
        for (( a=0; a < ${#allLogins[@]}; a+=$jumpVal ));do
            
            currStartTime=$(date -d "${allLogins[$a]}, ${allLogins[$a+2]} ${allLogins[$a+1]} ${allLogins[$a+4]} ${allLogins[$a+3]}" +%s)
            currEndTime=$(date -d "${allLogins[$a+6]}, ${allLogins[$a+8]} ${allLogins[$a+7]} ${allLogins[$a+10]} ${allLogins[$a+9]}" +%s)
            set +euo pipefail    
            if [ $sessionStartTime -eq 0 ]; then    # Starting a new session. 
                sessionStartTime=$currStartTime
                sessionEndTime=$currEndTime
            elif [ $currEndTime -lt $sessionStartTime ]; then       # Session is over. Move to a new session.
                sessionTime=$sessionEndTime-$sessionStartTime
                ((totalTime+=sessionTime))
                sessionStartTime=$currStartTime
                sessionEndTime=$currEndTime
                ((combinedLogins++))
            else                                                    # Extend session start or end time.
                if [ $currStartTime -lt $sessionStartTime ]; then   
                    sessionStartTime=$currStartTime
                fi
                if [ $currEndTime -gt $sessionEndTime ]; then
                    sessionEndTime=$currEndTime
                fi
            fi
            set -euo pipefail
        done

        # Show logins found + combined logins (sessions).
        printf "%0s" "found $sessionsNum logins "
        printf "%0s" "(combined $combinedLogins logins)."
            
        # Deternmine hours and minutes from total time in seconds. 
        local hours=0
        local minutes=0

        set +euo pipefail
        ((hours=(totalTime-(totalTime%3600))/3600))
        ((minutes=((totalTime%3600)-((totalTime%3600)%60))/60))

        # Remove 10 hours for classtime
        ((hours-=10))
        set -euo pipefail

        # Add left 0 to format: ex. 04 vs 4
        if [ $minutes -lt 10 ]; then
            minutes="0$minutes"
        fi

        # Show total logged in time.
        printf "%0s" "  Total logged in time ("
        printf "\e[32m"
        printf "%0s" "$hours"
        printf "\e[39m"
        printf ":\e[32m"
        printf "%0s" "$minutes"
        printf "\e[39m)"
        printf "\n"
    done
}

Process_Logins

exit








