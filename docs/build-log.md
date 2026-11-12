# Build log – Active Directory home lab

A Windows Server 2022 domain (lab.local) with a domain-joined Windows 11 client, built in VirtualBox to practise 1st/2nd line IT support.

| Item | Detail |
| --- | --- |
| Host | Intel i7-8650U (4 cores / 8 threads), 8 GB RAM |
| VM storage | 500 GB external USB 3 SSD (G:) |
| Hypervisor | VirtualBox [version] + Extension Pack |
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
| 2 | Installed VirtualBox [version] + the Extension Pack | The hypervisor that runs the VMs; the Extension Pack adds USB 3 and other features |
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

---

## Screenshots

| File | Shows |
| --- | --- |
| 00-external-drive-ntfs.png | External drive formatted NTFS |
| 01-virtualbox-machine-folder.png | Default machine folder on G: |
| 02-dc01-vm-settings.png | DC01 hardware and network adapters |
| 03-dc01-ip-config.png | ipconfig /all – 10.0.0.1 |
| 04-ad-ds-installed.png | Server Manager with AD DS and DNS |
| 05-aduc-lab-local.png | Active Directory Users and Computers – lab.local |
| 05b-dcdiag-passed.png | dcdiag results |
| 06-client-dns-test.png | nslookup + Test-NetConnection from CLIENT01 |
| 07-client-joined-domain.png | CLIENT01.lab.local in Settings → About |
| 08-aduc-computers.png | CLIENT01 in the Computers container |

## Next

Phase 4: OUs (IT, Sales, Disabled Users), 10 users and 3 security groups, created with PowerShell scripts.
