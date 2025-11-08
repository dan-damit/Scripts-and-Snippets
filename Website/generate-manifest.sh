#!/bin/sh

# ─── SYSTEM ─────────────────────────────────────────────────────────────
hostname=$(hostname)
dsmversion=$(grep productversion /etc/VERSION | awk -F= '{print $2}' | tr -d '"')
uptime=$(uptime -p)
loadavg=$(awk '{print $1, $2, $3}' /proc/loadavg)
cpu=$(grep 'model name' /proc/cpuinfo | uniq | awk -F: '{print $2}' | xargs)
memtotal=$(free -h | grep Mem | awk '{print $2}')
memused=$(free -h | grep Mem | awk '{print $3}')

# ─── STORAGE ────────────────────────────────────────────────────────────
diskusage=$(df -h /volume1 | awk 'NR==2 {print $5}')
raidstatus=$(grep -q '\[.*_.*\]' /proc/mdstat && echo "Degraded" || echo "Clean")

# ─── SERVICES ───────────────────────────────────────────────────────────
sshstatus=$(test -f /etc/ssh/sshd_config && echo "Configured" || echo "Not Configured")
firewallstatus=$(iptables -L | grep -q "Chain INPUT" && echo "Enabled" || echo "Disabled")

# ─── TIMESTAMP ──────────────────────────────────────────────────────────
lastsync=$(date +"%Y-%m-%d %H:%M:%S")

# ─── SMART Health ───────────────────────────────────────────────────────
smartstatus=""
for dev in /dev/sata?; do
  status=$(smartctl -H -d sat "$dev" 2>/dev/null | grep "SMART overall-health" | awk -F: '{print $2}' | xargs)
  status=${status:-Unavailable}
  smartstatus="$smartstatus$dev: $status; "
done

# ─── Bad Sector Count ───────────────────────────────────────────────────
for dev in /dev/sata?; do
  reallocated=$(smartctl -A -d sat "$dev" 2>/dev/null | grep -i "Reallocated_Sector_Ct" | awk '{print $10}')
  pending=$(smartctl -A -d sat "$dev" 2>/dev/null | grep -i "Current_Pending_Sector" | awk '{print $10}')
  offline=$(smartctl -A -d sat "$dev" 2>/dev/null | grep -i "Offline_Uncorrectable" | awk '{print $10}')
  badsectorstatus="$badsectorstatus$dev: Reallocated=$reallocated, Pending=$pending, Offline=$offline; "
done

# ─── OUTPUT ─────────────────────────────────────────────────────────────
echo "{
  \"Hostname\": \"$hostname\",
  \"DSMVersion\": \"$dsmversion\",
  \"Uptime\": \"$uptime\",
  \"LoadAvg\": \"$loadavg\",
  \"CPUModel\": \"$cpu\",
  \"MemoryTotal\": \"$memtotal\",
  \"MemoryUsed\": \"$memused\",
  \"DiskUsage\": \"$diskusage\",
  \"RAIDStatus\": \"$raidstatus\",
  \"SSHStatus\": \"$sshstatus\",
  \"FirewallStatus\": \"$firewallstatus\",
  \"SMARTStatus\": \"$smartstatus\",
  \"BadSectorStatus\": \"$badsectorstatus\",
  \"LastSync\": \"$lastsync\"
}" > /volume1/web/dan/manifest.json