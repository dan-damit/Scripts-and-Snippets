# Updated the Compliance Search tool

**Date:** 2026-1-3 **Tags:** powershell, modules, automation

## It got long so I made the fucs a module

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

UPDATE!! The above link is depricated. I moved it to its own repo - link below:

[Updated Repo URL](https://github.com/dan-damit/TechToolbox)

### dan

---

# The module is really coming along nicely

**Date:** 2026-1-17 **Tags:** powershell, module, scritpting

## It took a week of research

It took a week of reading and dealing with error after error to finaly get it to
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
