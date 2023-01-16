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
    $host_.UI.WriteVerboseLine([string]"Pid: "+$SM.Pid+", Thread: "+$SM.Tid[$threadNum]+" starting, initial buffer value: "+$SM.Buffer) | Out-Null
    while($SM.Buffer -lt $SM.Max)               
    {   $SM.Buffer++                                        #Increase buffer until it reaches the max value
    }
    $host_.UI.WriteVerboseLine([string]"Pid: "+$SM.Pid+", Thread: "+$SM.Tid[$threadNum]+" ending, initial buffer value: "+$SM.Buffer) |Out-Null
    Start-Sleep -seconds 0.5                                #Wait for other runspaces to finish
}

$sharedMemory = [hashtable]::Synchronized(@{})                      #Create a hashtable of values shared within the current process
$sharedMemory.Pid = $PID                                            #Save the process ID
$sharedMemory.Tid = New-Object System.Collections.ArrayList         #Save all threads id 
$sharedMemory.Max = $max                                            #Save the max value
$sharedMemory.Buffer = $initialBuffer                               #Create a buffer and set it to its initial value    

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

Write-Host "Value of buffer at end of invocation: $($sharedMemory.Buffer)"              #Show the final buffer size

Get-Runspace | where-object {$_.Id -ne 1} | ForEach-Object{$_.Dispose()} # kill child threads 

cmd /c Pause | Out-Null