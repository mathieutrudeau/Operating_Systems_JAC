param ([int]$bufferSize=0, [int]$numThreads=1)
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
        [array] $VALUES)
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
    $sum

}

#  Get number of threads to create
$threadsToCreate = 0
if(!$numThreads -and !$bufferSize)
{   $numThreads = [int]$env:NUMBER_OF_PROCESSORS
    $threadsToCreate = $numThreads
    $bufferSize = ($CONTENT.Length-($CONTENT.Length%$threadsToCreate))/$threadsToCreate
}
elseif(!$bufferSize)
{   $threadsToCreate = $numThreads
    $bufferSize = ($CONTENT.Length-($CONTENT.Length%$threadsToCreate))/$threadsToCreate
}
elseif(!$numThreads)
{   $threadsToCreate = ($CONTENT.Length-($CONTENT.Length%$bufferSize))/$bufferSize
    $numThreads = $threadsToCreate
}
else
{   $threadsToCreate = ($CONTENT.Length-($CONTENT.Length%$bufferSize))/$bufferSize
}

Write-Host "Buffer size: $bufferSize"
Write-Host "Number of threads: $numThreads"
Write-Host "Launching threads..."

#Create a runspace pool
$runspacePool = [runspacefactory]::CreateRunspacePool(1, $numThreads)
$runspacePool.SetMinRunspaces(1)                |Out-Null
$runspacePool.SetMaxRunspaces($numThreads)      |Out-Null
#$runspacePool.ApartmentState = "MTA"
$runspacePool.Open()


#Keep all runspaces 
$allRunspaces=@()

$lastIndex = 0

foreach($thread in 1..$threadsToCreate)
{   $psInstance = [powershell]::Create()

    if($thread -lt $threadsToCreate)
    {   $psInstance.AddScript($myScript).AddArgument($CONTENT[$lastIndex..($lastIndex+($bufferSize-1))])   |Out-Null
    }
    else 
    {   $psInstance.AddScript($myScript).AddArgument($CONTENT[$lastIndex..(($CONTENT.Length)-1)])   |Out-Null
    }

    $psInstance.RunspacePool = $runspacePool

    $allRunspaces += [PSCustomObject]@{
        Pipe=$psInstance; Status=$psInstance.BeginInvoke()}  
    $lastIndex += $bufferSize    
}    

#Sum of all primes
$sumTotal = 0;

Write-Host "Threads running..."

#Wait for all runspaces to complete
while($allRunspaces.Status.IsCompleted -notcontains $true){}

foreach($runspace in $allRunspaces)
{   # Retrieve sum from thread and dispose  
    $data = $runspace.Pipe.EndInvoke($Runspace.Status)
    $runspace.Pipe.Dispose()
    $sumTotal+=$data[0]
}

$runspacePool.CLose()
$runspacePool.Dispose()

$time = $stopWatch.ElapsedMilliseconds/1000
Write-Host "Time: $time (seconds)"
Write-Host "Sum of primes: $sumTotal"

cmd /c pause | out-null # Pause when using Console