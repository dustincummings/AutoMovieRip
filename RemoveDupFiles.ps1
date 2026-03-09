# Folder containing the "good" copies you want to keep
$KeepFolder = "C:\RecoveryShare\KeepThisOne"

# Folders where duplicates should be deleted
$OtherFolders = @(
    "C:\RecoveryShare\Recovery_Direct.1",
    "C:\RecoveryShare\Recovery_Direct.2",
    "C:\RecoveryShare\Recovery_Direct.3",
    "C:\RecoveryShare\Recovery_Direct.4",
    "C:\RecoveryShare\Recovery_Direct.5",
    "C:\RecoveryShare\Recovery_Direct.6",
    "C:\RecoveryShare\Recovery_Direct.7",
    "C:\RecoveryShare\Recovery_Direct.8",
    "C:\RecoveryShare\Recovery_Direct.9",
    "C:\RecoveryShare\Recovery_Direct.10",
    "C:\RecoveryShare\Recovery_Direct.11"
)

# Log file
$LogFile = "C:\RecoveryShare\KeepThisOne\deleted_duplicates.csv"
$Log = @()

Write-Host "Hashing KeepOne files..."
$KeepHashes = Get-ChildItem -Path $KeepFolder -File -Recurse |
    Get-FileHash -Algorithm SHA256 |
    Select-Object Hash, Path

Write-Host "Hashing other folders..."
$OtherFiles = foreach ($folder in $OtherFolders) {
    Get-ChildItem -Path $folder -File -Recurse -ErrorAction SilentlyContinue
}

$OtherHashes = $OtherFiles |
    Get-FileHash -Algorithm SHA256 |
    Select-Object Hash, Path

Write-Host "Comparing and deleting duplicates..."
foreach ($keep in $KeepHashes) {
    $filesMatched = $OtherHashes | Where-Object { $_.Hash -eq $keep.Hash }

    foreach ($match in $filesMatched) {
        try {
            Remove-Item -Path $match.Path -Force
            Write-Host "Deleted duplicate: $($match.Path)"

            $Log += [PSCustomObject]@{
                Hash = $keep.Hash
                KeepFile = $keep.Path
                DeletedFile = $match.Path
            }
        }
        catch {
            Write-Warning "Failed to delete $($match.Path): $_"
        }
    }
}

$Log | Export-Csv -Path $LogFile -NoTypeInformation
Write-Host "Done. Log saved to $LogFile"
