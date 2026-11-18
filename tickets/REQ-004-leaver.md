# REQ-004 – Leaver: Daniel Osei, Sales Executive

| Field | Value |
| --- | --- |
| Type | Service request |
| Priority | P2 on the leaving day (access must stop on time) |
| Requested by | Hannah Wright (`hwright`), Sales Manager |
| Leaver | Daniel Osei (`dosei`), Sales |
| Completed | 2026-11-18 |
| Status | Resolved |
| Assigned to | Fikki (1st line) |

## Description
> "Daniel Osei's last day is Friday. Please remove his access at 5pm."

## Approval check
Leaver requests come from HR or the line manager. A request from anyone else is checked with them first, because removing the wrong person's access stops them working.

## Before changes – record his access
ADUC → Sales → Daniel Osei → **Member Of** tab showed:

| Group | Note |
| --- | --- |
| Domain Users | Primary group – can't be removed |
| Sales-Team | Sales access (and All-Staff through nesting) |

Screenshot taken as the record, so his access can be restored or copied if needed.

## Resolution (GUI)
1. **Member Of** tab → selected **Sales-Team** → **Remove** → Apply.
2. **General** tab → Description: `Leaver - disabled 2026-11-18 (REQ-004)` → OK.
3. Right-click Daniel → **Reset Password** → long random password nobody knows → OK.
4. Right-click Daniel → **Disable Account**. A down-arrow appeared on his icon.
5. Right-click Daniel → **Move…** → **Disabled Users** → OK.

| Step | Why |
| --- | --- |
| Record groups first | If he returns, or a manager needs his access copied, it can be restored |
| Remove groups | Removes access to shares, apps and printers |
| Description = date + ticket | Anyone who finds the account knows why it's disabled |
| Scramble password | Even if someone re-enables it by mistake, nobody knows the password |
| Disable account | Blocks sign-in immediately, but keeps the account and its SID |
| Move to Disabled Users | Keeps leavers separate; easy to review and delete after the retention period (e.g. 30–90 days) |

**Why disable, not delete:** deleting is permanent (without the AD Recycle Bin) and loses the SID, so file permissions show as unknown accounts. Mailbox, files and audit history may also need to be kept.

PowerShell equivalent (not used): [`scripts/leaver.ps1`](../scripts/leaver.ps1) does all six steps and saves the group list to a file.
```powershell
& C:\LabScripts\leaver.ps1 -Username dosei -Ticket REQ-004
```

## Note to requester
> Hi Hannah, Daniel's account was disabled at 5pm and removed from the Sales group, so he no longer has access to anything. The account is kept (disabled) in case his files or history are needed. Please let me know if anything of his needs passing to another team member.

## Real-world extras (not in this lab)
- Convert the mailbox to a shared mailbox, or set an auto-reply / forward to the manager.
- Transfer OneDrive / home-drive files to the manager.
- Revoke Microsoft 365 sessions, remove MFA methods, collect the laptop and phone, and disable VPN and any SaaS accounts not linked to AD.

## Lessons
- Leavers are a **security** task: an ex-employee with working access is a classic insider-risk and audit finding.
- Record → remove groups → scramble → disable → move. Delete only after the retention period.
- Doing it at the agreed time matters as much as doing it at all.

## Screenshots
- [Daniel Osei – Member Of before removal](../screenshots/req004-%20daniel%20osei%20member%20of.png)
