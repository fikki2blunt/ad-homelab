<#
.SYNOPSIS
    Creates a new starter's account and adds it to their department group.
.DESCRIPTION
    Follows the lab naming standard (first initial + surname, lower case).
    The temporary password is typed at a secure prompt and never stored.
    The user must change it at first sign-in. Stops if the username is taken.
.EXAMPLE
    & C:\LabScripts\new-starter.ps1 -First Kemi -Last Adeyemi -Department Sales -Title "Sales Executive" -Manager hwright -Ticket REQ-003
.EXAMPLE
    Add -WhatIf to see what would happen without changing anything.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$First,
    [Parameter(Mandatory)][string]$Last,
    [Parameter(Mandatory)][ValidateSet("IT", "Sales")][string]$Department,
    [Parameter(Mandatory)][string]$Title,
    [string]$Manager,
    [Parameter(Mandatory)][string]$Ticket
)

$domain   = "lab.local"
$groupFor = @{ IT = "IT-Support"; Sales = "Sales-Team" }
$group    = $groupFor[$Department]
$sam      = ($First.Substring(0, 1) + $Last).ToLower()

# Checks before changing anything
if (Get-ADUser -Filter "SamAccountName -eq '$sam'") {
    Write-Host "Username '$sam' is already taken. Agree an alternative (e.g. add a middle initial) and re-run." -ForegroundColor Red
    return
}
if ($Manager -and -not (Get-ADUser -Filter "SamAccountName -eq '$Manager'")) {
    Write-Host "Manager '$Manager' not found in AD. Check the username." -ForegroundColor Red
    return
}

if ($PSCmdlet.ShouldProcess("$sam in OU=$Department", "Create user and add to $group")) {
    $pw = Read-Host -AsSecureString "Temporary password for $sam"

    $params = @{
        Name                  = "$First $Last"
        GivenName             = $First
        Surname               = $Last
        DisplayName           = "$First $Last"
        SamAccountName        = $sam
        UserPrincipalName     = "$sam@$domain"
        Title                 = $Title
        Department            = $Department
        Description           = "New starter - $Ticket - $(Get-Date -Format yyyy-MM-dd)"
        Path                  = "OU=$Department,DC=lab,DC=local"
        AccountPassword       = $pw
        Enabled               = $true
        ChangePasswordAtLogon = $true
    }
    if ($Manager) { $params.Manager = $Manager }

    New-ADUser @params
    Add-ADGroupMember -Identity $group -Members $sam
    Write-Host "Created '$sam' in OU $Department and added to $group" -ForegroundColor Green

    # Show the result for the ticket write-up
    Get-ADUser $sam -Properties Title, Department, Manager, MemberOf |
        Select-Object Name, SamAccountName, UserPrincipalName, Title, Department,
            @{ n = "Manager"; e = { ($_.Manager -split ",")[0] -replace "CN=" } },
            @{ n = "Groups";  e = { ($_.MemberOf | ForEach-Object { ($_ -split ",")[0] -replace "CN=" }) -join ", " } }
}
