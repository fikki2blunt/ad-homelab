<#
.SYNOPSIS
    Processes a leaver: disable, scramble password, remove groups, move to Disabled Users.
.DESCRIPTION
    The account is disabled, not deleted, so access can be restored or audited.
    Group memberships are saved to a text file first, so they can be put back
    if the account is ever re-enabled. Domain Users is the primary group and
    stays (AD doesn't allow removing it).
.EXAMPLE
    & C:\LabScripts\leaver.ps1 -Username dosei -Ticket REQ-004
.EXAMPLE
    Add -WhatIf to see what would happen without changing anything.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$Username,
    [Parameter(Mandatory)][string]$Ticket
)

$disabledOU = "OU=Disabled Users,DC=lab,DC=local"
$user = Get-ADUser -Filter "SamAccountName -eq '$Username'" -Properties MemberOf

if (-not $user) {
    Write-Host "User '$Username' not found. Check the username." -ForegroundColor Red
    return
}
if ($user.DistinguishedName -like "*$disabledOU") {
    Write-Host "'$Username' is already in Disabled Users - nothing to do." -ForegroundColor Yellow
    return
}

$today  = Get-Date -Format yyyy-MM-dd
$groups = $user.MemberOf | ForEach-Object { (Get-ADGroup $_).Name }

if ($PSCmdlet.ShouldProcess($Username, "Disable, scramble password, remove $($groups.Count) group(s), move to Disabled Users")) {

    # 1. Record group memberships before removing them
    $logDir  = Join-Path $PSScriptRoot "leavers"
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    $logFile = Join-Path $logDir "$Username-$today.txt"
    $groups | Set-Content $logFile
    Write-Host "Saved $($groups.Count) group(s) to $logFile"

    # 2. Disable the account (blocks sign-in immediately)
    Disable-ADAccount -Identity $user
    Write-Host "Disabled $Username"

    # 3. Scramble the password with a cryptographically random value nobody knows
    $chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%&*?'
    $bytes = New-Object byte[] 24
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $random = (-join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })) + 'Aa1!'
    Set-ADAccountPassword -Identity $user -Reset -NewPassword (ConvertTo-SecureString $random -AsPlainText -Force)
    Remove-Variable random
    Write-Host "Password scrambled"

    # 4. Remove from every group (removes access to shares, apps, printers)
    foreach ($g in $user.MemberOf) {
        Remove-ADGroupMember -Identity $g -Members $user -Confirm:$false
    }
    Write-Host "Removed from: $($groups -join ', ')"

    # 5. Note what happened on the account itself
    Set-ADUser -Identity $user -Description "Leaver - disabled $today ($Ticket). Groups saved in leavers\$Username-$today.txt"

    # 6. Move to Disabled Users (done last, because moving changes the account's DN)
    Move-ADObject -Identity $user.DistinguishedName -TargetPath $disabledOU
    Write-Host "Moved to Disabled Users" -ForegroundColor Green

    Get-ADUser $Username -Properties Description, MemberOf |
        Select-Object Name, Enabled, DistinguishedName, Description,
            @{ n = "Groups left"; e = { $_.MemberOf.Count } }
}
