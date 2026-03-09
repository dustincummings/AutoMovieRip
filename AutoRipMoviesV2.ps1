# ============================================================
# GLOBAL CONFIGURATION & UTILITY FUNCTIONS
# ============================================================

# Subtitle embedding toggle
$EmbedSubtitles = $true

# Paths to tools
$MakeMKV= "C:\Program Files (x86)\MakeMKV\makemkvcon.exe"
#$HandBrakeCLI = "C:\Program Files\HandBrakeCLI\HandBrakeCLI.exe"  #Location on Server
$HandBrakeCLI = "C:\Program Files\HandBrake\HandBrakeCLI.exe" #Location on Laptop

# Output directories
$MoviesRoot = "C:\Users\dusti\Videos" #Location when connected to Server

# Script + log directories
# $ScriptRoot = "C:\Users\Public\Scripts" #Location on server
$ScriptRoot = "C:\Users\dusti\OneDrive\Desktop\Scripts" #Location on Laptop
$LogDir = Join-Path $ScriptRoot "Logs"

if (!(Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir | Out-Null
}

# Timestamp for logs
$TimeStamp = (Get-Date).ToString("yyyy-MM-dd_HH-mm-ss")
$MainLog = Join-Path $LogDir "AutoRip_$TimeStamp.log"

# Logging function
function Write-Log {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date), $Message
    Write-Output $line
    Add-Content -Path $MainLog -Value $line
}

Write-Log "=== AutoRip Started ==="

function Get-MovieYearFromTMDb {
    param(
        [string]$DiscName,
        [string]$ApiKey
    )

    # Clean disc name
    $QueryTitle = ($DiscName -replace '_',' ' -replace '\s+',' ').Trim()
    $Query = [System.Web.HttpUtility]::UrlEncode($QueryTitle)

    # Build TMDb search URL
    $Url = "https://api.themoviedb.org/3/search/movie?api_key=$ApiKey&query=$Query"

    # Query TMDb
    $response = Invoke-RestMethod -Uri $Url -Method Get

    $results = $response.results

    if(-not $results) {
        Write-Host "No TMDB results found for '$DiscName'"
        return $null
    }

    # Show List to User
    Write-Host ""
    Write-Host "Possible matches from TMDb:"
    Write-Host "---------------------------"


    for($i =0; $i -lt $results.Count; $i++){
        $title = $results[$i].title
        $date = $results[$i].release_date
        Write-Host "[$($i+1)] $title ($date)"
    }

    Write-Host ""
    $choice = Read-Host "Enter the number of the correct movie (or press Enter to cancel)"

    $choice = [int]$choice

    if ([string]::IsNullOrWhiteSpace($choice)) { 
        Write-Host "No selection made." 
        return $null 
    }
 
    if ($choice -notmatch '^\d+$' -or $choice -lt 1 -or $choice -gt $results.Count) { 
        Write-Host "Invalid selection." 
        return $null 
    }

    $selected = $results[$choice -1]

    if ($selected.release_date -match '^(\d{4})') { 
         $year = $Matches[1] 
    } 
    
    return [PSCustomObject]@{ 
        Title = $selected.title 
        Year = $year 
        ID = $selected.id 
        Raw = $selected
    }
}

# ------------------------------
# Utility: Convert HH:MM:SS seconds
# ------------------------------
function Convert-RuntimeToSeconds {
    param([string]$Runtime)

    if ($Runtime -match "^\d+:\d{2}:\d{2}$") {
        $p = $Runtime.Split(":")
        return ([int]$p[0] * 3600) + ([int]$p[1] * 60) + ([int]$p[2])
    }
    return $null
}

# ------------------------------
# Utility: Convert size MB
# ------------------------------
function Convert-SizeToMB {
    param([string]$Size)

    if ($Size -match "GB") {
        return [math]::Round(([double]($Size -replace "GB", "").Trim()) * 1024)
    }
    elseif ($Size -match "MB") {
        return [math]::Round([double]($Size -replace "MB", "").Trim())
    }
    elseif ($Size -match "^\d+$") {
        return [math]::Round([double]$Size / 1MB)
    }

    return $null
}

# ------------------------------
# Utility: Ask Yes/No
# ------------------------------
function Read-UserConfirmation {
    param(
        [string]$Prompt,
        [string]$Default = "N"
    )

    $response = Read-Host "$Prompt (Y/N) [Default: $Default]"
    if ([string]::IsNullOrWhiteSpace($response)) { $response = $Default }

    return ($response.ToUpper() -eq "Y")
}

# ============================================================
# MAKEMKV SCANNING
# ============================================================

Write-Log "Starting MakeMKV scan..."

$MKVScanLog = Join-Path $LogDir "MakeMKV_Scan_$TimeStamp.txt"

$MakeMKVOutput = & $MakeMKV -r --cache=1 info disc:0 2>&1
$MakeMKVOutput | Out-File -FilePath $MKVScanLog -Encoding UTF8

if ($LASTEXITCODE -ne 0 -or $MakeMKVOutput.Count -eq 0) {
    Write-Log "MakeMKV scan failed or returned no data."
    $MakeMKVTitles = $null
}
else {
    Write-Log "MakeMKV scan completed. Parsing..."

    # Extract disc name
    $RippedName = "Unknown_Disc"
    foreach ($line in $MakeMKVOutput) {
        if ($line -match '^CINFO:(2|32),\d+,"(.+)"') {
            $RippedName = $Matches[2].Trim()
            break
        }
    }
    Write-Log "Detected disc name: $RippedName"
    Write-Host "Detected disc name: $RippedName"

    $UserInput = Read-Host "Press Enter to accept, or type a different name"

    if([string]::IsNullOrWhiteSpace($UserInput)){
        $DiscName = $RippedName
    } else {
        $DiscName = $UserInput.Trim()
    }

    #$DiscName = ($DiscName -replace '[^\w\-\.\s]', '')
    # Parse titles
    $Titles = @{}
    $currentID = $null

    foreach ($line in $MakeMKVOutput) {

        if ($line -match '^TINFO:(\d+),') {
            $currentID = [int]$Matches[1]
            $currentTrackType = $null 
            if (-not $Titles.ContainsKey($currentID)) {
                $Titles[$currentID] = [ordered]@{
                    ID       = $currentID
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
        }

        if ($null -eq $currentID) { continue }

        if ($line -match '^TINFO:\d+,9,0,"(.+)"') {
            $Titles[$currentID].Runtime = Convert-RuntimeToSeconds $Matches[1]
        }

        if ($line -match '^TINFO:\d+,8,0,"(\d+)"') {
            $Titles[$currentID].Chapters = [int]$Matches[1]
        }

        if ($line -match '^TINFO:\d+,11,0,"(.+)"') {
            $Titles[$currentID].SizeMB = Convert-SizeToMB $Matches[1]
        }

        if ($line -match '^TINFO:\d+,26,0,"(.+)"') {
            $Titles[$currentID].CellMap = $Matches[1]
        }

        # Video resolution
        if ($line -match '^SINFO:\d+,0,19,0,"(\d+)x(\d+)"') {
            $Titles[$currentID].VideoRes = "$($Matches[1])x$($Matches[2])"
        }

        # Detect audio track header
        if ($line -match '^SINFO:\d+,\d+,1,6202,"Audio"') {
            $currentTrackType = 'Audio'
            continue
        }

        # Detect subtitle track header
        if ($line -match '^SINFO:\d+,\d+,1,6203,"Subtitles"') {
            $currentTrackType = 'Subtitles'
            continue
        }

        # Capture description for audio/subtitles
        if ($line -match '^SINFO:\d+,\d+,30,0,"(.+)"') {
            switch ($currentTrackType) {
                'Audio'     { $Titles[$currentID].Audio     += $Matches[1] }
                'Subtitles' { $Titles[$currentID].Subtitles += $Matches[1] }
            }
        }
    }

    # Enhanced validation 
    foreach ($t in $Titles.Values) { 
        $hasEnglish51 = ($t.Audio | Where-Object{ $_ -match '(?i)(english|eng).*(5\.1)'}).Count -ge 0
        $subtitleLanguages = $t.Subtitles | 
            ForEach-Object { 
                if ($_ -match '(English|French|Spanish|Portuguese|German|Italian)') { 
                    $Matches[1] } 
                } | 
                Sort-Object -Unique 
        $hasMultipleSubs = $subtitleLanguages.Count -ge 2
        $validResolution = $t.VideoRes -match '720x480|720x576' 
        $validChapters = $t.Chapters -ge 12 
        $validRuntime = $t.Runtime -ge (90 * 60) 
        $validSize = $t.SizeMB -ge 100 
        $suspiciousCellMap = $t.CellMap -match '\d{3,}' 
        
        if ($validRuntime -and 
            $validChapters -and 
            $validSize -and 
            $validResolution -and 
            $hasEnglish51 -and 
            $hasMultipleSubs -and 
            -not $suspiciousCellMap) { 
                $t.Valid = $true 
        } 
    }

    $MakeMKVTitles = @($Titles.Values | Where-Object { $_.Valid -eq $true })    
    
    Write-Log "MakeMKV found $($MakeMKVTitles.Count) valid titles."
}

# ============================================================
# HANDBRAKE FALLBACK SCANNING
# ============================================================

function Invoke-HandBrakeFallback {
    Write-Log "Starting HandBrakeCLI fallback scan..."

    $HBScanLog = Join-Path $LogDir "HandBrake_Scan_$TimeStamp.txt"

    #$HBOutput = & $HandBrakeCLI --scan --input "E:\VIDEO_TS" 2>&1 #Location on server
    $HBOutput = & $HandBrakeCLI --scan --input "D:\VIDEO_TS" 2>&1 #Location on Laptop
    $HBOutput | Out-File -FilePath $HBScanLog -Encoding UTF8

    if ($LASTEXITCODE -ne 0 -or $HBOutput.Count -eq 0) {
        Write-Log "HandBrakeCLI fallback scan failed."
        return $null
    }

    $HB_Titles = @()
    $current = $null

    foreach ($line in $HBOutput) {

        if ($line -match '^\s*\+\s+title\s+(\d+):') {
            if ($current) { $HB_Titles += $current }
            $current = [ordered]@{
                ID       = [int]$Matches[1]
                Runtime  = $null
                Chapters = $null
                SizeMB   = $null
                Valid    = $false
            }
        }

        if (-not $current) { continue }

        if ($line -match 'duration:\s+(\d+:\d{2}:\d{2})') {
            $current.Runtime = Convert-RuntimeToSeconds $Matches[1]
        }

        if ($line -match 'chapters:\s+(\d+)') {
            $current.Chapters = [int]$Matches[1]
        }

        if ($line -match 'size:\s+([\d\.]+\s*(GB|MB))') {
            $current.SizeMB = Convert-SizeToMB $Matches[1]
        }
    }

    if ($current) { $HB_Titles += $current }

    foreach ($t in $HB_Titles) {
        if ($t.Runtime -ge 120 -and $t.SizeMB -ge 100) {
            $t.Valid = $true
        }
    }

    $valid = $HB_Titles | Where-Object { $_.Valid -eq $true }
    Write-Log "HandBrakeCLI found $($valid.Count) valid titles."

    return $valid
}

# ============================================================
# VERSION DETECTION (Movies Only)
# ============================================================

function Resolve-Versions {
    param(
        [array]$Titles,
        [string]$DiscType
    )

    Write-Log "Detecting movie versions..."

    if ($Titles.Count -eq 1) {
        Write-Log "Only one valid title no version suffix required."
        return @{ ($Titles[0].ID) = "" }
    }

    $sorted = $Titles | Sort-Object Runtime
    $shortest = $sorted[0]
    $longest = $sorted[-1]

    $VersionMap = @{}

    # Theatrical = shortest
    $VersionMap[$shortest.ID] = "Theatrical"
    Write-Log "Assigned Theatrical to title $($shortest.ID)."

    # Extended = longest
    if ($longest.ID -ne $shortest.ID) {
        $VersionMap[$longest.ID] = "Extended"
        Write-Log "Assigned Extended to title $($longest.ID)."
    }

    # Director's Cut / Alternate
    foreach ($t in $Titles) {
        if ($t.ID -eq $shortest.ID -or $t.ID -eq $longest.ID) { continue }

        if ($t.CellMap -and $shortest.CellMap -and ($t.CellMap -ne $shortest.CellMap)) {
            $VersionMap[$t.ID] = "Directors Cut"
            Write-Log "Assigned Directors Cut to title $($t.ID) (cell map differs)."
            continue
        }

        $diff = [math]::Abs($t.Runtime - $shortest.Runtime)

        if ($diff -le 300) {
            $VersionMap[$t.ID] = "Alternate"
            Write-Log "Assigned Alternate to title $($t.ID) (runtime close to theatrical)."
            continue
        }

        $VersionMap[$t.ID] = "Alternate"
        Write-Log "Assigned Alternate to title $($t.ID) (fallback)."
    }

    return $VersionMap
}

# ============================================================
# NAMING LOGIC (Movies)
# ============================================================

# Remove illegal filename characters
function Convert-FilenameSafe {
    param([string]$Name)

    $clean = $Name -replace '[^\w\-. ]', ''
    return $clean.Trim()
}

# ------------------------------
# Movie naming
# ------------------------------
function Get-MovieOutputPath {
    param(
        [string]$Title,
        [string]$Year,
        [string]$VersionSuffix
    )

    $cleanTitle = $Title -replace ':', '-'
    $movieFolder = Join-Path $MoviesRoot "$cleanTitle ($Year)"

    if (!(Test-Path $movieFolder)) {
        New-Item -ItemType Directory -Path $movieFolder | Out-Null
        Write-Log "Created movie folder: $movieFolder" | Out-Null
    }

    if ([string]::IsNullOrWhiteSpace($VersionSuffix)) {
        $fileName = "$cleanTitle ($Year).mkv"
    }
    else {
        $fileName = "$cleanTitle ($Year) - $VersionSuffix.mkv"
    }

    return (Join-Path $movieFolder $fileName)
}

# ============================================================
# RIPPING ENGINE
# ============================================================

function Invoke-TitleRip {
    param(
        [int]$TitleID,
        [string]$OutputPath
    )

    Write-Log "Ripping title $TitleID to: $OutputPath"

    $outDir = Split-Path $OutputPath
    if (!(Test-Path $outDir)) {
        New-Item -ItemType Directory -Path $outDir | Out-Null
    }

    # Subtitle embedding logic
    if ($EmbedSubtitles) {
        # Include only English subtitle tracks (forced + full)
        $subtitleFlag = "--subtitle=eng"
    }
    else {
        # No subtitles
        $subtitleFlag = "--subtitle=none"
    }

    # MakeMKV rip command
    $cmd = "`"$MakeMKV`" mkv disc:0 $TitleID `"$outDir`" --minlength=120 $subtitleFlag"
    Write-Log "Running: $cmd"
    & $MakeMKV mkv disc:0 $TitleID $outDir --minlength=120 2>&1 |
    Tee-Object -FilePath (Join-Path $LogDir "Rip_$TimeStamp.txt")

    # Find the output file MakeMKV created
    $rippedFile = Get-ChildItem -Path $outDir -Filter "*.mkv" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

    if ($rippedFile) {
        $finalName = Split-Path $OutputPath -Leaf
        Write-Log "Renaming ripped file: $($rippedFile.Name) $finalName"
        Rename-Item -Path $rippedFile.FullName -NewName $finalName
    }
    else {
        Write-Log "ERROR: MakeMKV did not produce an output file for title $TitleID."
    }
}

# ------------------------------
# Movie Ripping 
# ------------------------------
function Invoke-MovieDiscRip {
    param(
        [array]$Titles,
        [string]$MovieName,
        [string]$Year,
        [hashtable]$VersionMap
    )

    Write-Log "Ripping movie disc: $MovieName ($Year)"

    $outputFiles = @()

    foreach ($t in $Titles) {
        $suffix = $VersionMap[$t.ID]
        $output = Get-MovieOutputPath -Title $MovieName -Year $Year -VersionSuffix $suffix
        Invoke-TitleRip -TitleID $t.ID -OutputPath $output
        $outputFiles += $output
    }

    return $outputFiles
}

# ============================================================
# SUMMARY + EJECT PROMPT + FINALIZATION
# ============================================================

function Show-Summary {
    param(
        [string]$DiscName,
        [string]$DiscType,
        [array]$Titles,
        [hashtable]$VersionMap,
        [string]$MovieName,
        [string]$Year,
        [array]$OutputFiles
    )

    Write-Log "Generating summary..."

    $summary = @()
    $summary += "==============================================="
    $summary += " AutoRip Summary"
    $summary += "==============================================="
    $summary += "Disc Name: $DiscName"
    $summary += "Disc Type: $DiscType"
    $summary += "Year: $Year"

    if ($DiscType -eq "Movie") {
        $summary += "Movie Title: $MovieName"
        $summary += ""
        $summary += "Ripped Versions:"
        foreach ($t in $Titles) {
            $suffix = $VersionMap[$t.ID]
            if ([string]::IsNullOrWhiteSpace($suffix)) { $suffix = "(Theatrical)" }
            $summary += "  Title $($t.ID): $suffix"
        }
    }

    $summary += ""
    $summary += "Output Files:"
    foreach ($f in $OutputFiles) {
        $summary += "  $f"
    }

    $summary += "==============================================="
    $summary += " AutoRip Completed Successfully"
    $summary += "==============================================="

    # Print to console
    $summary | ForEach-Object { Write-Output $_ }

    # Write to log
    $summary | ForEach-Object { Write-Log $_ }
}

# ------------------------------
# Eject Prompt
# ------------------------------
function Show-EjectPrompt {
    Write-Log "Prompting user for disc eject..."

    $eject = Read-UserConfirmation "Eject disc now?" "N"

    if ($eject) {
        Write-Log "Ejecting disc..."
        try {
            # (New-Object -ComObject Shell.Application).NameSpace(17).ParseName("E:").InvokeVerb("Eject") # Location on Server
            (New-Object -ComObject Shell.Application).NameSpace(17).ParseName("D:").InvokeVerb("Eject") # Location on Laptop
        }
        catch {
            Write-Log "Failed to eject disc automatically."
        }
    }
    else {
        Write-Log "User chose not to eject disc."
    }
}

# ------------------------------
# Finalization
# ------------------------------
function Complete-AutoRip {
    Write-Log "=== AutoRip Completed ==="
}

# ============================================================
# MAIN EXECUTION FLOW
# ============================================================

Write-Log "Beginning main execution flow..."

# 1. Burnt DVD detection
# Ask user if this is a burnt DVD
$IsBurnt = Read-UserConfirmation "Is this a burnt or home-authored DVD?" "N"
#$IsBurnt = Detect-BurntDVD -MakeMKVTitles $MakeMKVTitles

# 2. If burnt or MakeMKV incomplete HandBrake fallback
if ($IsBurnt -or $MakeMKVTitles.Count -eq 0) {
    Write-Log "Using HandBrake fallback titles..."
    $Titles = Invoke-HandBrakeFallback
}
else {
    $Titles = $MakeMKVTitles
}

if ($null -eq $Titles -or $Titles.Count -eq 0) {
    Write-Log "ERROR: No valid titles found after all scanning."
    Complete-AutoRip
    exit
}

if([string]::IsNullOrWhiteSpace($DiscName) -or $DiscName -eq "Unknown_Disc"){
    $DiscName = Read-Host "Enter movie name: "
}

$MovieName = $DiscName
$MovieInfo = Get-MovieYearFromTMDb -DiscName $MovieName -ApiKey "c358ede5f926f6b1b1b81c719fb59b68"

$Year = $MovieInfo.Year

# Version detection
$VersionMap = Resolve-Versions -Titles $MakeMKVTitles -DiscType "Movie"

# Rip
$OutputFiles = Invoke-MovieDiscRip -Titles $MakeMKVTitles -MovieName $MovieInfo.Title -Year $Year -VersionMap $VersionMap[2]

    # Summary
Show-Summary -DiscName $DiscName -DiscType "Movie" -Titles $Titles -VersionMap $VersionMap[2] `
    -MovieName $MovieName -Year $Year -OutputFiles $OutputFiles

# 5. Eject prompt
Show-EjectPrompt

# 6. Finalize
Complete-AutoRip