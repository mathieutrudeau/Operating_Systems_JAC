#Start tracking time
$stopWatch = [System.Diagnostics.Stopwatch]::StartNew()

set-strictmode -version latest
#$DebugPreference        = 'SilentlyContinue'# disable write-debug output
$DebugPreference        = 'Continue'        # enable write-debug output
$ErrorActionPreference  = 'Stop'            # https://stackoverflow.com/questions/15545429/erroractionpreference-and-erroraction-silentlycontinue-for-get-pssessionconfigur
                                            # The ErrorAction can be used to convert non-terminating errors to terminating errors using the parameter value Stop. 
                                            # It can't help you ignore terminating errors. If you want to ignore, use a try { Stop-Transcript } catch {}
Clear-Host

#Input location
$INPUTFILE = "$PSScriptRoot\asg2-200000.txt"
#Get values from input file
$CONTENT = Get-Content $INPUTFILE

#Script to be executed by threads
$myScript = {
    Param(
        [array] $VALUES,
        [int] $ID)
    function isPrime([int]$primeContender_)
    {   if($primeContender_ -lt 3)
        {   if($primeContender_ -ne 1)
            {   return $true
            }
        return $false
        }
        elseif(($primeContender_%2 -eq 0) -or ($primeContender_%3 -eq 0))
        {   return $false
        }
        $i = 5  
        while(($i*$i) -le $primeContender_)
        {   if(($primeContender_%$i -eq 0) -or ($primeContender_%($i+2) -eq 0))
            {   return $false
            }
            $i+=6   
        }
        return $true
    }

    #Find primes and return sum of primes
    [int]$sum = 0;
    foreach($value in $VALUES)
    {   if(isPrime $value)
        {   $sum+=$value
        }
    }

    $curIndex = $ID-1           
    $info.sums[$curIndex] = $sum
    
    #Current Thread needs to add sum of other threads
    if($ID%2)
    {   
        #There is more sums to add
        while(($ID+$info.pointers[$curIndex]) -le $info.ThreadsNUM)
        {   #Next thread to add is completed its tasks
            while($info.CompleteStatus[(($ID+$info.pointers[$curIndex])-1)] -notcontains $true){}
            #Proceed to adding sum 
            $info.sums[$curIndex]+=$info.sums[(($ID+$info.pointers[$curIndex])-1)]
            #Set sum of other thread to 0 to avoid potential bugs
            $info.sums[(($ID+$info.pointers[$curIndex])-1)] = 0
            #Move to next thread to add
            $info.pointers[$curIndex]*=2
        }
    }
    $info.CompleteStatus[($ID-1)] = $true  
}

#  Get number of threads to create
$numThreads = [int]$env:NUMBER_OF_PROCESSORS
$bufferSize = ($CONTENT.Length-($CONTENT.Length%$numThreads))/$numThreads

Write-Host "Buffer size: $bufferSize"
Write-Host "Number of threads: $numThreads"
Write-Host "Launching threads..."

#Shared Memory
$sharedMemory = [hashtable]::Synchronized(@{})
$sharedMemory.ID = New-Object System.Collections.ArrayList
$sharedMemory.ThreadsNUM = [int]$numThreads
$sharedMemory.CompleteStatus = New-Object System.Collections.ArrayList
$sharedMemory.pointers = New-Object System.Collections.ArrayList
$sharedMemory.sums = New-Object System.Collections.ArrayList

#Keep all runspaces 
$allRunspaces=@()

$lastIndex = 0

foreach($thread in 1..$numThreads)
{   $sharedMemory.ID.Add($thread)               |Out-Null
    $sharedMemory.CompleteStatus.Add($false)    |Out-Null
    $sharedMemory.sums.Add(0)                   |Out-Null
    $sharedMemory.pointers.Add(1)               |Out-Null
    
    $psInstance = [powershell]::Create()
    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.Open()
    $runspace.SessionStateProxy.SetVariable('info',$sharedMemory)
    $psInstance.Runspace = $runspace

    if($thread -lt $numThreads)
    {   $psInstance.AddScript($myScript).AddArgument($CONTENT[$lastIndex..($lastIndex+($bufferSize-1))]).AddArgument($thread)   |Out-Null
    }
    else 
    {   $psInstance.AddScript($myScript).AddArgument($CONTENT[$lastIndex..($CONTENT.Length-1)]).AddArgument($thread)   |Out-Null
    }

    $allRunspaces += [PSCustomObject]@{
        Pipe=$psInstance; Status=$psInstance.BeginInvoke()}  
    $lastIndex += $bufferSize    
}    

#Sum of all primes
$sumTotal = 0;

Write-Host "Threads running..."

#Wait for all runspaces to complete
while($allRunspaces.Status.IsCompleted -notcontains $true)
{   Start-Sleep -seconds 1
}

foreach($runspace in $allRunspaces)
{   $runspace.Pipe.EndInvoke($Runspace.Status)
    $runspace.Pipe.Dispose()
}

$sumTotal = $sharedMemory.sums[0]

$time = $stopWatch.ElapsedMilliseconds/1000
Write-Host "Time: $time (seconds)"
Write-Host "Sum of primes: $sumTotal"

cmd /c pause | out-null # Pause when using Console