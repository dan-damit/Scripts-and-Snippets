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

**Date:** 2025-12-12 **Tags:** scripting, shell scripting, dsm

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
