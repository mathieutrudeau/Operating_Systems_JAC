param(
    [Parameter(Mandatory)][int]$max,
    [Parameter(Mandatory)][int]$numThreads
)
set-strictmode -version latest
#$DebugPreference        = 'SilentlyContinue'# disable write-debug output
$DebugPreference        = 'Continue'        # enable write-debug output
$ErrorActionPreference  = 'Stop'            # https://stackoverflow.com/questions/15545429/erroractionpreference-and-erroraction-silentlycontinue-for-get-pssessionconfigur
                                            # The ErrorAction can be used to convert non-terminating errors to terminating errors using the parameter value Stop. 
                                            # It can't help you ignore terminating errors. If you want to ignore, use a try { Stop-Transcript } catch {}
$VerbosePreference = 'Continue'

Clear-Host

Set-Variable -Name 'initialBuffer' -Value 1                 #Initial value of buffer 

$myScript = {
    Param([int]$threadNum, $host_)

    Start-Sleep -seconds 1                                  #Makes sure all threads start around the same time
    $SM.Begin | %{if(!$_){$SM.Begin=Get-Date}}              #Save the time at which this line is reached first
    $host_.UI.WriteVerboseLine([string]"Pid: "+$SM.Pid+", Thread: "+$SM.Tid[$threadNum]+" starting, initial buffer value: "+$SM.Buffer) | Out-Null     
    $mtx = New-Object System.Threading.Mutex($false, "Mutex")                   #Mutex Object
    while($SM.Buffer -lt $SM.Max)                                               #The max has not yet been reached
    {   if($mtx.WaitOne(10))                                                    #Wait for mutex to be release then take it
        {   if($SM.Buffer -lt $SM.Max)                                          
            {   $SM.Buffer++                                                    #Proceed to increment buffer
            }
        }
        $mtx.ReleaseMutex()                                                     #CS is exited so release the mutex so it can be used elsewhere
    }
    $mtx.Dispose()                                                              #No more cs. Mutex not needed
    $host_.UI.WriteVerboseLine([string]"Pid: "+$SM.Pid+", Thread: "+$SM.Tid[$threadNum]+" ending, initial buffer value: "+$SM.Buffer) |Out-Null
    $SM.End = Get-Date                                                          #Save the time at which the last thread exits
    Start-Sleep -seconds 0.1
}

$start = Get-Date

$sharedMemory = [hashtable]::Synchronized(@{})                      #Create a hashtable of values shared within the current process
$sharedMemory.Pid = $PID                                            #Save the process ID
$sharedMemory.Tid = New-Object System.Collections.ArrayList         #Save all threads id 
$sharedMemory.Max = $max                                            #Save the max value
$sharedMemory.Buffer = $initialBuffer                               #Create a buffer and set it to its initial value
$sharedMemory.Begin = $null
$sharedMemory.End = $null

$allRunspaces=@()                                           #Track all our runspaces

foreach($threadNum in 1..$numThreads)
{   Write-Host "Creating thread #$threadNum"
    $runspace = [powershell]::Create()                                                      #Create a new runspace                                        
    $runspace.Runspace.SessionStateProxy.SetVariable('SM',$sharedMemory)                    #Set shared memory
    $runspace.AddScript($myScript).AddArgument($threadNum-1).AddArgument($host)|Out-Null    #Give task to runspace
    $sharedMemory.Tid.Add($runspace.Runspace.ID)                |Out-Null                   #Save thread ID
    $allRunspaces += [PSCustomObject]@{Pipe=$runspace; Status=$runspace.BeginInvoke()}      #Save the runspace so we can track it
}

while($allRunspaces.Status.IsCompleted -contains $false){}    #Wait for all runspaces to complete

$completed = Get-Date

Write-Host "Value of buffer at end of invocation: $($sharedMemory.Buffer)"              #Show the final buffer size

$received = Get-Date

Get-Runspace | where-object {$_.Id -ne 1} | ForEach-Object{$_.Dispose()} # kill child threads 

$cleanup = Get-Date

$timeToLaunch = ($sharedMemory.Begin - $start).TotalMilliseconds
$timeToExit = ($completed - $sharedMemory.End).TotalMilliseconds
$timeToRunCommand = ($sharedMemory.End - $sharedMemory.Begin).TotalMilliseconds
$timeToReceive = ($received - $completed).TotalMilliseconds
$timeToCleanup = ($cleanup - $received).TotalMilliseconds

'{0,-30} : {1,10:#,##0.00} ms' -f 'Time to set up background job', $timeToLaunch
'{0,-30} : {1,10:#,##0.00} ms' -f 'Time to run code', $timeToRunCommand
'{0,-30} : {1,10:#,##0.00} ms' -f 'Time to exit background job', $timeToExit
'{0,-30} : {1,10:#,##0.00} ms' -f 'Time to receive results', $timeToReceive
'{0,-30} : {1,10:#,##0.00} ms' -f 'Time to cleanup runspace', $timeToCleanup

cmd /c Pause | Out-Null