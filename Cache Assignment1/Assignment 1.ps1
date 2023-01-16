set-strictmode -version latest
#$DebugPreference        = 'SilentlyContinue'# disable write-debug output
$DebugPreference        = 'Continue'        # enable write-debug output
$ErrorActionPreference  = 'Stop'            # https://stackoverflow.com/questions/15545429/erroractionpreference-and-erroraction-silentlycontinue-for-get-pssessionconfigur
                                            # The ErrorAction can be used to convert non-terminating errors to terminating errors using the parameter value Stop. 
                                            # It can't help you ignore terminating errors. If you want to ignore, use a try { Stop-Transcript } catch {}


Clear-Host

$TOTAL_OPS = 10000
$NUM_REGISTERS = 32
$CACHE_SIZE = 1024

# Response time of storage methods
$REGISTER_ACCESS_TIME = 0.25
$CACHE_ACCESS_TIME = 2
$RAM_ACCESS_TIME = 100
$DISK_ACCESS_TIME = 40000

# Time to transfer a single 64 bit word
$CACHE_BANDWIDTH_TIME   = ([Math]::Pow(10,9) / (700*[Math]::Pow(1024,3) / 8))
$RAM_BANDWIDTH_TIME     = ([Math]::Pow(10,9) / (15*[Math]::Pow(1024,3) / 8))
$DISK_BANDWIDTH_TIME    = ([Math]::Pow(10,9) / (200*[Math]::Pow(1024,2) / 8))

$RAM_HIT_PERCENTAGE = 90
$CACHE_REPLACEMENT_POLICIES = @('FIFO','LFU')

$INPUTFILE = "$PSScriptRoot\dataset.txt"

# $storage is the ONLY permitted global variable (as opposed to global constants)
$storage = [PSCustomObject]@{
    Registers   = New-Object System.Collections.Generic.List[Int]
    Cache       = $null
} 



function setRegisters($item_)
{   # return true/false if the item is in the registers
    # ...also set the registers appropriately
    $itemFound = $storage.Registers.Contains($item_)            
    if($itemFound)                                                  #Item is in registers
    {   $storage.Registers.Remove($item_)                           #Remove the item from the registers
        #write-debug "$item_ found in registers"
    }
    elseif($storage.Registers.Count -eq $NUM_REGISTERS)             #Registers are full
    {   $storage.Registers.RemoveAt(0)                              #Remove the first item 
    }
    $storage.Registers.Add($item_)                                  #Add current item to the reisters
    $stats.regTime+=$REGISTER_ACCESS_TIME
    $itemFound                                                      #return boolean
}

function testSetRegisters() 
{   # Arrays vs arraylists
    # https://www.jonathanmedd.net/2014/01/adding-and-removing-items-from-a-powershell-array.html
    $testData=New-Object System.Collections.ArrayList
    foreach($i in 1..$NUM_REGISTERS){
        $item = get-random -maximum $TOTAL_OPS
        $testData.add($item) | Out-Null   # add() is misbehaved
        setRegisters $item | Out-Null # don't need output
    }
    
    $a = Compare-Object -ReferenceObject ($testData | Select-Object -uniq) -DifferenceObject $storage.Registers -PassThru
    if($a){ # Is the register object in the format we expect?
        Write-Error "Argh! Broken setRegisters()"
        exit
    }

    $exists = setRegisters $testData[0]
    if(!$exists){ # i.e. item not found even though we added it
        Write-Error "Argh! Broken setRegisters()"
        exit
    }

    $newItem = get-random -maximum $TOTAL_DATA_ITEMS
    while($testData.Contains($newItem)){
        $newItem = get-random -maximum $TOTAL_DATA_ITEMS
    }

    $exists = setRegisters $newItem
    if($exists){ # i.e. item found even though it doesn't exist
        Write-Error "Argh! Broken setRegisters()"
        exit
    }
    
    if($storage.Registers[$NUM_REGISTERS - 1] -ne $newItem){
        Write-Error "Argh! Broken setRegisters()"
        exit
    }
}



function fetchEmptyStatsObject()
{   $stats = [PSCustomObject]@{ 
        'totalTime' = 0;    'regHits' = 0;      'cacheHits' = 0;    'ramHits' = 0;
        'diskHits'  = 0;     'regTime' = 0;     'cacheTime' = 0;    'ramTime' = 0;
        'diskTime'  = 0;
    }

    $stats | Add-Member -MemberType ScriptMethod -Name "show" -Force -Value {
        # Outputs the cache stats for a particular cache type
        $stats.totalTime = $stats.regTime + $stats.cacheTime + $stats.ramTime + $stats.diskTime
        $cacheMisses = $stats.ramHits+$stats.diskHits
        $regTimePerc = [math]::Round(($stats.regTime / $stats.totalTime)*100,2)
        $cacheTimePerc = [math]::Round(($stats.cacheTime / $stats.totalTime)*100,2)
        $ramTimePerc = [math]::Round(($stats.ramTime / $stats.totalTime)*100,2)
        $diskTimePerc = [math]::Round(($stats.diskTime / $stats.totalTime)*100,2)
        $totalHits = $cacheMisses+$stats.cacheHits+$stats.regHits
        $cacheHitRatio = [math]::Round($stats.cacheHits/($stats.cacheHits+$cacheMisses)*100,2)
        $cacheHitPerc = [math]::Round($stats.cacheHits/$totalHits*100,2)
        $regHitPerc = [math]::Round($stats.regHits/$totalHits*100,2)
        $ramHitPerc = [math]::Round($stats.ramHits/$totalHits*100,2)
        $diskHitPerc = [math]::Round($stats.diskHits/$totalHits*100,2)


        "{0,-60} {1,0}" -f "Overall performance (ns):" ,$($stats.totalTime.ToString("#.##"))
        "{0,-65} {1,0}" -f  "Cache hit ratio:", "$($cacheHitRatio)%"
        ""
        "{0,-58} {1,0}" -f "Cache hits:", "$($stats.cacheHits) ($($cacheHitPerc)%)"
        "{0,-67} {1,0}" -f "Cache misses:", "$($cacheMisses)"
        ""
        "{0,-60} {1,0}" -f "Register Hits:", "$($stats.regHits) ($($regHitPerc)%)"
        "{0,-58} {1,0}" -f "RAM Hits:", "$($stats.ramHits) ($($ramHitPerc)%)"
        "{0,-60} {1,0}" -f "Disk Hits:", "$($stats.diskHits) ($($diskHitPerc)%)"
        ""
        "{0,-56} {1,0}" -f "Register Time:", "$($stats.regTime) NS ($($regTimePerc)%)"
        "{0,-52} {1,0}" -f "Cache Time:", "$($stats.cacheTime.ToString("#.##")) NS ($($cacheTimePerc)%)"
        "{0,-51} {1,0}" -f "RAM Time:", "$($stats.ramTime.ToString("#.##")) NS ($($ramTimePerc)%)"
        "{0,-49} {1,0}" -f "Disk Time:", "$($stats.diskTime.ToString("#.##")) NS ($($diskTimePerc)%)"
    }

    return $stats
}


function setCache($cacheType_, $item_)
{   # Return true on cache hit, else false.  Call correct caching function
    $itemFound = $false
    if($cacheType_ -eq 'FIFO'){
        $itemFound=setFIFOCache $item_
    }
    if($cacheType_ -eq 'LFU'){
        $itemFound = setLFUCache $item_
    }
    $stats.cacheTime+=$CACHE_ACCESS_TIME+$CACHE_BANDWIDTH_TIME
    $itemFound
}

function setFIFOCache($item_)
{   # Given an item request, set the cache
    # Initialize cache
    if($null -eq $storage.Cache)
    {   $storage.Cache = New-Object System.Collections.Generic.List[Int]
    }
    # Look if item is in cache
    $itemFound = $storage.Cache.Contains($item_)
    if($itemFound)
    {   $storage.Cache.Remove($item_)
    }
    elseif($storage.Cache.Count -eq $CACHE_SIZE)
    {   $storage.Cache.RemoveAt(0)
    }
    # Add item at the end of list so it can be last to leave the cache
    $storage.Cache.Add($item_)
    $itemFound
}



function testSetFIFOCache() 
{   $testData=New-Object System.Collections.ArrayList
    
    foreach($head in 1..($CACHE_SIZE)){
        $item = get-random -maximum $TOTAL_DATA_ITEMS
        $testData.add($item) | Out-Null   # add() is misbehaved
        setFIFOCache $item | Out-Null
    }

    $a = Compare-Object -ReferenceObject ($testData | Select-Object -uniq) -DifferenceObject $storage.cache -PassThru
    if($a){ # Is the cache object in the format we expect?
        Write-Error "Argh! Broken SetFIFOCache()"
        exit
    }

    foreach($head in 1..($CACHE_SIZE)){ # do it again to cover duplicate items (i.e. cache not yet full condition)
        $item = get-random -maximum $TOTAL_DATA_ITEMS
        $testData.add($item) | Out-Null   # add() is misbehaved
        setFIFOCache $item | Out-Null
    }

    if($storage.cache.count -ne $CACHE_SIZE){
        Write-Error "Argh! Weird cache size, coincidence?"
        exit
    }
    
    $exists = setCache 'FIFO' $testData[-1]
    if(!$exists){ # i.e. item not found even though we added it
        Write-Error "Argh! Broken SetFIFOCache()"
        exit
    }

    $newItem = get-random -maximum $TOTAL_DATA_ITEMS
    while($testData.Contains($newItem)){
        $newItem = get-random -maximum $TOTAL_DATA_ITEMS
    }

    $exists = setCache 'FIFO' $newItem
    if($exists){ # i.e. item found even though it doesn't exist
        Write-Error "Argh! Broken SetFIFOCache()"
        exit
    }
    
    if($storage.cache[-1] -ne $newItem){
        Write-Error "Argh! Broken SetFIFOCache()"
        exit
    }
}



function setLFUCache($item_)
{   # Given an item request, set the cache
    $itemFound = $false
    $trackIndex = 0
    
    #Initialize Cache    
    if($null -eq $storage.Cache)                                                                                                                    
    {   $storage.Cache = New-Object System.Collections.ArrayList
        $storage.Cache.Add((New-Object System.Collections.ArrayList))           | Out-Null          
    }

    #Get number of items in cache
    foreach($element in $storage.Cache)                                                     
    {   $trackIndex += $element.Count
    }

    # Look if the item is currently in the cache
    for($frequency = 0; $frequency -lt $storage.Cache.Count; $frequency++)
    {   if($itemFound = ($storage.Cache[$frequency] -contains $item_))
        {   $storage.Cache[$frequency].Remove([int]$item_)
            if($frequency -eq ($storage.Cache.Count-1))
            {   $storage.Cache.Add((New-Object System.Collections.ArrayList))   | Out-Null
            }
            $storage.Cache[([int]($frequency+1))].Add([int]$item_)              | Out-Null
            break
        } 
    }

    # Add item to cache if not there
    if(!$itemFound)
    {   $storage.Cache[0].Add([int]$item_)      | Out-Null
    }
    
    # Remove less frequently used item if cache is full
    if($trackIndex -eq $CACHE_SIZE)                                                         
    {   for($frequency = 0; $frequency -lt $storage.Cache.Count; $frequency++)
        {   if($storage.Cache[$frequency].Count-1)
            {   $storage.Cache[$frequency].RemoveAt(0)
                break
            }
        }
    }
    $itemFound
}


function testSetLFUCache()
{   $item = 12
    $reps = 4

    for($i=0; $i -lt $reps; $i++){
        setCache 'LFU' $item | out-null
    }

    if($storage.cache[$reps-1][0] -ne $item){
        Write-Error "Argh! Weird cache values, broken setLFUCache()"
        exit
    }

    if($storage.cache[0].Count -ne 0 -or $storage.cache[1].Count -ne 0 -or $storage.cache[2].Count -ne 0){
        Write-Error "Argh! Weird cache values, broken setLFUCache()"
        exit
    }
}


function clearStorage()
{   # Clears the storage object so that it can be reused between cache types
    
    $storage.Registers.Clear()
    $storage.Cache = $null
}



# main body

$items = Get-Content $INPUTFILE  # All of the data items to process
Get-Random -SetSeed 2019    | Out-Null
foreach($cacheType in $CACHE_REPLACEMENT_POLICIES)
{   clearStorage

    $stats = fetchEmptyStatsObject

    Write-Output "________________________________________________________________________"
    Write-Output "${cacheType}:"

    for($opNum = 0; $opNum -lt $TOTAL_OPS; $opNum++){
        $currItem = $items[$opNum]
        
        if(setRegisters $currItem $opNum)
        { # item was in registers, we're done!
            $stats.regHits++
            continue
        }

        if(setCache $cacheType $currItem){
            $stats.cacheHits++
            continue
        }

        if((Get-Random -maximum 100 ) -lt $RAM_HIT_PERCENTAGE){ # if in RAM...
            $stats.ramHits++
            $stats.ramTime+=$RAM_ACCESS_TIME+$RAM_BANDWIDTH_TIME
            continue
        }
        else {
            $stats.diskHits++
            $stats.ramTime+=$RAM_ACCESS_TIME+$RAM_BANDWIDTH_TIME
            $stats.diskTime+=$DISK_ACCESS_TIME+$DISK_BANDWIDTH_TIME
        }

    }
    $stats.show()
}
cmd /c pause | out-null # Pause when using Console