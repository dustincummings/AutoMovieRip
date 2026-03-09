# Rip-BluRay.ps1 - v1.2.0

param(
    [array]$Titles,
    [string]$DiscType,
    [string]$DiscName
)

. "$PSScriptRoot\Config.ps1"
. "$PSScriptRoot\Utilities.ps1"
. "$PSScriptRoot\Common-Rip.ps1"

Write-Log "Starting Blu-ray rip workflow..."

# ------------------------------------------------------------
# BLU-RAY MOVIE
# ------------------------------------------------------------
if ($DiscType -eq "BluRayMovie") {

    $searchName = Read-Host "TMDb search name (Enter to use '$DiscName')"
    if ([string]::IsNullOrWhiteSpace($searchName)) {
        $searchName = $DiscName
    }

    $movieInfo = & "$PSScriptRoot\TMDb-Lookup-Movie.ps1" -DiscName $searchName -ApiKey $TMDbApiKey

    if (-not $movieInfo) {
        Write-Host "TMDb lookup failed or cancelled. Falling back to manual entry."
        $movieName = Read-Host "Enter movie name"
        $year      = Read-Host "Enter release year"
    }
    else {
        $movieName = $movieInfo.Title
        $year      = $movieInfo.Year
    }

    Write-Log "Blu-ray Movie identified as: $movieName ($year)"

    $folder = Join-Path $MoviesRoot "$movieName ($year)"
    if (!(Test-Path $folder)) {
        New-Item -ItemType Directory -Path $folder | Out-Null
    }

    foreach ($t in $Titles) {
        $output = Join-Path $folder "$movieName ($year).mkv"
        Invoke-Rip -TitleID $t.ID -OutputPath $output

        if (-not $global:LastOutputFiles) { 
            $global:LastOutputFiles = @() 
        } 
        $global:LastOutputFiles += $output
    }

    Write-Log "Blu-ray movie rip completed."
    return
}

# ------------------------------------------------------------
# BLU-RAY TV
# ------------------------------------------------------------
if ($DiscType -eq "BluRayTV") {

    $showInput = Read-Host "Enter show name (Enter to use '$DiscName')"
    if ([string]::IsNullOrWhiteSpace($showInput)) {
        $showInput = $DiscName
    }

    $seasonInput = Read-Host "Enter season number"
    [int]$season = $seasonInput

    $tvInfo = & "$PSScriptRoot\TMDb-Lookup-TV.ps1" -ShowName $showInput -Season $season -ApiKey $TMDbApiKey

    if (-not $tvInfo) {
        Write-Host "TMDb TV lookup failed or cancelled. Falling back to manual naming."
        $showName = $showInput
        $episodesMeta = $null
    }
    else {
        $showName = $tvInfo.ShowName
        $episodesMeta = $tvInfo.Episodes
    }

    Write-Log "Blu-ray TV identified as: $showName (Season $season)"

    $seasonFolder = Join-Path $TVRoot "$showName\Season $('{0:D2}' -f $season)"
    if (!(Test-Path $seasonFolder)) {
        New-Item -ItemType Directory -Path $seasonFolder -Force | Out-Null
    }

    $episodeIndex = 0

    foreach ($t in $Titles) {

        $episodeNumber = $episodeIndex + 1
        $epTag = "S{0:D2}E{1:D2}" -f $season, $episodeNumber

        $epName = $null
        if ($episodesMeta -and $episodeNumber -le $episodesMeta.Count) {
            $epName = $episodesMeta[$episodeIndex].name
        }

        if ([string]::IsNullOrWhiteSpace($epName)) {
            $fileName = "$showName - $epTag.mkv"
        }
        else {
            $safeEpName = ($epName -replace '[^\w\-. ]','').Trim()
            $fileName = "$showName - $epTag - $safeEpName.mkv"
        }

        $output = Join-Path $seasonFolder $fileName

        Invoke-Rip -TitleID $t.ID -OutputPath $output

        if (-not $global:LastOutputFiles) { 
            $global:LastOutputFiles = @() 
        } 
        $global:LastOutputFiles += $output

        $episodeIndex++
    }

    Write-Log "Blu-ray TV rip completed."
}
