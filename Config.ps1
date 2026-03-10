# Config.ps1 v1.0.0

$EmbedSubtitles = $true

$MakeMKV = "C:\Program Files (x86)\MakeMKV\makemkvcon.exe"
#$HandBrakeCLI = "C:\Program Files\HandBrakeCLI\HandBrakeCLI.exe"  #Location on Server
$HandBrakeCLI = "C:\Program Files\HandBrake\HandBrakeCLI.exe" #Location on Laptop

$MoviesRoot = "C:\Users\dusti\Videos" #UPDATE THIS TO WHERE IT GOES
$TVRoot     = "C:\Users\dusti\Videos\TV" #UPDATE THIS TO WHERE IT GOES

$TMDbApiKey = "c358ede5f926f6b1b1b81c719fb59b68"

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogDir = Join-Path $ScriptRoot "Logs"

if (!(Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir | Out-Null
}

$TimeStamp = (Get-Date).ToString("yyyy-MM-dd_HH-mm-ss")
$MainLog = Join-Path $LogDir "AutoRip_$TimeStamp.log"
