# Scan-HandBrake.ps - v1.0.0

param([string] $DiscType)

. "$PSScriptRoot\Config.ps1"
. "$PSScriptRoot\Utilities.ps1"

Write-Log "Running HandBrake fallback scan..."

$HBScanLog = Join-Path $LogDir "HandBrake_Scan_$TimeStamp.txt"

$output = & $HandBrakeCLI --scan --input "D:\VIDEO_TS" 2>&1
$output | Out-File -FilePath $HBScanLog -Encoding UTF8

# Extract DiscName if present 
$discName = "Unknown Disc" 
foreach ($line in $output) { 
    if ($line -match 'DVD Title:\s*(.+)$') { 
        $discName = $Matches[1].Trim() 
        break 
    } 
} 

Write-Log "HandBrake detected disc name: $discName"
Write-Host "HandBrake detected disc name: $discName"

$UserInput = Read-Host "Press Enter to accept, or type a different name"

if([string]::IsNullOrWhiteSpace($UserInput)){
    $DiscName = $discName
    Write-Log "User kept discName: $discName"
} else {
    $DiscName = $UserInput.Trim()
    Write-Log "User updated Disc Name: $DiscName"
}

#HandBrake cannot read encrypted Blu-Ray
if ($DiscType -like "Blu-Ray*" -and $output -match "libblureay failed"){
    Write-Log "HandBrake cannot read encrypted Blu-ray. Skipping fallback"
    return $null
}

if ($LASTEXITCODE -ne 0 -or $output.Count -eq 0) {
    Write-Log "HandBrake returned no usable data."
    return $null
}

$titles = @()
$current = $null

foreach ($line in $output) {
    if ($line -match '^\s*\+\s+title\s+(\d+):') {
        if ($current) { $titles += $current }
        $current = [ordered]@{
            ID = [int]$Matches[1]
            Runtime = $null
            Chapters = $null
            SizeMB = $null
            Valid = $false
        }
    }

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

if ($current) { $titles += $current }

foreach ($t in $titles) {
    if ($t.Runtime -ge 120 -and $t.SizeMB -ge 100) {
        $t.Valid = $true
    }
}

$valid = $titles | Where-Object { $_.Valid }

Write-Log "HandBrake found $($valid.Count) valid titles."

return [PSCustomObject]@{ 
    DiscName = $discName 
    Titles = $valid 
}