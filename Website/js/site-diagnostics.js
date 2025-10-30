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
        document.getElementById('hostname').textContent = data.Hostname;
        document.getElementById('dsm').textContent = data.DSMVersion;
        document.getElementById('uptime').textContent = data.Uptime;
        document.getElementById('loadavg').textContent = data.LoadAvg;
        document.getElementById('cpu').textContent = data.CPUModel;
        document.getElementById('memtotal').textContent = data.MemoryTotal;
        document.getElementById('memused').textContent = data.MemoryUsed;
        document.getElementById('disk').textContent = data.DiskUsage;
        document.getElementById('raid').textContent = data.RAIDStatus;
        document.getElementById('ssh').textContent = data.SSHStatus;
        document.getElementById('firewall').textContent = data.FirewallStatus;
        document.getElementById('smart').textContent = data.SMARTStatus;
        document.getElementById('badsectorstatus').innerHTML = data.BadSectorStatus.replace(/; /g, ';<br>');
        document.getElementById('last-sync').textContent = data.LastSync;
    });