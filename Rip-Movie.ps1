# Rip-Movie.ps1 - v1.0.0

param(
    [array]$Titles,
    [string]$DiscName
)

. "$PSScriptRoot\Config.ps1"
. "$PSScriptRoot\Utilities.ps1"
. "$PSScriptRoot\Common-Rip.ps1"

Write-Log "Starting movie rip workflow..."

# Ask user for TMDb search name (default = detected DiscName)
$searchName = Read-Host "TMDb search name (Enter to use '$DiscName')"
if ([string]::IsNullOrWhiteSpace($searchName)) {
    $searchName = $DiscName
}

# TMDb lookup
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

Write-Log "Movie identified as: $movieName ($year)"

# Create output folder
$cleanTitle = $movieName -replace ':', '-'
$folder = Join-Path $MoviesRoot "$cleanTitle ($year)"
if (!(Test-Path $folder)) {
    New-Item -ItemType Directory -Path $folder | Out-Null
}

# Rip each valid title
foreach ($t in $Titles) {
    $output = Join-Path $folder "$movieName ($year).mkv"
    Invoke-Rip -TitleID $t.ID -OutputPath $output

    if (-not $global:LastOutputFiles) { 
        $global:LastOutputFiles = @() 
    } 
    $global:LastOutputFiles += $output
}

Write-Log "Movie rip completed."
