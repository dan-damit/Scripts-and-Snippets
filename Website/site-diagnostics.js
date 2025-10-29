// site-diagnostics.js

// Load time
document.addEventListener('DOMContentLoaded', () => {
    const loadTime = performance.now().toFixed(2);
    const loadEl = document.getElementById('load-time');
    if (loadEl) loadEl.textContent = `${loadTime} ms`;
});

// Last sync (from manifest.json)
fetch('manifest.json')
    .then(res => res.json())
    .then(data => {
        document.getElementById('uptime').textContent = data.Uptime;
        document.getElementById('loadavg').textContent = data.LoadAvg;
        document.getElementById('disk').textContent = data.DiskUsage;
        document.getElementById('raid').textContent = data.RAIDStatus;
        document.getElementById('last-sync').textContent = data.LastSync;
    });