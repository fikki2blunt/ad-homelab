<#
.SYNOPSIS
    Creates the lab security groups and adds members.
.DESCRIPTION
    IT-Support  = everyone in the IT OU
    Sales-Team  = everyone in the Sales OU
    All-Staff   = contains the two groups above (group nesting)
    Groups are used to give access to resources; OUs are used for
    organisation and Group Policy. Safe to run more than once.
#>

$groups = @(
    @{ Name = "IT-Support"; Path = "OU=IT,DC=lab,DC=local";    Description = "IT support staff" },
    @{ Name = "Sales-Team"; Path = "OU=Sales,DC=lab,DC=local"; Description = "Sales department" },
    @{ Name = "All-Staff";  Path = "DC=lab,DC=local";          Description = "All employees (contains department groups)" }
)

foreach ($g in $groups) {
    if (Get-ADGroup -Filter "Name -eq '$($g.Name)'") {
        Write-Host "Group '$($g.Name)' already exists - skipped" -ForegroundColor Yellow
    }
    else {
        New-ADGroup -Name $g.Name -GroupScope Global -GroupCategory Security -Path $g.Path -Description $g.Description
        Write-Host "Created group '$($g.Name)'" -ForegroundColor Green
    }
}

# Department groups get the users from their OU
Add-ADGroupMember -Identity "IT-Support" -Members (Get-ADUser -Filter * -SearchBase "OU=IT,DC=lab,DC=local")
Add-ADGroupMember -Identity "Sales-Team" -Members (Get-ADUser -Filter * -SearchBase "OU=Sales,DC=lab,DC=local")

# All-Staff contains the department groups (nesting)
Add-ADGroupMember -Identity "All-Staff" -Members "IT-Support", "Sales-Team"

Write-Host "Group membership updated" -ForegroundColor Green
