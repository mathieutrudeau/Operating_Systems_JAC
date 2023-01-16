#!/bin/bash
set -euo pipefail

printf "\n"
printf "\n"
printf "\e[32mMemory Usage Statistics"
printf "\n"
printf "\e[39m-----------------------------------------------------------"
printf "\n"
printf "Ram Usage:"
printf "\n"
free -h
printf "\n"
printf "\e[39m-----------------------------------------------------------"
printf "\n"

physicalMemoryTot=$(free -k | awk '{print $2;}' | sed '2q;d'| numfmt --g) 
physicalMemoryUse=$(free -k | awk '{print $3;}' | sed '2q;d'| numfmt --g)

freeMemory=$(cat /proc/meminfo | egrep '^MemFree:' | awk '{print $2}')
totalMemory=$(cat /proc/meminfo | egrep '^MemTotal:' | awk '{print $2}')
buffers=$(cat /proc/meminfo | egrep '^Buffers:' | awk '{print $2}')
swapFree=$(cat /proc/meminfo | egrep '^SwapFree:' | awk '{print $2}')

freePhysicalMem=$( echo "scale=2 ; (100*($freeMemory+$buffers)/$totalMemory)"|bc)

swapMemoryTot=$(free -k | awk '{print $2;}' | sed '3q;d'| numfmt --g)
memoryTot=$(($(free -k | awk '{print $2;}' | sed '2q;d')+$(free -k | awk '{print $2;}' | sed '3q;d')))

freeMem=$(bc <<< "scale=2 ; (100*($freeMemory+$swapFree+$buffers)/($memoryTot))")

hardPFault=$(ps -eo cmd  --sort=maj_flt | tail -1 | awk '{print $1 " " $2;}')

user=$(whoami)

memoryTot=$(echo $memoryTot | numfmt --g)

printf "%-63s %0s" "Total physical memory:" "$physicalMemoryTot KB"
printf "\n"
printf "%-63s %0s" "Physical memory in use:" "$physicalMemoryUse KB"
printf "\n"
printf "%-63s %0s" "Free physical memory ('free' + available buffers):" "$freePhysicalMem%"
printf "\n"
printf "%-63s %0s" "Total swap memory:" "$swapMemoryTot KB"
printf "\n"
printf "%-63s %0s" "Total memory:" "$memoryTot KB"
printf "\n"
printf "%-63s %0s" "free total memory ('free' + available buffers):" "$freeMem%"
printf "\n"
printf "%-63s %0s" "Most frequently (hard) page-faulting process:" "$hardPFault"
printf "\n"
printf "%-63s %0s" "Current user (whoami):" "$user"
printf "\n"
printf "\n"
printf "\e[32mMemory Usage Statics"
printf "\n"
printf "\e[39m-----------------------------------------------------------"
printf "\n"
printf "%0s" "see http://stackoverflow.com/questions/22372960/is-this-explanation-about-vss-rss-pss-uss-accurately"
printf "\n"
printf "\n"

rss=$(smem -u | awk '{print $6;}'| sed '2q;d;')
pss=$(smem -u | awk '{print $5;}'| sed '2q;d')

savedMem=$(echo $((rss-pss))|numfmt --g)

rss=$(echo "$rss" | numfmt --g)
pss=$(echo "$pss" | numfmt --g)
uss=$(smem -u | awk '{print $4}' | sed '2q;d' | numfmt --g)

path=$(smem -m | grep '^/usr/lib' | sort -n -k 2 -r | sed '1d;q'|awk '{print $1;}')

numTimes=$(smem -m | grep '^/usr/lib' | sort -n -k 2 -r | sed '1d;q'|awk '{print $2;}')

printf "%-63s %0s" "Memory use by current user (RSS):" "$rss KB"
printf "\n"
printf "%-63s %0s" "Memory use by current user (PSS):" "$pss KB"
printf "\n"
printf "%-63s %0s" "Memory saved by implementing shared memory (current user):" "$savedMem KB"
printf "\n"
printf "%-63s %0s" "Memory returned to the system when the user logs out:" "$uss KB"
printf "\n"
printf "%-63s %0s" "Most used shared library:" "$path ($numTimes times)"
printf "\n"
printf "\n"
printf "\n"


exit
