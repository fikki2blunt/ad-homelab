\# Build log – Active Directory home lab



Host: Dell Latitude 7490, 8 GB RAM, VMs stored on a 500 GB external drive (V:)

Started: 2nd, November, 2026



\## Phase 0 – Preparation

\- External drive set to NTFS and letter G:, folders created

\- - Problems / fixes:

&#x20; - Repo location: chose `Downloads\\Git\_Clone\\ad-homelab` instead of `Documents` to keep all repos together. Checked Storage Sense is set to never auto-delete Downloads.

&#x20; - PowerShell opened as Administrator (started in `C:\\Windows\\System32`). Closed it and reopened a normal session via Win+R → `powershell`, since Git work doesn't need admin rights.

&#x20; - `Set-Location: A positional parameter cannot be found that accepts argument 'pwd'`: two commands were pasted on one line. Fix: run each command on its own line, or separate them with `;`.

&#x20; - Notepad couldn't find `docs\\build-log.md`: the new PowerShell window started in my user folder, not the project folder. Fix: `cd` into `ad-homelab` first, create the file with `New-Item`, then open it in Notepad.

&#x20; - Git doesn't track empty folders, so `screenshots`, `scripts` and `tickets` wouldn't appear on GitHub. Fix: added a `.gitkeep` placeholder file to each.

## Phase 1 – Hypervisor

\- Installed VirtualBox \[version] + Extension Pack

\- Set the default machine folder to G:\\HomeLab\\VMs (external drive) to save internal disk space

\- Downloaded the Windows Server 2022 and Windows 11 Enterprise evaluation ISOs to G:\\HomeLab\\ISOs

\- Problems / fixes: none

\- What I learned: VMs can live on an external drive as long as it's NTFS and keeps the same drive letter


## Phase 2 – Domain controller (DC01)

### Build summary
- VM: 2 vCPU, [4096 / 3072] MB RAM, 50 GB dynamically allocated disk, stored on the external drive (G:\HomeLab\VMs)
- Network: Adapter 1 = NAT (internet), Adapter 2 = Internal Network "lab"
- OS: Windows Server 2022 Standard Evaluation (Desktop Experience)
- Installed VirtualBox Guest Additions (amd64) for display, mouse, clipboard and time sync
- Internal adapter: static IP 10.0.0.1/24, DNS 127.0.0.1, no default gateway
- Renamed the server to DC01
- Installed the AD DS role, then promoted DC01 to a new forest: lab.local (NetBIOS: LAB) with DNS
- Signed in as LAB\Administrator and confirmed DC01 is in the Domain Controllers OU
- Snapshot taken: "DC01 – fresh domain"
- Screenshots: 02-dc01-vm-settings, 03-dc01-ip-config, 04-ad-ds-installed, 05-aduc-lab-local

### Problem 1: setup failed – "Windows cannot find the Microsoft Software License Terms"
- **Symptom:** Setup stopped at "Setup is starting" with this error.
- **Diagnosis:** VM Settings → Storage showed VirtualBox's auto-generated "Unattended" ISO in the
  optical drive instead of the Windows Server 2022 ISO. The VM had been created without
  ticking "Skip Unattended Installation".
- **Fix:** Swapped the optical drive to the Server 2022 ISO, set RAM to [4096] MB and removed
  Floppy from the boot order. Setup then ran normally.
- **Lesson:** When an install fails, check what media the machine is actually booting from
  before blaming the ISO or the hardware.

### Problem 2: Ctrl+Alt+Delete went to my PC, not the VM
- **Fix:** Used Input → Keyboard → Insert Ctrl-Alt-Del (or Right Ctrl + Delete).
- **Lesson:** The host catches some key combinations, so the hypervisor gives a way to send them to the VM.

### Problem 3: Guest Additions menu option did nothing
- **Fix:** Mounted it manually with the status-bar CD icon → Choose a disk file →
  C:\Program Files\Oracle\VirtualBox\VBoxGuestAdditions.iso, then ran VBoxWindowsAdditions-amd64.exe.
- **Lesson:** Guest Additions are drivers for the virtual hardware. The physical-machine
  equivalent is missing drivers, fixed with Device Manager, Windows Update or the
  manufacturer's tool (e.g. Dell Command Update).

### Problem 4: adapter names didn't match the guide
- **Symptom:** The guide said the internal adapter would be "Ethernet 2".
- **Diagnosis:** `Get-NetIPAddress -AddressFamily IPv4` showed "Ethernet" = 169.254.x.x
  (internal, no DHCP) and "Ethernet 2" = 10.0.2.15 (VirtualBox NAT).
- **Fix:** Configured "Ethernet" instead.
- **Lesson:** Identify adapters by their current IP, not by name, before changing settings.
  (Also learned PowerShell commands are Verb-Noun with no spaces, e.g. Get-NetIPAddress.)

### Problem 5: domain promotion failed the prerequisite check
- **Error:** "The Directory Services Restore Mode password does not meet the password complexity requirements."
- **Cause:** The DSRM password was too simple. Windows checks prerequisites before making
  any changes, so nothing had been modified.
- **Fix:** Re-ran Install-ADDSForest with a password of 8+ characters using at least 3 of:
  upper case, lower case, numbers, symbols.
- **Lesson:** Read the red error line, because it says exactly what's wrong. The same complexity
  rules apply to user passwords, which is a common helpdesk question.

### Problem 6: DNS warning during promotion
- **Warning:** "An error occurred while the wizard was installing DNS. You will have to configure DNS manually."
- **Checks:** DNS role [installed / missing], DNS service [running / stopped],
  zones lab.local and _msdcs.lab.local [present / missing], DC SRV record [found / not found].
- **Fix:** [e.g. "none needed, all checks passed" OR "created the zones with
  Add-DnsServerPrimaryZone, then ran ipconfig /registerdns and restarted Netlogon"].
- **Verified:** `dcdiag /test:dns` [passed].
- **Lesson:** AD depends on DNS. Clients find domain controllers through SRV records in
  _msdcs, so if DNS is broken nothing can join or sign in to the domain.

### Notes
- Promotion took about [X] minutes. "Waiting for DNS installation to finish" was the slowest
  step, because the VM runs from an external USB drive.
- Yellow warnings during promotion (NT 4.0 cryptography default, DNS delegation, NAT adapter
  without a static IP) are expected in a lab. Only red text is a real error.

### What I learned
- A fresh Windows Server is not a domain controller. AD is two steps:
  1. **Install the role:** `Install-WindowsFeature AD-Domain-Services -IncludeManagementTools`
     adds the software and tools only.
  2. **Promote the server:** `Install-ADDSForest -DomainName "lab.local" -DomainNetbiosName "LAB" -InstallDns`
     creates the forest and domain, makes DC01 the first domain controller, and sets up DNS.
- The first domain also creates the forest. "LAB" is the short name used in sign-ins (LAB\Administrator).
- The DSRM password is a separate emergency password for repairing AD offline. It's kept in a
  password manager, not in this log.
- A domain controller needs a static IP and must use itself for DNS.
- No default gateway on the internal adapter: DC01 reaches the internet through the NAT adapter,
  and a machine should have only one default gateway. ".1 is the gateway" is a habit, not a rule.
  A device is the gateway only if clients are configured to use it and it routes traffic.
- After promotion, the local Administrator becomes the domain administrator (LAB\Administrator).


