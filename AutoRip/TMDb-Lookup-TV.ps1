# TMDb-Lookup-TV.ps1 - v1.0.0

param(
    [string]$ShowName,
    [int]$Season,
    [string]$ApiKey
)

. "$PSScriptRoot\Utilities.ps1"

Write-Log "Querying TMDb (TV) for '$ShowName' (Season $Season)..."

$QueryTitle = ($ShowName -replace '_',' ' -replace '\s+',' ').Trim()
$Query = [System.Web.HttpUtility]::UrlEncode($QueryTitle)

$Url = "https://api.themoviedb.org/3/search/tv?api_key=$ApiKey&query=$Query"

try {
    $response = Invoke-RestMethod -Uri $Url -Method Get
}
catch {
    Write-Log "TMDb TV lookup failed: $_"
    return $null
}

$results = $response.results

if (-not $results -or $results.Count -eq 0) {
    Write-Host "No TMDb TV results found for '$ShowName'"
    Write-Log "TMDb returned no TV results."
    return $null
}

Write-Host ""
Write-Host "Possible TV matches from TMDb:"
Write-Host "--------------------------------"

for ($i = 0; $i -lt $results.Count; $i++) {
    $name = $results[$i].name
    $date = $results[$i].first_air_date
    Write-Host "[$($i+1)] $name ($date)"
}

Write-Host ""
$choice = Read-Host "Enter the number of the correct show (or press Enter to cancel)"

if ([string]::IsNullOrWhiteSpace($choice)) {
    Write-Host "No selection made."
    return $null
}

if ($choice -notmatch '^\d+$' -or $choice -lt 1 -or $choice -gt $results.Count) {
    Write-Host "Invalid selection."
    return $null
}

$selected = $results[$choice - 1]
$showId   = $selected.id

# Fetch season metadata
$SeasonUrl = "https://api.themoviedb.org/3/tv/$showId/season/$Season?api_key=$ApiKey"

try {
    $seasonData = Invoke-RestMethod -Uri $SeasonUrl -Method Get
}
catch {
    Write-Log "TMDb season lookup failed: $_"
    return $null
}

$episodes = $seasonData.episodes

if (-not $episodes -or $episodes.Count -eq 0) {
    Write-Host "No episodes found for Season $Season."
    Write-Log "TMDb returned no episodes for Season $Season."
    return $null
}

return [PSCustomObject]@{
    ShowName = $selected.name
    ShowID   = $showId
    Season   = $Season
    Episodes = $episodes
}
