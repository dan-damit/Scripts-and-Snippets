const fs = require("fs");
const path = require("path");

const blogDir = path.join(__dirname, "md");
const blogFiles = fs
  .readdirSync(blogDir)
  .filter((f) => /^blog.*\.md$/i.test(f));

let allEntries = [];

for (const file of blogFiles) {
  const raw = fs.readFileSync(path.join(blogDir, file), "utf8");

  const normalized = raw.replace(
    /(\*\*Date:\*\*.*?)(\s+)(\*\*Tags:\*\*.*)/g,
    "$1\n$3"
  );

  const blocks = normalized
    .split(/^---$/gm)
    .map((b) => b.trim())
    .filter(Boolean);

  const entries = blocks.map((block) => {
    const lines = block.trim().split("\n");
    const title = lines[0].trim();
    const dateLine = lines.find((l) => l.startsWith("**Date:**"));
    const tagsLine = lines.find((l) => l.startsWith("**Tags:**"));

    const date = dateLine
      ? dateLine.replace("**Date:**", "").trim()
      : "Unknown";
    const tags = tagsLine
      ? tagsLine
          .replace("**Tags:**", "")
          .split(",")
          .map((t) => t.trim())
      : [];

    const contentLines = lines
      .filter((l) => !l.startsWith("**Date:**") && !l.startsWith("**Tags:**"))
      .slice(1);

    const content = contentLines
      .join("\n")
      .replace(/\^([^\^]+)\^/g, "<code>$1</code>")
      .replace(/```([\s\S]+?)```/g, (_, code) => {
        const cleaned = code.replace(/^\n/, "");
        const escaped = escapeHTML(cleaned);
        return `<pre><code>${escaped}</code></pre>`;
      })
      .replace(/^### (.+)$/gm, "<h3>$1</h3>")
      .replace(/^## (.+)$/gm, "<h2>$1</h2>")
      .replace(/^# (.+)$/gm, "<h1>$1</h1>")
      .replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>")
      .replace(
        /\[([^\]]+)\]\((https?:\/\/[^\s\)]+)\)/g,
        '<a href="$2" target="_blank" rel="noopener noreferrer">$1</a>'
      )
      .split(/\n{2,}/)
      .map((p) => {
        if (p.startsWith("<pre><code>")) return p;
        return `<p>${p.replace(/\n/g, "<br>")}</p>`;
      })
      .join("");

    return { date, title, tags, content, source: file };
  });

  allEntries.push(...entries);
}

function escapeHTML(str) {
  return str.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

const perPage = 5;
const totalEntries = allEntries.length;
const totalPages = Math.ceil(totalEntries / perPage);

const output = {
  entries: allEntries,
  pagination: {
    perPage,
    totalEntries,
    totalPages,
  },
};

fs.writeFileSync("entries.json", JSON.stringify(output, null, 2));
console.log(
  `✅ Parsed ${totalEntries} entries from ${blogFiles.length} files into entries.json`
);
