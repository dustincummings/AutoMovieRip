# TMDb-Lookup-Movie - v1.0.0

param(
    [string]$DiscName,
    [string]$ApiKey
)

. "$PSScriptRoot\Utilities.ps1"

Write-Log "Querying TMDb (movie) for '$DiscName'..."

# Clean disc name
$QueryTitle = ($DiscName -replace '_',' ' -replace '\s+',' ').Trim()
$Query = [System.Web.HttpUtility]::UrlEncode($QueryTitle)

$Url = "https://api.themoviedb.org/3/search/movie?api_key=$ApiKey&query=$Query"

try {
    $response = Invoke-RestMethod -Uri $Url -Method Get
}
catch {
    Write-Log "TMDb lookup failed: $_"
    return $null
}

$results = $response.results

if (-not $results -or $results.Count -eq 0) {
    Write-Host "No TMDb results found for '$DiscName'"
    Write-Log "TMDb returned no results."
    return $null
}

Write-Host ""
Write-Host "Possible matches from TMDb:"
Write-Host "--------------------------------"

for ($i = 0; $i -lt $results.Count; $i++) {
    $title = $results[$i].title
    $date  = $results[$i].release_date
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

$selected = $results[$choice - 1]

# Extract year
$year = $null
if ($selected.release_date -match '^(\d{4})') {
    $year = $Matches[1]
}

return [PSCustomObject]@{
    Title = $selected.title
    Year  = $year
    ID    = $selected.id
    Raw   = $selected
}
