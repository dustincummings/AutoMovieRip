# Common-Rip.ps1 - v1.0.0

function Invoke-Rip {
    param(
        [int]$TitleID,
        [string]$OutputPath
    )

    . "$PSScriptRoot\Config.ps1"
    . "$PSScriptRoot\Utilities.ps1"

    Write-Log "Ripping title $TitleID to $OutputPath"

    $outDir = Split-Path $OutputPath
    if (!(Test-Path $outDir)) {
        New-Item -ItemType Directory -Path $outDir | Out-Null
    }

    if ($EmbedSubtitles) { 
        $subtitleFlag = "--subtitle=eng" 
    } else { 
        $subtitleFlag = "--subtitle=none" 
    }

    & $MakeMKV mkv disc:0 $TitleID $outDir --minlength=120 $subtitleFlag 2>&1 |
        Tee-Object -FilePath (Join-Path $LogDir "Rip_$TimeStamp.txt")

    $ripped = Get-ChildItem -Path $outDir -Filter "*.mkv" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if ($ripped) {
        Rename-Item -Path $ripped.FullName -NewName (Split-Path $OutputPath -Leaf)
    }
    else {
        Write-Log "ERROR: MakeMKV did not produce an output file for title $TitleID."
    }
}
