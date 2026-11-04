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

