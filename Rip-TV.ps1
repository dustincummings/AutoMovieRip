# Rip-TV.ps1 - v1.2.0

param(
    [array]$Titles,
    [string]$DiscName
)

. "$PSScriptRoot\Config.ps1"
. "$PSScriptRoot\Utilities.ps1"
. "$PSScriptRoot\Common-Rip.ps1"

Write-Log "Starting TV rip workflow..."

# Ask user for TMDb search name (default = detected DiscName)
$showInput = Read-Host "Enter show name (Enter to use '$DiscName')"
if ([string]::IsNullOrWhiteSpace($showInput)) {
    $showInput = $DiscName
}

$seasonInput = Read-Host "Enter season number"
[int]$season = $seasonInput

# TMDb lookup
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

Write-Log "TV Show identified as: $showName (Season $season)"

# Create season folder
$seasonFolder = Join-Path $TVRoot "$showName\Season $('{0:D2}' -f $season)"
if (!(Test-Path $seasonFolder)) {
    New-Item -ItemType Directory -Path $seasonFolder -Force | Out-Null
}

# Rip episodes
$episodeIndex = 0

foreach ($t in $Titles) {

    $episodeNumber = $episodeIndex + 1
    $epTag = "S{0:D2}E{1:D2}" -f $season, $episodeNumber

    # Episode name from TMDb if available
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

Write-Log "TV rip completed."
