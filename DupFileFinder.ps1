# Folders to scan
$SourceFolders = @(
    "C:\RecoveryShare\RecoveredFiles",
    "C:\RecoveryShare\RecoveredFiles.1",
    "C:\RecoveryShare\RecoveredFiles.2",
    "C:\RecoveryShare\RecoveredFiles.3",
    "C:\RecoveryShare\RecoveredFiles.4",
    "C:\RecoveryShare\RecoveredFiles.5",
    "C:\RecoveryShare\RecoveredFiles.6",
    "C:\RecoveryShare\RecoveredFiles.7",
    "C:\RecoveryShare\RecoveredFiles.8",
    "C:\RecoveryShare\RecoveredFiles.9",
    "C:\RecoveryShare\RecoveredFiles.10",
    "C:\RecoveryShare\RecoveredFiles.11",
    "C:\RecoveryShare\RecoveredFiles.12",
    "C:\RecoveryShare\RecoveredFiles_FullRun",
    "C:\RecoveryShare\RecoveredFiles_FullRun.1",
    "C:\RecoveryShare\RecoveredFiles_FullRun.2",
    "C:\RecoveryShare\RecoveredFiles_FullRun.3",
    "C:\RecoveryShare\RecoveredFiles_FullRun.4",
    "C:\RecoveryShare\RecoveredFiles_new",
    "C:\RecoveryShare\RecoveredFiles_new.1",
    "C:\RecoveryShare\RecoveredFiles_new.2",
    "C:\RecoveryShare\RecoveredFiles_new.3",
    "C:\RecoveryShare\RecoveredFiles_new.4",
    "C:\RecoveryShare\RecoveredFiles_new.5",
    "C:\RecoveryShare\RecoveredFiles_new.6",
    "C:\RecoveryShare\RecoveredFiles_new.7",
    "C:\RecoveryShare\RecoveredFiles_new.8",
    "C:\RecoveryShare\RecoveredFiles_new.9",
    "C:\RecoveryShare\RecoveredFiles_new.10",
    "C:\RecoveryShare\RecoveredFiles_new.11",
    "C:\RecoveryShare\RecoveredFiles_new.12",
    "C:\RecoveryShare\RecoveredFiles_new.13"
)

# Folder where one copy of each file will be moved
$Destination = "C:\RecoveryShare\KeepThisOne"
New-Item -ItemType Directory -Force -Path $Destination | Out-Null

# Collect all files
$Files = foreach ($folder in $SourceFolders) {
    Get-ChildItem -Path $folder -Recurse -File -ErrorAction SilentlyContinue
}

# Hash files and group by content
$HashGroups = $Files |
    Get-FileHash -Algorithm SHA256 |
    Group-Object Hash

# Process each group
$Log = @()

foreach ($group in $HashGroups) {
    $filesInGroup = $group.Group

    if ($filesInGroup.Count -gt 1) {
        # Pick the first file to move
        $fileToMove = $filesInGroup[0].Path
        $fileName = Split-Path $fileToMove -Leaf
        $destPath = Join-Path $Destination $fileName

        # Ensure unique name in destination
        $destPath = [System.IO.Path]::Combine(
            $Destination,
            [System.IO.Path]::GetFileNameWithoutExtension($fileName) +
            "_" + $group.Hash.Substring(0,8) +
            [System.IO.Path]::GetExtension($fileName)
        )

        Move-Item -Path $fileToMove -Destination $destPath

        $Log += [PSCustomObject]@{
            Hash = $group.Hash
            Moved = $destPath
            DuplicatesLeft = ($filesInGroup | Select-Object -ExpandProperty Path) -ne $fileToMove
        }
    }
}

# Save log
$Log | Export-Csv -Path "$Destination\duplicate_log.csv" -NoTypeInformation

Write-Host "Done. One copy of each duplicate group moved to $Destination"
