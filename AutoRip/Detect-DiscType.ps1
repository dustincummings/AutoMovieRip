# Detect-DiscType - v1.0.0

. "$PSScriptRoot\Utilities.ps1"

Write-Log "Detecting disc type..."

# Ask user if disc is Blu-ray
if (Read-YesNo "Is this a Blu-ray disc?" "N") {

    if (Read-YesNo "Is this a TV series Blu-ray?" "N") {
        return "BluRayTV"
    }
    else {
        return "BluRayMovie"
    }
}

# DVD logic
if (Read-YesNo "Is this a burnt or home-authored DVD?" "N") {
    return "BurntDVD"
}

if (Read-YesNo "Is this a TV series DVD?" "N") {
    return "DVDTV"
}

return "DVDMovie"
