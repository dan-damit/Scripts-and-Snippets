# This is a test

**Date:** 2025-11-24 **Tags:** test

## This is a test

This is a test

[code here](https://amazon.com)

### dan

---

# Last night's test for multiple markdown files

**Date:** 2025-11-25 **Tags:** markdown, javascript

## So I had to further adjust the parser

I had to adjust the parser to handle the new files like the original blog.md
file:

```
const raw = fs.readFileSync(path.join(blogDir, file), "utf8");

const normalizedRaw = raw.replace(/\r\n/g, "\n").replace(/\r/g, "\n");
```

Then:

```
const normalized = normalizedRaw.replace(
  /(\*\*Date:\*\*.*?)(\s+)(\*\*Tags:\*\*.*)/g,
  "$1\n$3"
);
```

Then finally, and update to how the final map() works if the parser detects
headers just how it was handling the pre and code elements:

```
.map((p) => {
    if (
        p.startsWith("<pre><code>") ||
        p.startsWith("<h1>") ||
        p.startsWith("<h2>") ||
        p.startsWith("<h3>")
    )
        return p;
    return `<p>${p}</p>`;
})
```

So this removed the carraige return \r that were causing the blog cards to look
weird with lots of spacing between lines, and it also let the CSS styling map to
links in the blog cards like with the orignial blog.md file.

[Code here](https://github.com/dan-damit/Scripts-and-Snippets/blob/main/Website/md-to-json.js)

### dan

---

# Spinning up an SQL sandbox

**Date:** 2025-11-30 **Tags:** sql, learning, server

## With the new gig, I'll be doing some SQL stuff

So I wanted to get a jump start on the SQL stuff by spinning up a 2022 Sever and
installing SQL Express. I got it all setup and installed, along with installing
SSRS. I am not sure how to load some sample data just yet though. Do I need to
enter it manually, or can I find a download and import it? I'll get to work on
this tomorrow. Maybe I could also find some free courses that I could do in the
couple of weeks leading up to the new gig.

I'm so freakin' stoked to open this new chapter in my career using SQL. 5-10
years out, I'm hoping this will open doors as a BI Analyst type of track. That's
the plan anyway!

### dan

---

# Adapting $PSScriptRoot for exe

**Date:** 2025-12-01 **Tags:** powershell, scripting

## I have been wrapping PS scripts lately

And one thing I learned is, after wrapping the .ps1 in an exe using PS2EXE
module is $PSScriptRoot doesn't like to work after compiling it like it does
when running the script from a console. I did a little searching and reading and
found this to be a suitable replacement for $PSScriptRoot when compiling the
script to executable:

```
$baseDir = [System.IO.Path]::GetDirectoryName([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
```

The above line functionally acts like $PSScriptRoot variable. It essentially
grabs the current directory in which the exe resides.

### dan

---

# Generated my first SQL report today

**Date:** 2025-12-04 **Tags:** sql, scripting, server

## Man this is going to be so fun

I generated my first report today. I loaded the Adventure Works 2022 sample
database from a .bak file that I found on GitHub. Just a small 200MB .bak file
that I can use as my sandbox for making reports. SSRS and making dashboards will
be a big componenet of the new job. AND I CANNOT WAIT! I haven't been this
excited for a new job...ever honestly.

After I loaded the database data from the backup and got a SSRS instance online,
I tried to do the "Design a query" window for a bit, spinning my wheels. Then I
found the Text editor section. That's where the query came in. Copy and pasted
the below code:

```
SELECT
    st.Name AS Region,
    YEAR(soh.OrderDate) AS OrderYear,
    MONTH(soh.OrderDate) AS OrderMonth,
    SUM(soh.TotalDue) AS TotalSales
FROM Sales.SalesOrderHeader soh
JOIN Sales.SalesTerritory st ON soh.TerritoryID = st.TerritoryID
GROUP BY st.Name, YEAR(soh.OrderDate), MONTH(soh.OrderDate)
ORDER BY st.Name, OrderYear, OrderMonth;
```

After I had connected the datasource:

```
Data Source=WINSERVER2022\SQLEXPRESS;Initial Catalog=AdventureWorks2022
```

Then it was just a matter of assigning the
selections to column/row/value and BAM. My first test report was generated. It's
ugly as all get-up yet, but I think the prettiness will come over time.

### dan

---

# Starting up a second query

**Date:** 2025-12-06 **Tags:** sql, server, scripting

## Tryin a second query

I wanted to grab FirstName, LastName, and EmailAddress from employees:

```
SELECT
    p.FirstName,
    p.LastName,
    ea.EmailAddress
FROM HumanResources.Employee e
JOIN Person.Person p
    ON e.BusinessEntityID = p.BusinessEntityID
JOIN Person.EmailAddress ea
    ON p.BusinessEntityID = ea.BusinessEntityID
ORDER BY p.LastName, p.FirstName;
```

The hard part still is figuring out JOINS and how to structure them using the
Primary and Secondary Keys. So I started reading up on how they interact with
each other, and why all the tables don't just "talk" to each other by default.
Turns out that is something that is learned early on in relational database
management. I will probably make a post about that in the coming days (since
doing the posts help me hammer it home in my head - like how writing stuff down
helps some people remember things).

I think there is a way to query a DB for table key information and how they
relate to each other. I read up a bit on it online and had trusty Copilot help
break it down into a digestible format. I think the three queries below will
show the keys for the AdventureWorks2022 sandbox I loaded up.

### Primary Keys:

```
SELECT
    t.name AS TableName,
    c.name AS ColumnName,
    i.name AS PrimaryKeyName
FROM sys.indexes i
JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
JOIN sys.tables t ON i.object_id = t.object_id
WHERE i.is_primary_key = 1
ORDER BY TableName;
```

### Secondary Keys:

```
SELECT
    fk.name AS ForeignKeyName,
    tp.name AS ParentTable,
    cp.name AS ParentColumn,
    tr.name AS ReferencedTable,
    cr.name AS ReferencedColumn
FROM sys.foreign_keys fk
JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
JOIN sys.tables tp ON fkc.parent_object_id = tp.object_id
JOIN sys.columns cp ON fkc.parent_object_id = cp.object_id AND fkc.parent_column_id = cp.column_id
JOIN sys.tables tr ON fkc.referenced_object_id = tr.object_id
JOIN sys.columns cr ON fkc.referenced_object_id = cr.object_id AND fkc.referenced_column_id = cr.column_id
ORDER BY ParentTable, ForeignKeyName;
```

### Constraints:

```
SELECT
    t.name AS TableName,
    c.name AS ColumnName,
    con.name AS ConstraintName,
    con.type_desc AS ConstraintType
FROM sys.objects con
JOIN sys.tables t ON con.parent_object_id = t.object_id
JOIN sys.columns c ON c.object_id = t.object_id
WHERE con.type_desc IN ('PRIMARY_KEY_CONSTRAINT','FOREIGN_KEY_CONSTRAINT','CHECK_CONSTRAINT','DEFAULT_CONSTRAINT','UNIQUE_CONSTRAINT')
ORDER BY TableName;
```

[Contraints Tips](https://www.mssqltips.com/sqlservertip/7547/what-is-a-sql-constraint/)

### dan

---

# Tweaking the matrix-rain engine

**Date:** 2025-12-09 **Tags:** javascript, scripting

## Adding some depth to the canvas

I wanted to have more depth in the Rain effect. So I was brainstorming how to
accomplish that without loading down slower computers like my attempt a couple
of months ago. I ended up having each column's font size pick a random size when
the loop starts for that column.

```
draw() {
    this.ctx.fillStyle = "rgba(0, 0, 0, 0.1)";
    this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);

    for (let i = 0; i < this.drops.length; i++) {
      const text =
        this.letters[Math.floor(Math.random() * this.letters.length)];
      const depth = this.depths[i];

      const size = this.fontSize * (0.5 + depth * 1.5);
      this.ctx.font = `${size}px monospace`;
      const brightness = Math.floor(100 + depth * 155);
      this.ctx.fillStyle = `rgb(0, ${brightness}, 0)`;

      this.ctx.shadowColor = "transparent";
      this.ctx.shadowBlur = (1 - depth) * 8;
      const x = i * this.fontSize + depth * 10;

      this.ctx.fillText(text, x, this.drops[i] * size);

      if (this.drops[i] * size > this.canvas.height && Math.random() > 0.975) {
        this.drops[i] = 0;
      }
      this.drops[i]++;
    }
  }
```

This effectively let the column decide at draw time to pick a font size randomly
between 0.5 and 1.5 times the default size. The result has been just was I was
looking for. I also added an overlay based off of a cool idea I found someone
post on a medium.com article, which had a link in it to the author's repo.

[His code](https://github.com/andresz74/matrix/blob/main/matrix.js)

I adapted the Overlay into my matrix-rain.js file because I loved the effect of
it seeming like rain drops were hitting the backstop of the canvas.

[My code](https://github.com/dan-damit/Scripts-and-Snippets/blob/main/Website/js/matrix-rain.js)

### dan

---

# Changing the DSM default favicon

**Date:** 2025-12-11 **Tags:** scripting, shell scripting, dsm

## I wanted a custom favicon for DSM

I wanted to make my custom "Matrix-styled" favicon work for DSM because the
default one is boring. Some digging showed that the syno user houses the favicon
and other default .png files that get served up for browsers. I didn't really
want to change the .pngs because DSM requires them to be certain names, so I
skipped that part. The shell script below automates changing the favicon.ico
file to my custom one:

[Script here](https://github.com/dan-damit/Scripts-and-Snippets/blob/main/shell%20scripts/update-favicon.sh)

DSM will change back to the defaults when it's updated so this script will
automate that next time it updates. Thankfully DSM doesn't seem to update that
often. At least version 7 doesn't from what I've noticed.

### dan

---

# Modularizing the build script

**Date:** 2025-12-12 **Tags:** scripting, powershell

## I was making some changes to the WS onboarding tool

I wanted to remove all references to my old company in all aspects of my
onboarding tool, which was fine and easy. I created a build script for compling
the tool months and months ago, but using it tonight to recompile my tool, I
was getting error after error... It was quite the rabbit hole - more like a
rabbit apartment complex...

Some time ago (who knows when), I was troubleshooting something else with NuGet
packages, and I ended up mirroring some locally to a dir on C:. That dir didn't
exist anymore, so I had to remove that as a source. Removing it caused issues
with the dotnet build commands. I also had to remove the local dir as a source for
NuGet packages.

On to the next issue... dotnet was not happy....or maybe just out of date since
I hadn't needed it for the last 4 months. Updated all the dotnet stuff and it
worked manually.

I'm never really content with leaving a script alone, so I wanted to modularize
the PowerShell build script I use to build my workstation onboarding tool. It
took me almost 2 hours to realize why manually running the dotnet commands in
the $projDir worked, but running it from my script would fail out.

Turns out it was the way dotnet was interpreting the commands when I was wanting
them to run within a function (I love modularizing stuff). The code that
eventually worked is below:

```
# === Helper Functions ===
function Run-DotnetCommand($command, $projDir) {
    UpdateStatus "Running: dotnet $command in $projDir"
    Push-Location $projDir
    $parts = $command -split ' '
    & dotnet @parts
    $exit = $LASTEXITCODE
    Pop-Location
    if ($exit -ne 0) { throw "dotnet $command failed in $projDir" }
}

function Build-Project($name, $artifactPath, $signType) {
    $projDir = Join-Path $projectRoot $name
    UpdateStatus "Cleaning $name"
    Run-DotnetCommand "clean" $projDir
    Run-DotnetCommand "restore" $projDir
    Run-DotnetCommand "build -c Release" $projDir
    Run-DotnetCommand "publish -c Release" $projDir

    if ($artifactPath) {
        UpdateStatus "Signing $signType"
        & signtool sign /fd SHA256 /f $certPath /p $certPassword /tr $timestampUrl /td SHA256 $artifactPath
        if ($LASTEXITCODE -ne 0) { throw "Signing $signType failed" }
    }
}

function Build-UIProject {
    $projDir = Join-Path $projectRoot "WS_Setup_6.UI"
    $uiExe   = "$projDir\bin\Release\net8.0-windows\win-x64\publish\WS_Setup_6.UI.exe"

    UpdateStatus "Cleaning UI project"
    Run-DotnetCommand "clean" $projDir
    Run-DotnetCommand "restore" $projDir
    Run-DotnetCommand "build -c Release" $projDir
    # Framework-dependent publish (runtime provided separately in Assets)
    Run-DotnetCommand "publish -c Release -r win-x64" $projDir

    if (Test-Path $uiExe) {
        UpdateStatus "Signing UI executable"
        & signtool sign /fd SHA256 /f $certPath /p $certPassword /tr $timestampUrl /td SHA256 $uiExe
        if ($LASTEXITCODE -ne 0) {
            throw "Signing UI executable failed"
        }
    } else {
        throw "UI exe not found at $uiExe"
    }
}
```

Adding the $parts variable as $command -split ' ' to make the "build -c Release"
into an array instead of a regular string was the winning tweak; dotnet was then
able to fire correctly with the "& dotnet @parts" line.

```PowerShell
$parts = $command -split ' '

& dotnet @parts
```

### dan

---

# Been a busy start to the new job

**Date:** 2025-12-20 **Tags:** powershell, scripting

## A custom battery health report

I had a some time on Friday to take a look at some of the scripts that the guys
on my team had come up with in the past. The first one that was brought up to me
was a custom battery health report. It's a fairly old script, written in what
looks like 2020 or so based on the last modified date on the file. It wassn't
using Window's built in battery health report tool, which outputs a fancy lookng
html with some very detailed informaiton on a laptop's battery.

I ended up using that report as my base:

```PowerShell
$reportPath = "C:\temp\battery-report.html"

powercfg /batteryreport /output "$reportPath" | Out-Null
```

Then from that fancy report, after a ton of save and test cycles, I was able to
parse the first and second tables into a json. These two tables have great
information that our team can use. I was hoping that report had an option
to be directly output to JSON but html is the only output that Windows supports.

[Code here](https://github.com/dan-damit/Scripts-and-Snippets/blob/main/PowerShell/batteryHealthReport.ps1)

I also added a simple calculation to figure out the battery's health as a
percentage. Also, the output into a JSON can make it so we can easily use that
data in other reporting tools in the future.

### dan

---

# Fixing scripts!

**Date:** 2025-12-24 **Tags:** powershell, scripting, automation

## I created a browser cache cleanup tool

In February we're flipping the switch to all cloud based ERP, so I am betting we
will see an uptick in browser cache issues. So, what I ended up doing then is
making a new script with lots of guardrails for error handling gracefully. 

[Code here](https://github.com/dan-damit/Scripts-and-Snippets/blob/main/PowerShell/DumpBrowserCache/DumpBrowserCache.ps1)

I also parameterized many things all the way down to a -WhatIf for dry run
support. This scripts supports Chrome and Edge, and you can pick between them or
do them both at the same time. It currenly only targets cache and cookies. It
doesn't touch anything else like passwords and browsing history.

### dan

---

# Created two new PowerShell tools

**Date:** 2025-12-27 **Tags:** powershell, scripting, automation

## One for Remote DISM execution

The other to automate purging phishing emails from our server permanently. I
didn't really get a chance to script remote DISM execution since our RMM
platform already setup remote shells adhoc. There was no need to script it. At
the new job however, we don't really have a true RMM. the code to both is below:

[RemoteDISM script](https://github.com/dan-damit/Scripts-and-Snippets/blob/main/PowerShell/RemoteSessionDISM.ps1)
[PurgeEMAIL script](https://github.com/dan-damit/Scripts-and-Snippets/blob/main/PowerShell/Purge-ComplianceSearch.ps1)

I haven't tested the Remote DISM scripts yet. I am reviewing everything to the
nth degree to make sure it won't trip our AV software.

I'll update with another post after testing.

### dan

---

# Built a super cool automation today

**Date:** 2025-12-30 **Tags:** powershell, automation, scripting

## Automation with PowerShell is INSANELY fun

So it started with some of the guys wanting me to take a look at an in-progress
project. The ultimate goal was to passwordlessly authenticate to an Azure App
Registration to Mail.Send using Microsoft Graph. :D

They had most of the script already written, but were stuck on the auth using a
certificate. I will make an environment-agnostic version of it for my personal
repo that doesn't include any of our environment information at all, but that
will come later once it's fully running smoothly.

The App permission needed Application permission -> Mail.Send with administrator
authorization - meaning it's pretty secure. And on top of that you can further
restrict which accounts you want to even have the Mail.Send ability from the
app. Meaning, you can lock it down to just one authorized account to send the
mail this way using Graph. The auth is handled by a Cert to use with the private
key imported on the server running the script, and the public matching pair in
the Azure App Registration. 

From there, the script needed the Tenant ID, the Org domain for the connection
to Exchange Online, the Client ID of the App, and the Thumbprint of the cert you
want to use, and the specific 'From' you authorized to even 'send as'.

We wanted some specific email stats on a mail group like how many were
sent and how many were received per member of the group.

After that it was a few hours of VSCode to build the script (roughly 150 lines
or so without including comments and blank lines). I had it setup to use HTML to
build the table out to look pretty. HTML + CSS took care of the formatting of
the table in the email. Looks nice. 

That has been the most fun I've had coding in months.

### dan
