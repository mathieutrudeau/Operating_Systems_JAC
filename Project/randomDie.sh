#!/bin/bash
#set-euo pipefail


((ran=10-($RANDOM%6)))
sleep $ran

((div=1/($ran%2))) 2>&-

exit $?

