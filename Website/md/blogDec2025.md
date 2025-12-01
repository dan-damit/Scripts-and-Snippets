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
