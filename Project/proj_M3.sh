#!/bin/bash
#set-euo pipefail


isRunning=0
pid=0
ts=0
pStart=0
pEnd=0
pTotal=0

# Kill process when ctrl-c is pressed
function kill_Processes(){
    pEnd=$(date +%s)
    ((pTotal=pEnd-pStart))
    kill $pid
    user=$(whoami)
    printf "\n"
    printf "%0s" "(killed by $user after $pTotal seconds running)"
    printf "\n"
    exit
}

trap kill_Processes SIGINT SIGTERM

# Monitor process
function process_Monitor(){

    local isRunning=0
    local pid=0
    local ts=0  #timestamp (ts)
    local pStart=0
    local pEnd=0
    local pTotal=0

    while : 
    do
        if [ $isRunning -eq 0 ]; then
            ts=$(date +"%d/%m/%Y %H:%M:%S") #timestamp
            printf "%0s" "$ts: "
            printf "no running instance of ./randomDie.sh found"
            printf "\n"
            printf "%0s" "$ts: "
            printf "Re-spawning ./randomDie.sh, "
            ./randomDie.sh &
            pid=($(jobs -l))
            pid=${pid[1]}
            printf "%0s" "pid: $pid, DONE!"
            pStart=$(date +%s) #timestamp start
            isRunning=1
        else
            local process=($(ps -au | grep '$(echo $pid)' | grep 'S+'))
            if [ ${#process[@]} -ne 0 ]; then
                ts=$(date +"%d/%m/%Y %H:%M:%S") #timestamp
                printf "%0s" "$ts: pid $pid found, ./randomDie.sh still running"
                printf "\n"
                printf "%0s" "$ts: pid $pid performance stats: using ${process[2]}% of system CPU"
                printf "\n"
                printf "%0s" "$ts: pid $pid performance stats: using ${process[3]}% of system memory"
                printf "\n"
                wait $pid
                local errorCode=$?
                ts=$(date +"%d/%m/%Y %H:%M:%S") #timestamp
                printf "%0s" "$ts: pid $pid just died with error: $errorCode"
                isRunning=0
            else
                isRunning=0
            fi
        fi
        printf "\n"
        ts=$(date +"%d/%m/%Y %H:%M:%S") #timestamp
        printf "%0s" "$ts: "
        printf "%0s" "checking health of pid #$pid"
        printf "\n"
    done
}



process_Monitor
