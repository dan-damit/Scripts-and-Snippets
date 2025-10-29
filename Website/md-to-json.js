const fs = require('fs');
const raw = fs.readFileSync('blog.md', 'utf8');

// Split entries by top-level headers
const blocks = raw.split(/^---$/gm).map(b => b.trim()).filter(Boolean);

const entries = blocks.map(block => {
    const lines = block.trim().split('\n');
    const title = lines[0].trim();
    const dateLine = lines.find(l => l.startsWith('**Date:**'));
    const tagsLine = lines.find(l => l.startsWith('**Tags:**'));

    const date = dateLine ? dateLine.replace('**Date:**', '').trim() : 'Unknown';
    const tags = tagsLine ? tagsLine.replace('**Tags:**', '').split(',').map(t => t.trim()) : [];

    // Remove metadata lines
    const contentLines = lines.filter(l => !l.startsWith('**Date:**') && !l.startsWith('**Tags:**')).slice(1);
    const content = contentLines.join('\n')
        .replace(/\^([^\^]+)\^/g, '<code>$1</code>')
        .replace(/```([\s\S]+?)```/g, (_, code) => {
            const cleaned = code.replace(/^\n/, ''); // remove leading newline in code blocks
            return `<pre><code>${cleaned}</code></pre>`;
        })
        .replace(/^### (.+)$/gm, '<h3>$1</h3>')
        .replace(/^## (.+)$/gm, '<h2>$1</h2>')
        .replace(/^# (.+)$/gm, '<h1>$1</h1>')
        .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
        .replace(/\[([^\]]+)\]\((https?:\/\/[^\)]+)\)/g, '<a href="$2" target="_blank">$1</a>') // links
        .split(/\n{2,}/) // split into paragraphs
        .map(p => {
            if (p.startsWith('<pre><code>')) return p; // skip <br> injection for code blocks
            return `<p>${p.replace(/\n/g, '<br>')}</p>`;
        })
        .join('');

    return { date, title, tags, content };
});

fs.writeFileSync('entries.json', JSON.stringify(entries, null, 2));
console.log(`✅ Parsed ${entries.length} entries into entries.json`);