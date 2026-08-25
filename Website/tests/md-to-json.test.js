const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

it('writes entries.json containing the newest markdown post', () => {
  const workspace = path.join(__dirname, '..');
  const result = spawnSync(process.execPath, ['md-to-json.js'], {
    cwd: workspace,
    encoding: 'utf8',
  });

  if (result.status !== 0) {
    throw new Error(result.stderr || result.stdout);
  }

  const entriesJson = JSON.parse(fs.readFileSync(path.join(workspace, 'entries.json'), 'utf8'));
  const sources = entriesJson.entries.map((entry) => entry.source);
  expect(sources).toContain('10_blogAug2026.md');
});
