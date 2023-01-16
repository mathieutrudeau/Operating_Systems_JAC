#!/bin/bash
set -euo pipefail


dnsServer=$(cat /etc/resolv.conf | tail -1 | awk '{print $2}')
host=$(hostname)

set +euo pipefail
pingG=$(ping google.com -c 2 | wc -l)
if [ $pingG -eq 7 ]; then
    connectStatus="Connected"
else
    connectStatus="Disconnected"
fi



uptimeDays=$(uptime | awk '{print $3 " " $4}' | awk -F "," '{print $1}')
intIP=$(ifconfig | egrep 'inet [0-9].{2}[0-9].{2}[0-9].{1}[0-9].{2}' | awk '{print $2}')

loggedInUsers=($(who | awk '{print $1}' | sort | uniq)) # users logged

set +euo pipefail
waitQueue=$(ps -ax -o state | grep '^D$' | wc -l) #wait queue
readyQueue=$(ps -ax -o state | grep '^R$' | wc -l) #ready queue
set -euo pipefail

diskUsage=($(df -h | egrep '/boot$')) # disk usage
loadAVG=$(uptime | awk -F ":" '{print $5}' | awk -F " " '{print $3}') #load average


printf "\e[32m"
printf "%-60s" "Internet:"
printf "\e[39m"
printf "%0s" " $connectStatus"
printf "\n"
printf "\e[32m"
printf "%-60s" "Hostname:"
printf "\e[39m"
printf "%0s" " $host"
printf "\n"
printf "\e[32m"
printf "%-60s" "Private IP Address (internal):"
printf "\e[39m"
printf "%0s" " $intIP"
printf "\n"
printf "\e[32m"
printf "%-60s" "Public IP Address (external):"
printf "\e[39m "
curl http://ipecho.net/plain
printf "\n"
printf "\e[32m"
printf "%-60s" "DNS Server(s):"
printf "\e[39m"
printf "%0s" " $dnsServer"
printf "\n"
printf "\e[32m"
printf "%-60s" "Logged In users:"
printf "\e[39m "

set +euo pipefail
for (( i=0; i < ${#loggedInUsers[@]}; i++ )); do
    printf "%0s" "${loggedInUsers[$i]}"
    limit=$i
    ((limit++))
    if [ $limit -ne ${#loggedInUsers[@]} ]; then
        printf "%0s" ","
    fi
done
set -euo pipefail

printf "\n"
printf "\e[32m"
printf "%-60s" "# processes in ready queue:"
printf "\e[39m"
printf "%0s" " $readyQueue"
printf "\n"
printf "\e[32m"
printf "%-60s" "# processes in wait queue:"
printf "\e[39m"
printf "%0s" " $waitQueue"
printf "\n"
printf "\e[32m"
printf "%-60s" "Disk Usages:"
printf "\e[39m "
printf "%-25s" "Filesystem"
printf "%-6s" "Size"
printf "%-5s" "Used"
printf "%-6s" "Avail"
printf "%-5s" "Use%"
printf "%-6s" "Mounted on"
printf "\n"
printf "%-61s" ""
printf "%-25s" "${diskUsage[0]}"
printf "%-6s" "${diskUsage[1]}"
printf "%-6s" "${diskUsage[2]}"
printf "%-6s" "${diskUsage[3]}"
printf "%-4s" "${diskUsage[4]}"
printf "%-6s" "${diskUsage[5]}"
printf "\n"
printf "\e[32m"
printf "%-60s" "Load Average:"
printf "\e[39m"
printf "%0s" " $loadAVG"
printf "\n"
printf "\e[32m"
printf "%-60s" "System Uptime Days/(HH:MM):"
printf "\e[39m"
printf "%0s" " $uptimeDays"
printf "\n"



exit












