<#
.SYNOPSIS
    Creates the organisational units (OUs) for the lab.local domain.
.DESCRIPTION
    OUs are folders in Active Directory used to organise users and computers
    and to apply Group Policy. IT is created by hand in ADUC; this script adds
    the rest. Safe to run more than once - existing OUs are skipped.
#>

$domainDN = "DC=lab,DC=local"
$ous = "IT", "Sales", "Disabled Users"

foreach ($ou in $ous) {
    if (Get-ADOrganizationalUnit -Filter "Name -eq '$ou'" -SearchBase $domainDN -SearchScope OneLevel) {
        Write-Host "OU '$ou' already exists - skipped" -ForegroundColor Yellow
    }
    else {
        New-ADOrganizationalUnit -Name $ou -Path $domainDN -ProtectedFromAccidentalDeletion $true
        Write-Host "Created OU '$ou'" -ForegroundColor Green
    }
}
