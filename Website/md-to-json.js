const fs = require('fs');
const raw = fs.readFileSync('blog.md', 'utf8');

// Split entries by top-level headers
const blocks = raw.split(/^---$/gm).map(b => b.trim()).filter(Boolean);

const entries = blocks.map(block => {
    const lines = block.split('\n');
    const title = lines[0].trim();
    const dateLine = lines.find(l => l.startsWith('**Date:**'));
    const tagsLine = lines.find(l => l.startsWith('**Tags:**'));

    const date = dateLine ? dateLine.replace('**Date:**', '').trim() : 'Unknown';
    const tags = tagsLine ? tagsLine.replace('**Tags:**', '').split(',').map(t => t.trim()) : [];

    // Remove metadata lines
    const contentLines = lines.filter(l => !l.startsWith('**Date:**') && !l.startsWith('**Tags:**')).slice(1);
    const content = contentLines.join('\n')
        .replace(/^### (.+)$/gm, '<h3>$1</h3>')       // Convert ### headers
        .replace(/^## (.+)$/gm, '<h2>$1</h2>')        // Convert ## headers
        .replace(/^# (.+)$/gm, '<h1>$1</h1>')         // Convert # headers
        .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>') // Bold
        .replace(/\n{2,}/g, '</p><p>')               // Paragraph breaks
        .replace(/\n/g, '<br>')                      // Line breaks
        .replace(/^/, '<p>')
        .concat('</p>');

    return { date, title, tags, content };
});

fs.writeFileSync('entries.json', JSON.stringify(entries, null, 2));
console.log(`✅ Parsed ${entries.length} entries into entries.json`);