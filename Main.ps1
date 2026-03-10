# Main.ps1 - v1.0.0

. "$PSScriptRoot\Config.ps1"
. "$PSScriptRoot\Utilities.ps1"

Write-Log "=== AutoRip Started ==="

$discType = & "$PSScriptRoot\Detect-DiscType.ps1"

$mk = & "$PSScriptRoot\Scan-MakeMKV.ps1" -DiscType $discType

if ($mk -and $mk.Count -gt 0) {
    Write-Log "Using MakeMKV..."
    $discName = $mk.DiscName 
    $titles = $mk.Titles
}
else {
    Write-Log "MakeMKV Failed. Trying HandBrake fallback..."
    $hb = & "$PSScriptRoot\Scan-HandBrake.ps1" -DiscType $discType

    if ($hb -and $hb.Titles.Count -gt 0) { 
        Write-Log "Using HandBrake titles." 
        $discName = $hb.DiscName 
        $titles = $hb.Titles 
    } else { 
        Write-Log "ERROR: Disc unreadable by both MakeMKV and HandBrake." 
        Write-Host "Disc unreadable by both MakeMKV and HandBrake." 
        exit 
    }
}

Write-Log "Final detected disc name: $discName"

switch ($discType) {
    "DVDMovie"      { & "$PSScriptRoot\Rip-Movie.ps1" -Titles $titles -DiscName $discName }
    "DVDTV"         { & "$PSScriptRoot\Rip-TV.ps1"    -Titles $title -DiscName $discName }
    "BurntDVD"      { & "$PSScriptRoot\Rip-TV.ps1"    -Titles $titles -DiscName $discName }
    "BluRayMovie"   { & "$PSScriptRoot\Rip-BluRay.ps1"    -Titles $titles -DiscType $discType -DiscName $discName }
    "BluRayTV"      { & "$PSScriptRoot\Rip-BluRay.ps1"    -Titles $titles -DiscType $discType -DiscName $discName }
}

if ($global:LastOutputFiles) { 
    
    # Determine TMDb metadata if available 
    $tmdbTitle = $null 
    $tmdbYear = $null 
    
    if ($global:TMDbMovieInfo) { 
        $tmdbTitle = $global:TMDbMovieInfo.Title 
        $tmdbYear = $global:TMDbMovieInfo.Year 
    } 
    
    & "$PSScriptRoot\Show-Summary.ps1" `
    -DiscName $discName `
    -DiscType $discType `
    -Titles $titles `
    -OutputRoot $MoviesRoot `
    -TMDbTitle $tmdbTitle `
    -TMDbYear $tmdbYear `
    -OutputFiles $global:LastOutputFiles 
} else { 
    Write-Log "WARNING: No output files were recorded by rippers." 

}

Invoke-DiscEject -DriveLetter "D:" 

Write-Log "=== AutoRip Completed ===" 
Write-Host "AutoRip Completed."
