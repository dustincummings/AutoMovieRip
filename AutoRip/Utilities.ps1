function Write-Log {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date), $Message
    Write-Output $line
    Add-Content -Path $MainLog -Value $line
}

function Read-YesNo {
    param([string]$Prompt, [string]$Default = "N")
    $response = Read-Host "$Prompt (Y/N) [Default: $Default]"
    if ([string]::IsNullOrWhiteSpace($response)) { $response = $Default }
    return ($response.ToUpper() -eq "Y")
}

function Convert-RuntimeToSeconds {
    param([string]$Runtime)
    if ($Runtime -match "^\d+:\d{2}:\d{2}$") {
        $p = $Runtime.Split(":")
        return ([int]$p[0] * 3600) + ([int]$p[1] * 60) + ([int]$p[2])
    }
    return $null
}

function Convert-SizeToMB {
    param([string]$Size)
    if ($Size -match "GB") { return [math]::Round(([double]($Size -replace "GB","")) * 1024) }
    if ($Size -match "MB") { return [math]::Round([double]($Size -replace "MB","")) }
    return $null
}

function Invoke-DiscEject { 
    param( [string]$DriveLetter = "D:" ) 

    Write-Log "Prompting user for disc eject..." 
    $eject = Read-YesNo "Eject disc now?" "N" 
    
    if ($eject) { 
        Write-Log "Attempting to eject disc from $DriveLetter..." 
        
        try { 
            $shell = New-Object -ComObject Shell.Application 
            $shell.NameSpace(17).ParseName($DriveLetter).InvokeVerb("Eject") 
            
            Write-Log "Disc ejected successfully."
        } 
        catch { 
            Write-Log "ERROR: Failed to eject disc automatically. $_" 
        } 
    } else { 
        Write-Log "User chose not to eject disc." 
    }
}