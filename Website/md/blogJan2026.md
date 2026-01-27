# Updated the Compliance Search tool

**Date:** 2026-1-3 **Tags:** powershell, modules, automation

## It got long so I made the funcs a module

The more I tinkered with the script, the longer it was getting, so I made all
the functions into a psm1 file, and an accompanying psd1 file for the script's
metadata. The updated URL is below:

[PurgeEMAILS Script](https://github.com/dan-damit/Scripts-and-Snippets/tree/main/PowerShell/Purge-ComplianceSearch)

I also made a script to clear out comments and blank lines in a script too.

[Clear Comment script](https://github.com/dan-damit/Scripts-and-Snippets/blob/main/PowerShell/Remove-PSComments.ps1)

### dan

---

# Creating a true module called my "TechToolbox"

**Date:** 2026-1-8 **Tags:** powershell, modules, scripting

## My first true module in the making

I don't have much time to get into it yet, but I just wanted to make the post
because I'm genuinely excited to get this project rolling.

[Code here](https://github.com/dan-damit/Scripts-and-Snippets/tree/main/PowerShell/TechToolbox)

UPDATE!! The above link is deprecated. I moved it to its own repo - link below:

[Updated Repo URL](https://github.com/dan-damit/TechToolbox)

### dan

---

# The module is really coming along nicely

**Date:** 2026-1-17 **Tags:** powershell, module, scripting

## It took a week of research

It took a week of reading and dealing with error after error to finally get it to
load successfully. It has been a battle and a very good learning opportunity.
It's over 100 functions total now for day-to-day ops. Most of it was copy pasta
from my existing script.

Public commands that orchestrate all the private helpers. I am expanding it to
include AD-User support, including hybrid support - on prem and Azure. There is
so much to talk about with it I almost don't know where to start. I suppose I'll
start with the configuration json. Values in the json can be adjusted without
touching any scripts, and the scripts will pick up the new values at runtime.
Handy since they're all signed so they can run in our environment.

The loader was getting up to 300 ish lines, so I ended up modularizing that too,
and broke out the loading helper functions into separate ps1 files that get
called by the loader. The result is a super sleek less that 80 line loader.

[Code here](https://github.com/dan-damit/TechToolbox)

It might actually be something I publish for the community to be honest. After I
get all the tools in the toolbox, and after I have squashed the last but, I
think I just might do that.

### dan

---

# Launching a process elevated with Task Scheduler

**Date:** 2026-1-26 **Tags:** scripting, powershell, pam

## One-time elevation with Task Scheduler

I was tasked with trying to launch a couple pieces of software (Microsoft
Dynamics GP Time Clock and Supervisor Time Logger) as an elevated process to
satisfy the old software's need to run these couple of tools as an
administrator. I ended up taking 12 hours between 2 days to get it working, but
I did manage to get it going properly.

The first issue was trying to use task scheduler to launch it using a PowerShell
script and a service account that was also part of local admin group. Keep in
mind, we do not give local admin to any "standard user" domain account as a
policy. Hence the need to try and get around that policy securely and launch the
tools as an administrator. 

I used DPAPI to create a localmachine.key to encrypt the service account's
password and store it in an XML. Then another script would be called by the
desktop shortcut to launch the tool using the service account and encrypted
password. 

The last two pieces of the puzzle were to let the standard user account launch
the tasks (one for each tool) by adjusting the task's permissions via another
PowerShell script - giving standard users Read and Execute; and the last
part was to have the launcher script point at sessionID 1 (the current user's
desktop console), so the UI of the Dynamics.exe TimeLog.set would launch
properly for the current user and not the service account used to launch the
thing (elevated).

The end flow was like this

```
1. Run a small script to prompt user for and store the service account username and password securely in an XML (encrypted)
2. This initial script would also create the localmachine.key used to encrypt the password
3. Then another script would create the Task and put the shortcut on the user's desktop
4. The Task pointed to a third script that would launch the tool using the creds in the XML (and use the localmachine.key to decrypt reliably)
    4.1. This script would target the current user's desktop console ID (generally always 1 if only one user is logged on).
5. User's Desktop shortcut to the task in Task Scheduler would launch the whole process of opening the tool under CU context.
```

It was a fun project that took WAY more doing than I anticipated last week. I
can't show you code on GitHub like the others in my posts though. It's
proprietary. In the end, no password information is stored on disk anywhere -
only in RAM after decryption then disposed of immediately after running the
task.

Doing it this way allowed the task to be run under SYSTEM context by the current
user without giving them elevated privileges or any privileged account credentials.

### dan
