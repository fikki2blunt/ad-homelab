# INC-002 – Account locked out: Chloe Evans

| Field | Value |
| --- | --- |
| Type | Incident |
| Priority | P3 (one user can't work; no wider impact) |
| Caller | Chloe Evans (`cevans`), Sales |
| Logged | 2026-11-18 01:45 |
| Resolved | 2026-11-18 02:14 |
| Time spent | 29 min (includes setting up the lockout policy for the lab) |
| Status | Resolved |
| Assigned to | Fikki (1st line) |

## Description
> "It says my account is locked. I think I mistyped my new password a few times."

Follow-on from [INC-001](INC-001-password-reset.md): Chloe had just set a new password after her reset.

## Lab setup – account lockout policy
A new domain has **no lockout policy**, so accounts never lock. `Get-ADDefaultDomainPasswordPolicy` confirmed **LockoutThreshold 0**.

Set it in the **GUI**: Group Policy Management (`gpmc.msc`) → Forest: lab.local → Domains → lab.local → right-click **Default Domain Policy** → Edit → Computer Configuration → Policies → Windows Settings → Security Settings → Account Policies → **Account Lockout Policy**.

| Setting | Value | Meaning |
| --- | --- | --- |
| Account lockout threshold | 5 invalid logon attempts | Locks after 5 bad passwords – slows down password guessing |
| Account lockout duration | 15 minutes | Unlocks itself after 15 minutes, or IT unlocks it sooner |
| Reset account lockout counter after | 15 minutes | Bad-attempt counter resets after 15 minutes without a failure |

**Checked:** `Get-ADDefaultDomainPasswordPolicy` now shows LockoutThreshold 5, LockoutDuration 00:15:00, LockoutObservationWindow 00:15:00.

PowerShell equivalent (not used):
```powershell
Set-ADDefaultDomainPasswordPolicy -Identity lab.local -LockoutThreshold 5 -LockoutDuration 00:15:00 -LockoutObservationWindow 00:15:00
```

**Why the Default Domain Policy:** domain account lockout and password rules can only be set in a policy linked to the domain itself, normally the Default Domain Policy. A policy linked to an OU won't change them for domain accounts.

**Lockout caused by:** running `gpupdate /force` on CLIENT01, then entering a wrong password for `LAB\cevans` 5 times. CLIENT01 then showed: *"The referenced account is currently locked out and may not be logged on to."*

## Identity check
*Lab simulation:* confirmed it was Chloe by calling back on the number held for her before unlocking. Never asked for her password.

## Investigation (DC01)

```powershell
Search-ADAccount -LockedOut | Select Name, SamAccountName
Get-ADUser cevans -Properties LockedOut, BadLogonCount, LastBadPasswordAttempt |
  Select Name, LockedOut, BadLogonCount, LastBadPasswordAttempt
Get-WinEvent -FilterHashtable @{ LogName = 'Security'; Id = 4740 } -MaxEvents 5 |
  Select TimeCreated, @{ n = 'User'; e = { $_.Properties[0].Value } }, @{ n = 'Source PC'; e = { $_.Properties[1].Value } }
```

| Check | Result |
| --- | --- |
| Locked accounts in the domain | Only **Chloe Evans (cevans)**, so not a wider attack |
| LockedOut | **True** |
| BadLogonCount | **5** (matches the threshold) |
| LastBadPasswordAttempt | **18/11/2026 02:04:07** |
| Event 4740 (account locked out) | **02:04:07, user cevans, source PC CLIENT01** |

**Conclusion:** the lockout came from 5 bad passwords typed on Chloe's own PC, CLIENT01, at the time she reported. Nothing else (a phone, a saved password, a service) was involved, so unlocking was safe. Her password was still known to her, so **no reset was needed**.

GUI equivalents: ADUC → user → **Account** tab shows the lockout; Event Viewer → Windows Logs → Security → **Filter Current Log** → `4740` shows the event and the **Caller Computer Name**.

## Resolution

```powershell
Unlock-ADAccount -Identity cevans
```

GUI equivalent: ADUC → Sales → Chloe Evans → Properties → **Account** tab → tick **Unlock account** → OK.

## Verification
```powershell
Get-ADUser cevans -Properties LockedOut | Select Name, LockedOut
```
Result: **LockedOut False**.

## Note to user
> Hi Chloe, your account is unlocked. It locks after 5 wrong passwords to protect it from guessing. Your password hasn't changed, so use the new one you set earlier. If it locks again without you mistyping, let us know – it can mean an old password is saved on another device.

## Root cause / lessons
- **Cause:** 5 mistyped passwords on CLIENT01, confirmed by event 4740.
- **Lockout ≠ forgotten password:** unlock only, unless the user can't remember it. Resetting when it isn't needed creates extra work for the user.
- **Find the source** before closing a lockout ticket. Repeated lockouts from an unknown PC, or many accounts locking at once, can mean a password-guessing attack, so escalate to security.
- **Lockout is a security control** (brute-force protection). Too low a threshold creates helpdesk tickets; too high helps attackers.
- **Time zones:** both VMs were changed to GMT before this ticket, so event times matched the ticket times exactly.

## Screenshots
- [Account Lockout Policy in Group Policy Management](../screenshots/account%20lockout%20policy%20-%20group%20policy%20management.png)
- [Password policy before (threshold 0) and after (5)](../screenshots/dc01%20default%20policy.png)
- ["Account is locked out" on CLIENT01](../screenshots/incident002%20locked%20message.png)
- [Investigation and event 4740 showing CLIENT01](../screenshots/incident002-%20event%204740.png)
- [Unlocked – LockedOut False](../screenshots/inciden002%20unlocked.png)
