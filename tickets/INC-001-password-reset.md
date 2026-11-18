# INC-001 – Forgotten password: Chloe Evans

| Field | Value |
| --- | --- |
| Type | Incident |
| Priority | P3 (one user can't work; no wider impact) |
| Caller | Chloe Evans (`cevans`), Sales |
| Logged | 2026-11-18 00:44 |
| Resolved | 2026-11-18 01:18 |
| Time spent | 34 min (includes ~3 min waiting for AD to start after booting DC01) |
| Status | Resolved |
| Assigned to | Fikki (1st line) |

## Description
> "I've been on holiday for two weeks and I can't remember my password. Can you reset it?"

## Identity check
Before resetting anything, confirm the caller really is Chloe. A password reset for the wrong person is an easy way for an attacker into an account (social engineering).

- *Lab simulation:* verified by calling her back on the number held for her and asking her manager (Hannah Wright) to confirm, rather than trusting the incoming call.
- Never asked for her old password.

## Investigation (DC01)

```powershell
Get-ADUser cevans -Properties Enabled, LockedOut, PasswordLastSet, PasswordExpired, BadLogonCount, LastLogonDate |
  Select Name, Enabled, LockedOut, PasswordLastSet, PasswordExpired, BadLogonCount, LastLogonDate
```

| Check | Why | Result |
| --- | --- | --- |
| Enabled | A disabled account is a different problem (leaver? HR?) – don't just re-enable it | **True** |
| LockedOut | If locked, a reset alone won't let her in; unlock as well | **Unlocked** (the Reset Password dialog shows "Account Lockout Status on this Domain Controller: Unlocked") |
| PasswordExpired | Tells you whether she forgot it or it simply expired | **True** – see note below |

**Why PasswordExpired was True:** her account still had "User must change password at next logon" set. It was set when the account was created in Phase 4, and she had never signed in. AD records this by clearing the password's last-set date, so it reports the password as expired. It doesn't mean the password reached the end of its maximum age.

**Conclusion:** the account was enabled and not locked, so only a password reset was needed.

## Resolution

Used the **GUI**: ADUC → lab.local → **Sales** → right-click **Chloe Evans** → **Reset Password** → entered a temporary password twice → ticked **User must change password at next logon** → OK.

- **Unlock the user's account** was left unticked because the account wasn't locked.
- The temporary password was given to her by phone, not written in the ticket or sent by email.

PowerShell equivalent (not used this time):
```powershell
Set-ADAccountPassword -Identity cevans -Reset -NewPassword (Read-Host -AsSecureString "Temporary password")
Set-ADUser -Identity cevans -ChangePasswordAtLogon $true
```

## Verification (CLIENT01)
- Other user → `LAB\cevans` with the temporary password.
- Windows showed **"The user's password must be changed before signing in."** This proves the reset and the "change at next logon" setting both worked.
- Set a new password and reached the desktop. `whoami` → **`lab\cevans`**. Signed in as the correct domain user.

## Note to user
> Hi Chloe, your password has been reset and you've been given a temporary one by phone. You'll be asked to choose a new password when you sign in. It needs at least 7 characters with a mix of upper case, lower case, numbers or symbols. Let us know if you have any trouble.

## Problems during the ticket
**ADUC wouldn't open straight after booting DC01**
- **Cause:** the AD services were still starting, which is slower because the VM runs from the external USB drive.
- **Fix:** waited 2–3 minutes and it opened.
- **Lesson:** after a DC reboot, give AD time to start before assuming it's broken.

**First temporary password rejected**
- **Symptom:** a 4-character temporary password in the Reset Password dialog gave a password policy error.
- **Cause:** the Default Domain Policy needs at least 7 characters, plus complexity (3 of: upper case, lower case, numbers, symbols). The policy applies to passwords set by admins too, not just users.
- **Fix:** entered a longer password that met the rules. The reset then succeeded.
- **Lesson:** the error proves the password policy is enforced. Check the rules with `Get-ADDefaultDomainPasswordPolicy`. Users who hit the same error on their forced change are a common helpdesk call.

**DC01 clock set to US Pacific time**
- **Finding:** the taskbar showed 17/11/2026 5:01 PM when UK time was about 01:00 on 18/11. The time zone was left at the installer default.
- **Why it matters:** event logs and ticket times won't match, which makes investigations (e.g. finding a lockout in INC-002) confusing. Kerberos itself uses UTC, so sign-ins still work.
- **Fix:** `Set-TimeZone -Id "GMT Standard Time"` on DC01 and CLIENT01.

## Root cause / lessons
- Cause: user forgot password after time away. No fault.
- Always verify identity first. A reset is a security action, not just an admin task.
- Check the account before acting. The lockout status in the reset dialog showed no unlock was needed.
- "Change at next logon" means only the user knows the final password, not IT.
- Self-service password reset (e.g. Microsoft Entra SSPR) reduces these tickets in real companies.

## Screenshots
- [Reset Password dialog in ADUC](../screenshots/incident001-reset%20password.png)
- [Forced password change on CLIENT01](../screenshots/incident001-%20forced%20change%20upon%20login.png)
