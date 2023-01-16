param(
    [Parameter(Mandatory)][int]$max,
    [Parameter(Mandatory)][int]$numProcesses
)
set-strictmode -version latest
#$DebugPreference        = 'SilentlyContinue'# disable write-debug output
$DebugPreference        = 'Continue'        # enable write-debug output
$ErrorActionPreference  = 'Stop'            # https://stackoverflow.com/questions/15545429/erroractionpreference-and-erroraction-silentlycontinue-for-get-pssessionconfigur
                                            # The ErrorAction can be used to convert non-terminating errors to terminating errors using the parameter value Stop. 
                                            # It can't help you ignore terminating errors. If you want to ignore, use a try { Stop-Transcript } catch {}
$VerbosePreference = 'Continue'

#Clear-Host

$bufferFilePath = $PSScriptRoot+'\bufferStore.txt'          #Set file path for saving buffer

Set-Variable -Name 'initialBuffer' -Value 0                 #Initial value of buffer 

Write-Output $initialBuffer | Out-File -FilePath $bufferFilePath        #Create a file with default buffer size 

$myScript = {
    [int]$max = $args[0]                                    #Max size for buffer
    [string] $bufferFilePath = $args[1]                     #File path where buffer value is stored
    [string] $mutexName = $args[2]                          #Name of mutex to retrieve it
    [int]$buffer = $args[3]                                 #initial buffer size
    [int]$numProcesses = $args[4]
    Start-Sleep -Seconds 1
    $begin = Get-Date
    $mtx  = [System.Threading.Mutex]::OpenExisting($mutexName)          #Retreive the mutex    
    
    $subMax = ($max-($max%$numProcesses))/$numProcesses                 #Get a submax
    $done = $false
    
    while($buffer -lt $max -or !$done)                                             #Max has not yet been reached         
    {   if($buffer -lt $subMax)                                         #Increase buffer if less than submax
        {   $buffer++
        }
        else                                                            #Buffer has reached submax
        {   if($buffer -eq $subMax)
            {   if($mtx.WaitOne())                                      #Entering CS
                {   [int]$buff = Get-Content -Path $bufferFilePath      #Get shared buffer size
                    if(($buffer+$buff) -lt $max)                        #Can we add to it?
                    {   $buff+=$buffer                                  #Yes, so add it    
                    }   
                    elseif($buff -lt $max)                              #No, so add one 
                    {   $buff++
                    }
                    else 
                    {   $done=$true        
                    }
                    Set-Content -Path $bufferFilePath -Value $buff      #Save new buffer                                                    
                    $mtx.ReleaseMutex()                                 #Leaving CS
                    if($done){break}                                    #Leave if buffer equals max

                    $buffer = 0                                         #Reset buffer 
                    $subMax = ($subMax-($subMax%2))/2                   #Recalculate submax
                }
            }
        }
    }
    $end = Get-Date
    $begin                                              #Return starting time
    $end                                                #Return end time
    Start-Sleep -Seconds 0.5                            #Wait for all jobs to end
}

$start = Get-Date

$mutexName = "Mutex"                                                        #Give Name to mutex so we can retrieve it
$mtx = New-Object System.Threading.Mutex($false, $mutexName)               
Get-Job | %{Stop-Job -Name $_.Name;Remove-Job -Name $_.Name}                                       #clear all jobs

foreach($process in 1..$numProcesses)                                       #Start n number of jobs 
{   Write-Host "Creating process #$process"
    Start-Job -ScriptBlock $myScript -ArgumentList $max, $bufferFilePath, $mutexName, $initialBuffer, $numProcesses    |Out-Null
}

Get-Job| %{Wait-Job -Name $_.Name}       |Out-Null                          #Wait for all jobs to finish

$completed = Get-Date

$spinup = $exit = $null                                                     
Get-Job | Receive-Job | %{if(!$spinup){$spinup=$_}$exit=$_}                 #Retrieve the timestamps from the jobs, Spinup=start time Exit= ending time

$received = Get-Date

$mtx.Dispose()                                                              #No more CS. Get rid of mutex

Get-Job | %{Remove-Job -Name $_.Name}                                       #Kill all remaining processes
$cleanup = Get-Date

Get-Content -Path $bufferFilePath | %{Write-Host "Value of buffer at end of invocation: $_"}      #Show value of buffer

$timeToLaunch = ($spinup - $start).TotalMilliseconds
$timeToExit = ($completed - $exit).TotalMilliseconds
$timeToRunCommand = ($exit - $spinup).TotalMilliseconds
$timeToReceive = ($received - $completed).TotalMilliseconds
$timeToCleanup = ($cleanup - $received).TotalMilliseconds

'{0,-30} : {1,10:#,##0.00} ms' -f 'Time to set up background job', $timeToLaunch
'{0,-30} : {1,10:#,##0.00} ms' -f 'Time to run code', $timeToRunCommand
'{0,-30} : {1,10:#,##0.00} ms' -f 'Time to exit background job', $timeToExit
'{0,-30} : {1,10:#,##0.00} ms' -f 'Time to receive results', $timeToReceive
'{0,-30} : {1,10:#,##0.00} ms' -f 'Time to cleanup psJobs', $timeToCleanup

cmd /c Pause | Out-Null