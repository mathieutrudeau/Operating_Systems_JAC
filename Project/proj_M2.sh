#!/bin/bash
set -euo pipefail


mountedFS=($(df -h -T | grep -v '^tmpfs' | awk '{print $1 " " $2 " " $3 " " $6 " " $7}' | sed 1,1d))

homeDir=$(echo $HOME)
currPID=$(ps | sed '2q;d' | awk '{print $1}')
openFilesForCurrPID=($(lsof -l| egrep "$(($currPID))" | awk '{print $9}'))

duHome=$(du -sh $HOME | awk '{print $1}')

relPathToHome=$(realpath --relative-to=$HOME /)

kFile=$(cat /proc/cmdline | awk -F "/" '{print $2}' | awk -F " " '{print $1}')
runningKernelFile=$(ls /boot -i | egrep $kFile)
kernelInode=$(echo $runningKernelFile|awk '{print $1}')
kernelFile=$(echo $runningKernelFile|awk '{print $2}')

bootFiles=$(ls /boot  | egrep 'vmlinuz' | awk '{print "/boot/" $1}')
kernelFilesInBoot=($(stat -c '%n (%a)' $bootFiles))

printf "\e[39m-----------------------------------------------------------"
printf "\n"
printf "\e[32mDisk / Filesystem Statistics"
printf "\n"
printf "\e[39m-----------------------------------------------------------"
printf "\n"
printf "\e[32mMounted filesystems (excluding tmpfs):\e[39m"
printf "\n"
printf "%-61s" ""
printf "%-15s" "Mount Point"
printf "%-15s" "FS Type"
printf "%-10s" "Disk"
printf "%-5s" "Size"
printf "%0s" "Util%"
printf "\n"
printf "%-61s" ""
printf "%-15s" "-----------"
printf "%-15s" "-------"
printf "%-10s" "----"
printf "%-5s" "----"
printf "%0s" "-----"
printf "\n"
for (( i=0; i < ${#mountedFS[@]}; i+=5 )); do
    printf "%-61s" ""
    printf "%11s" "${mountedFS[$i+4]}"
    printf "%11s" "${mountedFS[$i+1]}"
    diskSearch="${mountedFS[$i+4]}$"
    set +euo pipefail
    disk=$(lsblk -l | grep $diskSearch | awk '{print $1}')
    set -euo pipefail
    printf "%12s" "$disk"
    printf "%10s" "${mountedFS[$i+2]}"
    printf "%6s" "${mountedFS[$i+3]}"
    printf "\n"
done 
printf "\e[32mKernel files in /boot (with permissions):\e[39m"
printf "\n"
for (( i=0; i < ${#kernelFilesInBoot[@]}; i+=2 )); do
    printf "\e[32m"
    printf "%-61s"
    printf "\e[39m"
    printf "%0s" "${kernelFilesInBoot[$i]} ${kernelFilesInBoot[$i+1]}"
    printf "\n"
done
printf "\e[32m"
printf "%-61s" "Running kernel file (with inode)" 
printf "\e[39m"
printf "%0s" "$kernelFile ($kernelInode)"
printf "\n"
printf "\e[32m"
printf "%-61s" "Home directory:" 
printf "\e[39m"
printf "%0s" "$homeDir"
printf "\n"
printf "\e[32m"
printf "%-61s" "Disk usage (home directory):"
printf "\e[39m"
printf "%0s" "$duHome"
printf "\n"
printf "\e[32m"
printf "%-61s" "Relative path of / to \$HOME"
printf "\e[39m"
printf "%0s" "$relPathToHome"
printf "\n"
printf "\e[32m"
printf "%0s" "Open files for current process ID ($currPID):"
printf "\e[39m"
printf "\n"
for (( i=0; i < ${#openFilesForCurrPID[@]}; i++ )); do
    printf "\e[32m"
    printf "%-61s"
    printf "\e[39m"
    printf "%0s" "${openFilesForCurrPID[$i]}"
    printf "\n"
done
printf "\n"


exit
