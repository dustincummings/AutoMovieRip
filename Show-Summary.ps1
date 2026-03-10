# Show-Summary.ps1 - v1.2.0

param(
    [string]$DiscName,
    [string]$DiscType,
    [array]$Titles,
    [string]$OutputRoot,
    [string]$TMDbTitle,
    [string]$TMDbYear,
    [array]$OutputFiles
)

. "$PSScriptRoot\Config.ps1"
. "$PSScriptRoot\Utilities.ps1"

Write-Log "Generating summary..."

$summary = @()
$summary += "==============================================="
$summary += " AutoRip Summary"
$summary += "==============================================="
$summary += "Disc Name: $DiscName"
$summary += "Disc Type: $DiscType"

if ($TMDbTitle) {
    $summary += "TMDb Title: $TMDbTitle"
}
if ($TMDbYear) {
    $summary += "TMDb Year:  $TMDbYear"
}

$summary += ""
$summary += "Ripped Titles:"
foreach ($t in $Titles) {
    $summary += "  Title ID $($t.ID) - Runtime: $($t.Runtime) sec"
}

$summary += ""
$summary += "Output Files:"
foreach ($f in $OutputFiles) {
    $summary += "  $f"
}

$summary += ""
$summary += "Logs:"
$summary += "  Main Log: $MainLog"
$summary += "  MakeMKV Scan Log: MakeMKV_Scan_$TimeStamp.txt"
$summary += "  HandBrake Scan Log: HandBrake_Scan_$TimeStamp.txt"

$summary += "==============================================="
$summary += " AutoRip Completed Successfully"
$summary += "==============================================="

# Print to console
$summary | ForEach-Object { Write-Output $_ }

# Write to log
$summary | ForEach-Object { Write-Log $_ }
