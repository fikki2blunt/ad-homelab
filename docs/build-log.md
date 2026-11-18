# Build log – Active Directory home lab

A Windows Server 2022 domain (lab.local) with a domain-joined Windows 11 client, built in VirtualBox to practise 1st/2nd line IT support.

| Item | Detail |
| --- | --- |
| Host | Intel i7-8650U (4 cores / 8 threads), 8 GB RAM |
| VM storage | 500 GB external USB 3 SSD (G:) |
| Hypervisor | VirtualBox 7.2.22 + Extension Pack |
| Started | November 2026 |

**Lab network**

| Machine | OS | Role | IP | DNS server |
| --- | --- | --- | --- | --- |
| DC01 | Windows Server 2022 Standard (Desktop Experience) | Domain controller + DNS for lab.local | 10.0.0.1/24 | 10.0.0.1 |
| CLIENT01 | Windows 11 Enterprise | Domain-joined client | 10.0.0.10/24 | 10.0.0.1 |

---

## Phase 0 – Preparation

**Goal:** get the storage and documentation ready before building anything.

| Step | What I did | Why |
| --- | --- | --- |
| 1 | Checked the external drive is NTFS (drive letter G:) | FAT32 can't store files over 4 GB, and VM disks and ISOs are bigger than that |
| 2 | Created `G:\HomeLab\ISOs` and `G:\HomeLab\VMs` | Keeps installers and VMs organised and off the internal disk (only ~37 GB free) |
| 3 | Turned off USB selective suspend (Power Options → USB settings) | Stops Windows putting the drive to sleep while VMs are running from it |
| 4 | Created the `ad-homelab` repo with `docs`, `screenshots`, `scripts`, `tickets` | Documents the work as it happens and gives recruiters proof on GitHub |

```powershell
git init
git add .
git commit -m "Phase 0: lab preparation and build log"
git branch -M main
git remote add origin https://github.com/fikki2blunt/ad-homelab.git
git push -u origin main
```

**Problems:** none.

---

## Phase 1 – Hypervisor

**Goal:** install the virtualisation software and download the operating systems.

| Step | What I did | Why |
| --- | --- | --- |
| 1 | Confirmed virtualisation is enabled (Task Manager → Performance → CPU) | VirtualBox needs Intel VT-x to run 64-bit VMs |
| 2 | Installed VirtualBox 7.2.22 + the Extension Pack | The hypervisor that runs the VMs; the Extension Pack adds USB 3 and other features |
| 3 | Set File → Preferences → General → Default Machine Folder to `G:\HomeLab\VMs` | Every new VM is created on the external SSD automatically |
| 4 | Downloaded the Windows Server 2022 and Windows 11 Enterprise evaluation ISOs to `G:\HomeLab\ISOs` | Free 180-day (Server) and 90-day (Windows 11) trials. I chose regular Enterprise, not LTSC, because it's what office PCs actually run |

**Problems:** none.

**What I learned:** LTSC (Long-Term Servicing Channel) gets security updates for years but no new features. It's meant for kiosks and tills, not office PCs.

---

## Phase 2 – Domain controller (DC01)

**Goal:** build a server and turn it into the domain controller for a new domain, lab.local.

### Step 1 – Create the VM

| Setting | Value | Why |
| --- | --- | --- |
| Name / folder | DC01, `G:\HomeLab\VMs` | Stored on the external SSD |
| CPU / RAM | 1 vCPU, 2048 MB | Enough for a lab DC, and leaves RAM for the host and the client (see Phase 3, Problem 6) |
| Disk | 50 GB, dynamically allocated | Only uses the space actually written (~20 GB) |
| Adapter 1 | NAT | Internet access for the server (updates) |
| Adapter 2 | Internal Network "lab" | Private network shared with CLIENT01, isolated from my home network |

### Step 2 – Install Windows Server 2022

- Chose **Windows Server 2022 Standard Evaluation (Desktop Experience)**.
- **Why Desktop Experience:** it includes the graphical tools used daily in support (Active Directory Users and Computers, DNS Manager, Group Policy Management). Server Core has no desktop and is managed with PowerShell or remotely. That's lighter and more secure, but too much while learning.
- Sent Ctrl+Alt+Del to the VM with **Input → Keyboard → Insert Ctrl-Alt-Del**, because the host keeps that key combination for itself.

### Step 3 – Install Guest Additions

- Mounted `C:\Program Files\Oracle\VirtualBox\VBoxGuestAdditions.iso` and ran **VBoxWindowsAdditions-amd64.exe** (amd64 = 64-bit Windows on Intel/AMD), then rebooted.
- **Why:** Guest Additions are drivers and services for the virtual hardware: proper screen resolution, smooth mouse, shared clipboard and time sync. Time sync matters because AD sign-ins fail if clocks differ by more than 5 minutes.
- **Real-world equivalent:** a freshly imaged laptop with missing drivers. Check Device Manager for warning icons, then Windows Update (optional updates) or the manufacturer's tool (Dell Command Update, Lenovo System Update, HP Support Assistant).

### Step 4 – Identify the network adapters

```powershell
Get-NetIPAddress -AddressFamily IPv4 | Select InterfaceAlias, IPAddress
```

- **Why:** two adapters exist, and the wrong one must not be changed. The adapter with 169.254.x.x (no DHCP) is the internal one. 10.0.2.x is VirtualBox NAT.
- **Result:** `Ethernet` = internal (169.254.11.87), `Ethernet 2` = NAT (10.0.2.15). This is the opposite of what the guide expected.

### Step 5 – Static IP and rename

```powershell
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 10.0.0.1 -PrefixLength 24
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 127.0.0.1
Rename-Computer -NewName DC01 -Restart
```

| Command | What it does | Why |
| --- | --- | --- |
| `New-NetIPAddress` | Sets IP 10.0.0.1, subnet mask 255.255.255.0 (/24) | A DC's address must never change, because every client finds it by this IP |
| `Set-DnsClientServerAddress` | Points DNS at itself | The DC will run the DNS server for the domain |
| `Rename-Computer` | Names the server DC01 | Renaming a DC after promotion is awkward, so it's done first |

- **No default gateway** on the internal adapter. DC01 reaches the internet through the NAT adapter, and a machine should have only one default gateway. A device is only a gateway if clients are configured to send traffic to it and it routes that traffic. ".1 is the gateway" is a convention, not a rule.

### Step 6 – Install the AD DS role

```powershell
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
```

- **What it does:** installs the Active Directory software and admin tools only. **No domain exists yet.**

### Step 7 – Promote DC01 to a domain controller

```powershell
Install-ADDSForest -DomainName "lab.local" -DomainNetbiosName "LAB" -InstallDns
```

- **What it does:** creates a new forest and the domain lab.local, makes DC01 its first domain controller, and installs DNS.
- **Forest** = the top-level AD structure. Creating the first domain also creates the forest. **LAB** = the short NetBIOS name used in sign-ins like `LAB\Administrator`.
- Set a **DSRM (Directory Services Restore Mode) password**, a separate emergency password for repairing AD offline. It's stored in a password manager, not in this log.
- Expected yellow warnings appeared (NT 4.0 cryptography default, DNS delegation, NAT adapter without a static IP). Only red text is a real error.
- After the restart, the local Administrator became the domain administrator, `LAB\Administrator`.

**Key lesson:** a fresh server is not a domain controller. AD is two steps: **install the role**, then **promote the server**. The GUI equivalents are Server Manager → Add Roles and Features, then the yellow flag → "Promote this server to a domain controller".

### Step 8 – Fix DNS (see Problem 6) and verify the domain

```powershell
whoami                                                    # lab\administrator
Get-ADDomain | Select DNSRoot, NetBIOSName, PDCEmulator   # lab.local, LAB, DC01.lab.local
Get-Service NTDS, DNS, Netlogon, Kdc, DFSR                # all Running
net share                                                 # NETLOGON and SYSVOL present
Get-DnsServerZone                                         # lab.local + _msdcs.lab.local
Resolve-DnsName dc01.lab.local -Server 10.0.0.1 -DnsOnly  # 10.0.0.1 only
nslookup -type=SRV _ldap._tcp.dc._msdcs.lab.local         # dc01.lab.local
dcdiag /test:dns                                          # passed
```

| Check | Why it matters |
| --- | --- |
| NTDS / Kdc / Netlogon / DNS / DFSR services | AD database, Kerberos authentication, sign-ins and DC records, name lookups, policy folder sync |
| SYSVOL / NETLOGON shares | Where Group Policy and logon scripts live |
| SRV record in _msdcs | How clients find a domain controller |
| dcdiag | Microsoft's built-in DC health test |

### Step 9 – Snapshot

Shut down DC01 and took the snapshot **"DC01 – fresh domain"**, a restore point saved to the external drive.

### Phase 2 problems

**Problem 1 – Setup failed: "Windows cannot find the Microsoft Software License Terms"**
- **Symptom:** Setup stopped at "Setup is starting" with this error.
- **Diagnosis:** VM Settings → Storage showed VirtualBox's auto-generated "Unattended" ISO in the optical drive, not the Server 2022 ISO. The VM had been created without ticking "Skip Unattended Installation".
- **Fix:** swapped the optical drive to the Server 2022 ISO (Storage → optical drive → Choose a disk file). Setup then ran normally.
- **Lesson:** when an install fails, check what media the machine is actually booting from before blaming the ISO or the hardware.

**Problem 2 – Keyboard error: VERR_PDM_NO_QUEUE_ITEMS ("could not send all scan codes")**
- **Cause:** keystrokes were sent faster than the VM could process them, which happens when pasting through VirtualBox's keyboard or pressing keys while the VM is busy.
- **Fix:** restarted the VM. From then on I pasted with Shared Clipboard (Devices → Shared Clipboard → Bidirectional, then right-click to paste).

**Problem 3 – PowerShell "term 'Get' is not recognized"**
- **Cause:** typed `Get -NetIPAddress` with a space.
- **Fix:** `Get-NetIPAddress`. PowerShell commands are Verb-Noun joined by a hyphen, and only parameters have a space before the hyphen.

**Problem 4 – Adapter names didn't match the guide**
- **Fix:** identified the adapters by their current IP with `Get-NetIPAddress` and configured "Ethernet" instead of "Ethernet 2".
- **Lesson:** identify adapters by IP, not by name, before changing settings.

**Problem 5 – Promotion failed the prerequisite check**
- **Error:** "The Directory Services Restore Mode password does not meet the password complexity requirements."
- **Cause:** the DSRM password was too simple. Windows checks prerequisites before changing anything, so nothing had been modified.
- **Fix:** re-ran `Install-ADDSForest` with a password of 8+ characters using at least 3 of: upper case, lower case, numbers, symbols.
- **Lesson:** the red error line says exactly what's wrong. The same complexity rules apply to user passwords, a common helpdesk question.

**Problem 6 – DNS zones missing, so the DC advertised the wrong IP**
- **Symptoms:** promotion warned "An error occurred while the wizard was installing DNS". Afterwards `Get-ADDomainController` showed 10.0.2.15 (NAT) instead of 10.0.0.1, and `Get-DnsServerResourceRecord` reported "zone lab.local was not found".
- **Root cause:** the DNS server was installed, but the lab.local and _msdcs.lab.local zones were never created. With no zone, DC01 resolved its own name through the NAT adapter.
- **Fix:**

```powershell
# Create AD-integrated zones with secure dynamic updates
Add-DnsServerPrimaryZone -Name "lab.local" -ReplicationScope "Domain" -DynamicUpdate Secure
Add-DnsServerPrimaryZone -Name "_msdcs.lab.local" -ReplicationScope "Forest" -DynamicUpdate Secure

# Stop the NAT adapter registering its IP in DNS
Set-DnsClient -InterfaceAlias "Ethernet 2" -RegisterThisConnectionsAddress $false

# Point both adapters' DNS at the DC's own internal IP
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 10.0.0.1,127.0.0.1
Set-DnsClientServerAddress -InterfaceAlias "Ethernet 2" -ServerAddresses 10.0.0.1

# Forward non-lab names (e.g. microsoft.com) to VirtualBox's DNS
Add-DnsServerForwarder -IPAddress 10.0.2.3

# Re-register the DC's A and SRV records
ipconfig /flushdns
ipconfig /registerdns
Restart-Service Netlogon
```

  Also set DNS Manager → DC01 → Properties → Interfaces → listen only on 10.0.0.1.
- **Verified:** querying the DNS server directly returns only 10.0.0.1. The zone holds @, dc01, DomainDnsZones and ForestDnsZones, all pointing to 10.0.0.1. The SRV record resolves to dc01.lab.local, and `dcdiag /test:dns` passed.
- **Note:** `Resolve-DnsName` run *on DC01 itself* still lists 10.0.2.15 and IPv6 addresses (Section "Question"), because Windows adds its own local IPs when resolving its own name. Clients only see what the DNS server returns.
- **Lesson:** AD depends on DNS. Clients find DCs through SRV records in _msdcs. A DC with two adapters ("multi-homed") causes DNS problems, which is why production DCs normally have one. Verify DNS straight after promoting, not when the first client fails to join.

**Other notes**
- Promotion was slow at "Waiting for DNS installation to finish" because the VM runs from a USB drive. Clicking inside a PowerShell window can pause output ("Select" in the title bar), and Esc resumes it.
- Server Manager opens at every sign-in by default. It can be turned off in Manage → Server Manager Properties.

---

## Phase 3 – Windows 11 client (CLIENT01)

**Goal:** add a workstation to the domain, as a new company laptop would be.

### Step 1 – Create the VM

| Setting | Value | Why |
| --- | --- | --- |
| Name / folder | CLIENT01, `G:\HomeLab\VMs` | Stored on the external SSD |
| Unattended install | **Skipped** (on the rebuild) | Full control over the account and settings |
| CPU / RAM | 2 vCPU, 2560 MB | Windows 11 needs 4 GB to install but runs with less, leaving RAM for the host |
| Disk | 64 GB, dynamically allocated | Windows 11's minimum disk size |
| System | EFI, Secure Boot, TPM 2.0 | Windows 11 hardware requirements |
| Display | VBoxSVGA, 128 MB, 3D acceleration off | Recommended for Windows guests; 3D can cause black screens |
| Adapter 1 | Internal Network "lab" only | CLIENT01 only needs to reach DC01; no internet, isolated lab |

### Step 2 – Install Windows 11 Enterprise

- At "Press any key to boot from CD or DVD", pressed a key within 5 seconds to start the installer. After the first restart I didn't press a key, so it booted from the hard disk.
- With no internet: **Sign-in options → Domain join instead** creates a local account. It does **not** join the domain; that's done later.

### Step 3 – Install Guest Additions

- Ran **VBoxWindowsAdditions-amd64.exe** and rebooted, then turned on Shared Clipboard (Bidirectional).
- **Why:** without the display driver, Windows was stuck at 1024x768 (Problem 5).
- Took the snapshot **"CLIENT01 – fresh install"**.

### Step 4 – Network settings

```powershell
Get-NetIPAddress -AddressFamily IPv4 | Select InterfaceAlias, IPAddress
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 10.0.0.10 -PrefixLength 24
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 10.0.0.1
```

| Setting | Why |
| --- | --- |
| IP 10.0.0.10/24 | Same subnet as DC01 so they can talk |
| DNS 10.0.0.1 | **The most important setting.** The client finds the domain by asking DC01's DNS for the SRV records |
| No gateway | Nothing outside 10.0.0.0/24 is needed |

### Step 5 – Rename

```powershell
Rename-Computer -NewName CLIENT01 -Restart
```

Replaces the random DESKTOP-XXXX name with one that follows a naming standard.

### Step 6 – Test before joining

```powershell
nslookup lab.local                       # answered 10.0.0.1
Test-NetConnection 10.0.0.1 -Port 389    # TcpTestSucceeded : True
```

- **Why:** confirms DNS works and LDAP (port 389, used to talk to AD) is reachable before attempting the join.
- Plain `ping` can fail because the server firewall blocks it by default. That's normal.

### Step 7 – Join the domain (elevated terminal)

```powershell
$pw   = Read-Host -AsSecureString "Password"
$cred = New-Object System.Management.Automation.PSCredential("LAB\Administrator", $pw)
Add-Computer -DomainName lab.local -Credential $cred -Restart
```

| Line | What it does |
| --- | --- |
| `Read-Host -AsSecureString` | Prompts for the password and stores it encrypted in memory, not in plain text |
| `PSCredential` | Combines the username and password into one credential object |
| `Add-Computer` | Creates the computer account in AD and joins CLIENT01 to lab.local |

- **Why a domain admin account:** a normal user can't join computers without delegated rights.
- **GUI equivalent:** `sysdm.cpl` → Computer Name → Change → Domain: lab.local.

### Step 8 – Verify

- Signed in on CLIENT01 as **Other user → LAB\Administrator**. `whoami` returned `lab\administrator`.
- Settings → System → About shows **CLIENT01.lab.local**.
- On DC01: Active Directory Users and Computers → lab.local → **Computers** lists CLIENT01.
- Cleared the PowerShell history, because a password had been typed in plain text:

```powershell
Clear-History
Remove-Item (Get-PSReadLineOption).HistorySavePath -ErrorAction SilentlyContinue
```

### Step 9 – Snapshots

Shut down both VMs and took a **"Client joined"** snapshot of each.

### How I run the lab on 8 GB RAM

| Task | VMs running |
| --- | --- |
| Configuring CLIENT01 (IP, rename) | CLIENT01 only |
| Domain join and sign-in tests | Both. Start DC01 first and wait 2 minutes |
| AD admin work (users, groups, scripts) | DC01 only |

The VM not in use is paused with **Close → Save the machine state**, which frees its RAM.

### Phase 3 problems

**Problem 1 – First build ran an unattended install**
- **Cause:** "Skip Unattended Installation" wasn't ticked, so VirtualBox created the account (vboxuser) and settings automatically.
- **Lesson:** unattended installs save time but take away control. Companies use the same idea on purpose (answer files, Autopilot) to build many PCs identically.

**Problem 2 – Black screen on the first CLIENT01**
- **Tried:** waking the screen, toggling full screen, and Graphics Controller VBoxSVGA / 128 MB / 3D off. The VM log showed the firmware stopping early.
- **Fix:** deleted the VM and rebuilt it with Skip Unattended ticked and the display settings set before the first boot.
- **Lesson:** "reimage vs repair". When a machine has nothing of value on it, rebuilding is often faster than troubleshooting.

**Problem 3 – "Saved screenshot thumbnail data is not available (VERR_NOT_SUPPORTED)"**
- A harmless VirtualBox Manager preview error after recreating a VM with the same name. Cleared with OK.

**Problem 4 – "No bootable option or device was found"**
- **Cause:** missed the 5-second "Press any key to boot from CD or DVD" prompt, so the VM tried the empty hard disk.
- **Fix:** mounted the Windows 11 ISO from the dialog and pressed a key at the prompt.
- **Lesson:** new machines boot from installation media only if you choose it at startup or set it first in the boot order. The same applies when reimaging physical PCs from USB.

**Problem 5 – Stuck at 1024x768 resolution**
- **Cause:** Guest Additions wasn't installed, so Windows used a basic display driver.
- **Fix:** installed Guest Additions (amd64) and rebooted; auto-resize then worked.
- **Lesson:** low resolution and few options mean a missing display driver. On physical PCs, check Device Manager.

**Problem 6 – Laptop froze with both VMs running**
- **Diagnosis:** 8 GB host RAM. The VMs were using more memory than the laptop could spare (the external SSD wasn't the bottleneck).
- **Fix:** DC01 2 GB / 1 vCPU, CLIENT01 2.5 GB / 2 vCPU (≈3.4 GB left for the host), closed host apps, charger plugged in and Best performance, and saved the state of whichever VM wasn't needed.
- **Lesson:** capacity planning. Total VM memory must leave enough for the host, the same principle as sizing VMs on a production Hyper-V or VMware host.

**Problem 7 – Credential pop-up wouldn't stay on screen**
- **Fix:** built the credential in the console with `Read-Host -AsSecureString` and `PSCredential` (Step 7) instead of the pop-up.

**Problem 8 – `$pw` was empty ("value of argument 'password' is null")**
- **Cause:** a garbled paste meant the `Read-Host` line never ran. I had also put the password in the prompt text instead of typing it at the prompt.
- **Fix:** typed the line by hand, entered the password at the `Password:` prompt, and checked with `$pw` (it shows `System.Security.SecureString`).
- **Lesson:** never put passwords in commands, tickets or chats, because they end up in history and logs.

**Problem 9 – Domain join failed: "Access is denied"**
- **What it told me:** CLIENT01 had reached the DC, so DNS and the network were fine and this was a permissions problem.
- **Cause:** the terminal wasn't running as Administrator. Joining a domain changes system settings and needs elevation (UAC).
- **Fix:** reopened **Terminal (Admin)** and re-ran the three commands. The join succeeded.
- **Lesson:** read where an error happens. "Access denied" after contacting the DC means permissions, not connectivity.

## Phase 4 – OUs, users and groups

**Goal:** organise lab.local like a small company: departments as OUs, staff as user accounts, and security groups for access. Built partly by hand (to learn the screens) and partly with PowerShell scripts (to learn automation).

Ran on **DC01 only**, apart from the final sign-in test.

### Step 1 – Create the first OU and user by hand (ADUC)

| Action | Where | Why |
| --- | --- | --- |
| Created OU **IT** | ADUC → right-click lab.local → New → Organizational Unit | An OU is a folder in AD for organising accounts. Unlike the built-in Users/Computers containers, an OU can have Group Policy linked to it and its management delegated |
| Left "Protect container from accidental deletion" ticked | New OU dialog | Stops the OU (and everything in it) being deleted by a misclick |
| Created user **Ada Okafor** (`aokafor`) in IT | Right-click IT → New → User | Learned the user wizard, which is used daily in support for one-off new starters |
| Ticked "User must change password at next logon" | Password page of the wizard | The admin sets a temporary password; only the user should know their real one |
| Set Job Title "IT Support Analyst", Department "IT" | User Properties → Organization tab | Matches the scripted users; real companies fill these in for address books and reporting |

### Step 2 – Script 1: `scripts/create-ous.ps1`

```powershell
& C:\LabScripts\create-ous.ps1
```

- **What it does:** creates the OUs **Sales** and **Disabled Users** (IT already existed, so it was skipped), protected from accidental deletion.
- **Why Disabled Users:** leavers' accounts are disabled and moved here rather than deleted straight away, so access can be restored or audited if needed (practised in Phase 5).
- **Key cmdlets:** `Get-ADOrganizationalUnit` (checks whether it already exists) and `New-ADOrganizationalUnit`.

### Step 3 – Script 2: `scripts/create-users.ps1`

```powershell
& C:\LabScripts\create-users.ps1
```

- **What it does:** creates 9 users (2 in IT, 7 in Sales) with first name, surname, display name, job title, department, username and UPN.
- **Naming standard:** username = first initial + surname, lower case (Sam Carter → `scarter`). UPN = `scarter@lab.local`.
- **Password handling:** the starting password is typed at a secure prompt (`Read-Host -AsSecureString`) and is never stored in the script. Every account must change it at first sign-in, the same as a real new starter.
- **Safe to re-run:** it checks `Get-ADUser` first and skips anyone who already exists.
- **Key cmdlet:** `New-ADUser` with a hashtable of parameters (splatting, `@params`), which keeps long commands readable.

**Users created (10 in total)**

| Name | Username | OU | Title |
| --- | --- | --- | --- |
| Ada Okafor (by hand) | aokafor | IT | IT Support Analyst |
| Tunde Bello | tbello | IT | IT Support Analyst |
| Grace Mensah | gmensah | IT | IT Support Analyst |
| Sam Carter | scarter | Sales | Sales Executive |
| Priya Shah | pshah | Sales | Sales Executive |
| Leo Martins | lmartins | Sales | Sales Executive |
| Chloe Evans | cevans | Sales | Sales Executive |
| Musa Ibrahim | mibrahim | Sales | Sales Executive |
| Hannah Wright | hwright | Sales | Sales Manager |
| Daniel Osei | dosei | Sales | Sales Executive |

### Step 4 – Script 3: `scripts/create-groups.ps1`

```powershell
& C:\LabScripts\create-groups.ps1
```

| Group | Scope / type | Members | Purpose |
| --- | --- | --- | --- |
| IT-Support | Global, Security | Everyone in the IT OU | Access to IT tools and shares |
| Sales-Team | Global, Security | Everyone in the Sales OU | Access to Sales shares and printers |
| All-Staff | Global, Security | The IT-Support and Sales-Team **groups** | Company-wide resources |

- **Why groups:** permissions are given to a group once, then people are added or removed. You never set permissions person by person.
- **Why Global Security:** *Security* groups can grant access (distribution groups are email only). *Global* is the standard scope for grouping people from one domain by department.
- **Nesting:** All-Staff contains the two department groups, so anything shared with All-Staff automatically includes every member of both.
- **Key cmdlets:** `New-ADGroup`, `Add-ADGroupMember`.

### Step 5 – Verify

```powershell
Get-ADOrganizationalUnit -Filter * | Select Name
Get-ADUser -Filter * -SearchBase "DC=lab,DC=local" -Properties Title, Department |
  Where-Object { $_.DistinguishedName -like "*OU=*" } |
  Select Name, SamAccountName, Title, Department
Get-ADGroupMember "Sales-Team" | Select Name
Get-ADGroupMember "All-Staff" | Select Name
```

- OUs: Domain Controllers, IT, Sales, Disabled Users
- 10 users listed with the correct OU, title and department
- Sales-Team: 7 users. All-Staff: IT-Support and Sales-Team

### Step 6 – Snapshot

Shut down DC01 and took the snapshot **"Users and groups created"** (VirtualBox → DC01 → Snapshots tab → Take). It's a restore point before Phase 5 and the Group Policy work.

### Step 7 – Test a real domain sign-in on CLIENT01

- Started DC01, waited 2 minutes, then started CLIENT01.
- Sign-in screen → **Other user** → `LAB\scarter` with the starting password.
- Windows forced a password change ("The user's password must be changed before signing in"), which proved the "change at next logon" setting works.
- `whoami` → `lab\scarter`.
- **Result:** passed. scarter signed in, changed the temporary password, and reached the desktop as a domain user.

### Problems

None. All three scripts ran first time, and the domain sign-in test passed.

### Notes

- **VirtualBox UI:** this version has no three-line menu next to the VM. Snapshots are in the **Snapshots** tab of the right-hand panel.
- **Resources:** set DC01 back to 2048 MB / 1 vCPU (it had drifted to 2417 MB / 2 vCPU) to keep enough RAM for the host and CLIENT01.

### What I learned

- **OU vs group:** an OU decides *where* an account lives and which Group Policy applies to it. A group decides *what it can access*.
- **Containers aren't OUs:** the built-in Users and Computers containers can't have Group Policy linked, which is why departments get their own OUs.
- **`LAB\scarter`:** `LAB` is the domain's short (NetBIOS) name, set with `-DomainNetbiosName "LAB"` when the domain was created. `LAB\scarter` means "the user scarter in the LAB domain". `scarter@lab.local` (the UPN) means the same thing.
- **Local vs domain accounts:** the account created during Windows setup is a **local** account stored only on CLIENT01 (`CLIENT01\client01`). Domain accounts are stored in AD on DC01 and work on any domain-joined PC. The prefix tells Windows which one to check.
- **"Other user":** the sign-in screen only lists accounts that have signed in on that PC before, so a first-time domain user has to type their name.
- **No AD account, no domain sign-in:** that's why creating the account is step one of every new-starter process.
- **Scripts beat clicking for repeat work:** the same 9 users would take ~20 minutes by hand, and the scripts can be re-run safely and are documented on GitHub.

---

## Phase 5 – Helpdesk tickets

**Goal:** handle the four most common 1st line requests the way a real service desk does, with each one written up as a ticket in `tickets/`.

Done mainly through the **GUI** (ADUC, Group Policy Management) to learn the screens used daily on a service desk. PowerShell was used to investigate the lockout and for the unlock. Scripts for the new starter and leaver are in `scripts/` as the automated alternative.

| Ticket | Type | What happened | Fixed with |
| --- | --- | --- | --- |
| [INC-001](../tickets/INC-001-password-reset.md) | Incident | Chloe Evans forgot her password | ADUC → Reset Password, change at next logon |
| [INC-002](../tickets/INC-002-account-lockout.md) | Incident | Chloe locked herself out mistyping the new password | Found the source (event 4740), then `Unlock-ADAccount` |
| [REQ-003](../tickets/REQ-003-new-starter.md) | Request | New starter Kemi Adeyemi, Sales Executive | ADUC → Copy existing Sales user, set manager, checked groups |
| [REQ-004](../tickets/REQ-004-leaver.md) | Request | Leaver Daniel Osei | Recorded groups, removed them, scrambled password, disabled, moved to Disabled Users |

**Ticket layout:** every ticket records the caller, priority, times, identity or approval check, investigation, resolution, verification, a note to the user and lessons, the same fields as ServiceNow or Jira Service Management. `tickets/TEMPLATE.md` is a blank copy.

### Step 1 – Fix the time zone on both VMs

```powershell
Set-TimeZone -Id "GMT Standard Time"
```

- **Why:** both VMs were still on the installer default (US Pacific), 8 hours behind UK time. Event logs and ticket times have to match, or investigations get confusing.

### Step 2 – INC-001 Password reset (Chloe Evans)

- **Identity check first:** a password reset is a security action. Confirmed the caller (lab simulation: call-back to the number on file, manager confirmation) and never asked for the old password.
- **Investigated** with `Get-ADUser cevans -Properties Enabled, LockedOut, PasswordExpired ...`: Enabled True, not locked, PasswordExpired True (see What I learned).
- **Reset** in ADUC → Sales → right-click Chloe Evans → **Reset Password** → temporary password → **User must change password at next logon**. Left "Unlock" unticked because she wasn't locked.
- **Verified** on CLIENT01: Windows forced a password change, and `whoami` → `lab\cevans`.

### Step 3 – Account lockout policy (GUI)

A new domain never locks accounts (`LockoutThreshold 0`). Set a policy like a real company would:

**Group Policy Management → lab.local → Default Domain Policy → Edit → Computer Configuration → Policies → Windows Settings → Security Settings → Account Policies → Account Lockout Policy**

| Setting | Value |
| --- | --- |
| Account lockout threshold | 5 invalid logon attempts |
| Account lockout duration | 15 minutes |
| Reset account lockout counter after | 15 minutes |

Checked with `Get-ADDefaultDomainPasswordPolicy`: LockoutThreshold 5, LockoutDuration and LockoutObservationWindow 00:15:00. Ran `gpupdate /force` on CLIENT01.

### Step 4 – INC-002 Account lockout (Chloe Evans)

- Caused the lockout by typing a wrong password for `LAB\cevans` 5 times on CLIENT01: *"The referenced account is currently locked out and may not be logged on to."*
- **Investigated on DC01:**

```powershell
Search-ADAccount -LockedOut | Select Name, SamAccountName            # only cevans
Get-ADUser cevans -Properties LockedOut, BadLogonCount, LastBadPasswordAttempt |
  Select Name, LockedOut, BadLogonCount, LastBadPasswordAttempt       # True, 5, 02:04:07
Get-WinEvent -FilterHashtable @{ LogName = 'Security'; Id = 4740 } -MaxEvents 5 |
  Select TimeCreated, @{ n = 'User'; e = { $_.Properties[0].Value } }, @{ n = 'Source PC'; e = { $_.Properties[1].Value } }
                                                                      # 02:04:07, cevans, CLIENT01
```

- **Event 4740** = "a user account was locked out", logged on the DC. It names the **source computer**, so you can tell whether the user is mistyping or something else (a phone, a saved password, a service) is using an old password.
- **Unlocked** with `Unlock-ADAccount -Identity cevans` and checked `LockedOut : False`. No password reset, because she still knew her password.

### Step 5 – REQ-003 New starter (Kemi Adeyemi)

- ADUC → Sales → right-click **Sam Carter** → **Copy…** → Kemi Adeyemi, `kadeyemi`, temporary password, change at next logon.
- Set **Manager = Hannah Wright** (Organization tab), added the ticket number to Description, and checked **Member Of** = Sales-Team.
- **Why check after copying:** Copy gives the new user every group the template user has, including any extra access.

### Step 6 – REQ-004 Leaver (Daniel Osei)

- Screenshotted **Member Of** first (Domain Users, Sales-Team) as the record of his access.
- Removed **Sales-Team**, set Description `Leaver - disabled 2026-11-18 (REQ-004)`, reset the password to a random value, **Disable Account**, then **Move…** to **Disabled Users**.
- **Disable, don't delete:** deleting loses the account's SID, files and audit history. The account is kept disabled for a retention period, then deleted.

### Step 7 – Automation (written, not run)

| Script | Does |
| --- | --- |
| `scripts/new-starter.ps1` | Creates a user to the naming standard, sets title, department, manager and ticket number, adds the department group. Stops if the username is taken |
| `scripts/leaver.ps1` | Saves the user's groups to a file, disables, scrambles the password with a cryptographically random value, removes groups, sets the description, moves to Disabled Users |

Both support `-WhatIf` (dry run). Not run in this phase because the GUI was used to learn the process, so they're untested so far.

### Phase 5 problems

**Problem 1 – ADUC wouldn't open straight after booting DC01**
- **Cause:** the AD services were still starting, which is slower because the VM runs from the external USB drive.
- **Fix:** waited 2–3 minutes and it opened.
- **Lesson:** after a DC reboot, give AD time to start before assuming it's broken.

**Problem 2 – First temporary password rejected**
- **Cause:** a 4-character password. The Default Domain Policy needs at least 7 characters plus complexity, and that applies to passwords set by admins too.
- **Fix:** used a longer password that met the rules.
- **Lesson:** `Get-ADDefaultDomainPasswordPolicy` shows the rules. Users hitting this on their forced change is a common helpdesk call.

**Problem 3 – VMs on the wrong time zone**
- **Symptom:** DC01 showed 17/11 5:01 PM when UK time was about 01:00 on 18/11.
- **Fix:** `Set-TimeZone -Id "GMT Standard Time"` on both VMs. Event 4740 then matched the ticket times exactly.
- **Lesson:** Kerberos uses UTC, so sign-ins still worked, but wrong local time makes logs misleading during an investigation.

### What I learned

- **Lockout ≠ forgotten password:** unlock only when the user still knows the password. A reset makes them choose a new one for no reason.
- **PasswordExpired = True** on a user who must change their password at next logon: AD clears the password's last-set date, so it reports it as expired. It doesn't mean the password reached its maximum age.
- **Where lockout lives:** domain password and lockout rules are set in the Default Domain Policy. A policy linked to an OU won't change them for domain accounts.
- **Always find the source of a lockout** (event 4740 → Caller Computer Name). Many accounts locking at once from one place can mean a password-guessing attack, so escalate to security.
- **Identity and approval come first:** resets and unlocks need the caller verified; new starters and leavers need an approved request from the manager or HR.
- **GUI vs PowerShell:** the GUI is quicker for one-off tickets and shows where settings live. Scripts are better for repeat or bulk work and leave a record.

---

## Screenshots

| File | Shows |
| --- | --- |
| [virtual machine setup.png](../screenshots/virtual%20machine%20setup.png) | VirtualBox VM setup |
| [vm1 windows server 2022 summary.png](../screenshots/vm1%20windows%20server%202022%20summary.png) | DC01 VM summary |
| [vm 1 full details.png](../screenshots/vm%201%20full%20details.png) | DC01 hardware and network adapters |
| [DC-01 IP config.png](../screenshots/DC-01%20IP%20config.png) | DC01 static IP 10.0.0.1 |
| [client01 test connection with dco01.png](../screenshots/client01%20test%20connection%20with%20dco01.png) | nslookup + Test-NetConnection from CLIENT01 |
| [aduc computers.png](../screenshots/aduc%20computers.png) | CLIENT01 in the Computers container |
| [new organisational user.png](../screenshots/new%20organisational%20user.png) | New user wizard for Ada Okafor |
| [ou-structure.png](../screenshots/ou-structure.png) | ADUC with IT, Sales and Disabled Users |
| [users-in -powershell.png](../screenshots/users-in%20-powershell.png) | Get-ADUser listing all 10 users |
| [sales team members.png](../screenshots/sales%20team%20members.png) | Sales-Team members |
| [domain user login.png](../screenshots/domain%20user%20login.png) | CLIENT01 signed in as lab\scarter |
| [incident001-reset password.png](../screenshots/incident001-reset%20password.png) | INC-001 – Reset Password in ADUC |
| [incident001- forced change upon login.png](../screenshots/incident001-%20forced%20change%20upon%20login.png) | INC-001 – forced password change on CLIENT01 |
| [account lockout policy - group policy management.png](../screenshots/account%20lockout%20policy%20-%20group%20policy%20management.png) | Account Lockout Policy in the Default Domain Policy |
| [dc01 default policy.png](../screenshots/dc01%20default%20policy.png) | Password policy before (threshold 0) and after (5) |
| [incident002 locked message.png](../screenshots/incident002%20locked%20message.png) | INC-002 – "account is locked out" on CLIENT01 |
| [incident002- event 4740.png](../screenshots/incident002-%20event%204740.png) | INC-002 – event 4740 showing source CLIENT01 |
| [inciden002 unlocked.png](../screenshots/inciden002%20unlocked.png) | INC-002 – LockedOut False after unlock |
| [req004- daniel osei member of.png](../screenshots/req004-%20daniel%20osei%20member%20of.png) | REQ-004 – Daniel's groups before removal |

## Next

Phase 6: Group Policy – create and link GPOs to the IT and Sales OUs (e.g. a desktop wallpaper, mapped drive, and a USB storage restriction), then verify on CLIENT01 with `gpresult /r`.
