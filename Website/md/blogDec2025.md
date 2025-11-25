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

```JavaScript
const raw = fs.readFileSync(path.join(blogDir, file), "utf8");

const normalizedRaw = raw.replace(/\r\n/g, "\n").replace(/\r/g, "\n");
```

Then:

```JavaScript
const normalized = normalizedRaw.replace(
  /(\*\*Date:\*\*.*?)(\s+)(\*\*Tags:\*\*.*)/g,
  "$1\n$3"
);
```

Then finally, and update to how the final map() works if the parser detects
headers just how it was handling the pre and code elements:

```JavaScript
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
