# REQ-003 – New starter: Kemi Adeyemi, Sales Executive

| Field | Value |
| --- | --- |
| Type | Service request |
| Priority | P4 (planned, start date known) |
| Requested by | Hannah Wright (`hwright`), Sales Manager |
| New starter | Kemi Adeyemi, Sales Executive, reports to Hannah Wright |
| Completed | 2026-11-18 |
| Status | Resolved |
| Assigned to | Fikki (1st line) |

## Description
> "Kemi Adeyemi joins Sales on Monday as a Sales Executive, reporting to me. She needs the same access as the rest of the team."

## Approval check
The request came from her line manager, who can approve Sales access. Accounts are only created from an approved request (normally from HR or the manager), never from a phone call alone.

## Pre-checks
- Username `kadeyemi` (first initial + surname) was not already in use.
- The manager, Hannah Wright, exists in AD.
- "Same access as the team" = the **Sales-Team** group.

## Resolution (GUI)
1. ADUC → **Sales** → right-click **Sam Carter** (an existing Sales Executive) → **Copy…**
2. First name `Kemi`, Last name `Adeyemi`, User logon name `kadeyemi` → Next.
3. Set a temporary password and ticked **User must change password at next logon** → Next → Finish.
4. Opened Kemi's properties and checked or set:
   - **Organization** tab: Job Title and Department copied from Sam. Manager set to **Hannah Wright**.
   - **Member Of** tab: **Sales-Team** (copied from Sam).
   - **General** tab: ticket number added to Description.

| What was set | Why |
| --- | --- |
| Username `kadeyemi`, UPN `kadeyemi@lab.local` | Naming standard: first initial + surname |
| OU = Sales | Puts her under any Sales Group Policy (Phase 6) |
| Title, Department, Manager | Address book, org chart, and who approves her future requests |
| Sales-Team group | Gives Sales access; group nesting gives All-Staff too |
| Change password at next logon | Only Kemi will know her real password |

**Why check after copying:** "Copy" gives the new person *all* of the template user's groups. If Sam had extra access, Kemi would get it too. Always check the Member Of tab.

PowerShell equivalent (not used): [`scripts/new-starter.ps1`](../scripts/new-starter.ps1)
```powershell
& C:\LabScripts\new-starter.ps1 -First Kemi -Last Adeyemi -Department Sales -Title "Sales Executive" -Manager hwright -Ticket REQ-003
```

## Note to requester
> Hi Hannah, Kemi's account is ready: username **kadeyemi** (email-style sign-in kadeyemi@lab.local). I'll give her the temporary password in person on her first morning, and she'll set her own when she signs in. She has the same Sales access as the rest of the team.

## Lessons
- New starter = account + correct OU + correct groups + manager + temporary password. Missing any one creates a follow-up ticket.
- Copying an existing user is quick, but give access by role (the Sales-Team group), not by copying whatever a colleague happens to have.
- For many starters at once, a script makes every account identical (see `scripts/new-starter.ps1`).
