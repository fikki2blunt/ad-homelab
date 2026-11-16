<#
.SYNOPSIS
    Creates lab user accounts in the IT and Sales OUs.
.DESCRIPTION
    Usernames are first initial + surname (e.g. Sam Carter -> scarter).
    The starting password is typed at a secure prompt, never stored in the
    script. Users must change it at first sign-in. Existing users are skipped.
#>

$domain = "lab.local"
$pw = Read-Host -AsSecureString "Starting password for new users"

$users = @(
    @{ First = "Tunde";  Last = "Bello";   OU = "IT";    Title = "IT Support Analyst" },
    @{ First = "Grace";  Last = "Mensah";  OU = "IT";    Title = "IT Support Analyst" },
    @{ First = "Sam";    Last = "Carter";  OU = "Sales"; Title = "Sales Executive" },
    @{ First = "Priya";  Last = "Shah";    OU = "Sales"; Title = "Sales Executive" },
    @{ First = "Leo";    Last = "Martins"; OU = "Sales"; Title = "Sales Executive" },
    @{ First = "Chloe";  Last = "Evans";   OU = "Sales"; Title = "Sales Executive" },
    @{ First = "Musa";   Last = "Ibrahim"; OU = "Sales"; Title = "Sales Executive" },
    @{ First = "Hannah"; Last = "Wright";  OU = "Sales"; Title = "Sales Manager" },
    @{ First = "Daniel"; Last = "Osei";    OU = "Sales"; Title = "Sales Executive" }
)

foreach ($u in $users) {
    $sam = ($u.First.Substring(0, 1) + $u.Last).ToLower()

    if (Get-ADUser -Filter "SamAccountName -eq '$sam'") {
        Write-Host "User '$sam' already exists - skipped" -ForegroundColor Yellow
        continue
    }

    $params = @{
        Name                  = "$($u.First) $($u.Last)"
        GivenName             = $u.First
        Surname               = $u.Last
        DisplayName           = "$($u.First) $($u.Last)"
        SamAccountName        = $sam
        UserPrincipalName     = "$sam@$domain"
        Title                 = $u.Title
        Department            = $u.OU
        Path                  = "OU=$($u.OU),DC=lab,DC=local"
        AccountPassword       = $pw
        Enabled               = $true
        ChangePasswordAtLogon = $true
    }
    New-ADUser @params
    Write-Host "Created user '$sam' in OU $($u.OU)" -ForegroundColor Green
}
