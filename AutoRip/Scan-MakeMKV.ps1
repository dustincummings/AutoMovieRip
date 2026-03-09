# Scan-MakeMKV.ps - v1.0.0
param([string] $DiscType)

. "$PSScriptRoot\Config.ps1"
. "$PSScriptRoot\Utilities.ps1"

Write-Log "Running MakeMKV scan..."

$MKVScanLog = Join-Path $LogDir "MakeMKV_Scan_$TimeStamp.txt"

# Capture full output and log it
$output = & $MakeMKV -r --cache=1 info disc:0 2>&1
$output | Out-File -FilePath $MKVScanLog -Encoding UTF8

if ($LASTEXITCODE -ne 0 -or $output.Count -eq 0) {
    Write-Log "MakeMKV returned no usable data."
    return $null
}

#Extract DiscName from CINFO:2 or CINFO:32
$discName = "Unknown_Disc"
foreach ($line in $output) {
    if ($line -match '^CINFO:(2|32),\d+,"(.+)"') {
        $discName = $Matches[2].Trim()
        break
    }
}
Write-Log "Detected disc name: $discName"
Write-Host "Detected disc name: $discName"

$UserInput = Read-Host "Press Enter to accept, or type a different name"

if([string]::IsNullOrWhiteSpace($UserInput)){
    $DiscName = $discName
    Write-Log "User kept discName: $discName"
} else {
    $DiscName = $UserInput.Trim()
    Write-Log "User updated Disc Name: $DiscName"
}

#Parse Titles
Remove-Variable -Name Titles -ErrorAction SilentlyContinue 
$Titles = @{}
$currentID = $null
$currentTrackType = $null

foreach ($line in $output) {
    #---------------------------------
    # TITLE HEADER
    #---------------------------------
   if ($line -match '^TINFO:(\d+),') {
        $currentID = [int]$Matches[1]
        $currentTrackType = $null

        if (-not $Titles.ContainsKey($currentID)) {
            $Titles[$currentID] = [ordered]@{
                ID = $currentID
                Runtime = $null 
                Chapters = $null 
                SizeMB = $null 
                CellMap = $null 
                Audio = @() 
                Subtitles = @() 
                VideoRes = $null
                Valid = $false
            }
        }
        continue
    }

    if ($null -eq $currentID) { continue }

    # Runtime
    if ($line -match '^TINFO:\d+,9,0,"(.+)"') {
        $Titles[$currentID].Runtime = Convert-RuntimeToSeconds $Matches[1]
    }
    # Chapters
    if ($line -match '^TINFO:\d+,8,0,"(\d+)"') {
        $Titles[$currentID].Chapters = [int]$Matches[1]
    }
    # Size
    if ($line -match '^TINFO:\d+,11,0,"(.+)"') {
        $Titles[$currentID].SizeMB = Convert-SizeToMB $Matches[1]
    }
    # Cell Map (DVD only)
    if ($line -match '^TINFO:\d+,26,0,"(.+)"') {
        $Titles[$currentID].CellMap = $Matches[1]
    }

    # Video resolution (DVD & Blu-ray)
    if ($line -match '^SINFO:\d+,0,19,0,"(\d+)x(\d+)"') {
        $Titles[$currentID].VideoRes = "$($Matches[1])x$($Matches[2])"
    }

    # Audio Header
    if ($line -match '^SINFO:\d+,\d+,1,6202,"Audio"') {
        $currentTrackType = 'Audio'
        continue
    }

    # Subtitle Header
    if ($line -match '^SINFO:\d+,\d+,1,6203,"Subtitles"') {
        $currentTrackType = 'Subtitles'
        continue
    }

    # Audio/Subtitles description
    if ($line -match '^SINFO:\d+,\d+,30,0,"(.+)"') {
        switch ($currentTrackType) {
            'Audio'     { $Titles[$currentID].Audio     += $Matches[1] }
            'Subtitles' { $Titles[$currentID].Subtitles += $Matches[1] }
        }
        continue
    }
}
# VALIDATION (DVD & Blu-ray)
foreach ($t in $Titles.Values) {
    #--------------------------
    # Audio: English 5.1
    #--------------------------
    $hasEnglish51 = ($t.Audio | Where-Object{ $_ -match '(?i)(english|eng).*(5\.1)'}).Count -ge 0

    #--------------------------
    # Subtitles: at least 2 major languages
    #--------------------------
    $subtitleLanguages = $t.Subtitles | 
        ForEach-Object { 
            if ($_ -match '(English|French|Spanish|Portuguese|German|Italian)') { 
                $Matches[1] 
            } 
        } | 
        Sort-Object -Unique 
    $hasMultipleSubs = $subtitleLanguages.Count -ge 2

    #--------------------------
    # DVD validation rules
    #--------------------------
    $validDVDResolution = $t.VideoRes -match '720x480|720x576' 
    $validDVDChapters = $t.Chapters -ge 12 
    $validDVDRuntime = $t.Runtime -ge (90 * 60) 
    $validDVDSize = $t.SizeMB -ge 100 
    $suspiciousCellMap = $t.CellMap -match '\d{3,}'

    $isDVDValid = ( 
        $validDVDResolution -and 
        $validDVDChapters -and 
        $validDVDRuntime -and 
        $validDVDSize -and 
        $hasEnglish51 -and 
        $hasMultipleSubs -and 
        -not $suspiciousCellMap 
    )
    
    #--------------------------
    # Blu-ray validation rules
    #--------------------------
    $validBDResolution = $t.VideoRes -match '1920x1080|1280x720' 
    $validBDRuntime = $t.Runtime -ge (20 * 60) 
    $validBDSize = $t.SizeMB -ge 1024 
    $isBDValid = ( 
        $validBDResolution -and 
        $validBDRuntime -and 
        $validBDSize -and 
        $hasEnglish51 -and 
        $hasMultipleSubs 
    )
    #-------------------------
    # Final decision
    #-------------------------
    if($isDVDValid -or $isBDValid){
        $t.Valid =$true
    }
}

$valid = $Titles | Where-Object { $_.Valid }

Write-Log "MakeMKV found $($valid.Count) valid titles."

return [PSCustomObject]@{
    DiscName = $discName
    Titles = $valid
}
