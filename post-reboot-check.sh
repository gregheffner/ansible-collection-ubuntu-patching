#!/bin/bash

# Post-reboot maintenance completion checker
# This script should be run after docker host reboots to verify maintenance completion

LOGFILE="/mnt/QNAP/backuplogs/ansible-automation.log"
POST_REBOOT_LOGFILE="/home/ansible/post-reboot-check.log"

echo "=== POST-REBOOT MAINTENANCE VERIFICATION ===" | tee -a "$POST_REBOOT_LOGFILE"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$POST_REBOOT_LOGFILE"
echo "Host: $(hostname)" | tee -a "$POST_REBOOT_LOGFILE"
echo "" | tee -a "$POST_REBOOT_LOGFILE"

# Check if system was recently rebooted (within last 30 minutes)
BOOT_TIME=$(uptime -s)
CURRENT_TIME=$(date '+%s')
BOOT_TIMESTAMP=$(date -d "$BOOT_TIME" '+%s')
TIME_DIFF=$((CURRENT_TIME - BOOT_TIMESTAMP))

if [ $TIME_DIFF -lt 1800 ]; then  # Less than 30 minutes
    echo "✅ Recent reboot detected (uptime: $(uptime -p))" | tee -a "$POST_REBOOT_LOGFILE"
    REBOOT_STATUS="RECENT_REBOOT"
else
    echo "ℹ️  No recent reboot detected (uptime: $(uptime -p))" | tee -a "$POST_REBOOT_LOGFILE"
    REBOOT_STATUS="NO_RECENT_REBOOT"
fi

# Check system health after reboot
echo "" | tee -a "$POST_REBOOT_LOGFILE"
echo "=== SYSTEM HEALTH CHECK ===" | tee -a "$POST_REBOOT_LOGFILE"

# Docker service status
if systemctl is-active --quiet docker; then
    echo "✅ Docker service: Active" | tee -a "$POST_REBOOT_LOGFILE"
    DOCKER_STATUS="ACTIVE"
    
    # Check running containers
    RUNNING_CONTAINERS=$(docker ps --format "table {{.Names}}\t{{.Status}}" 2>/dev/null | grep -v "NAMES" | wc -l)
    echo "📊 Running containers: $RUNNING_CONTAINERS" | tee -a "$POST_REBOOT_LOGFILE"
else
    echo "❌ Docker service: Inactive" | tee -a "$POST_REBOOT_LOGFILE"
    DOCKER_STATUS="INACTIVE"
fi

# GitHub Actions runner status
if systemctl is-active --quiet actions.runner; then
    echo "✅ GitHub Actions runner: Active" | tee -a "$POST_REBOOT_LOGFILE"
    RUNNER_STATUS="ACTIVE"
else
    echo "❌ GitHub Actions runner: Inactive" | tee -a "$POST_REBOOT_LOGFILE"
    RUNNER_STATUS="INACTIVE"
fi

# System load
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//')
echo "📈 Load average: $LOAD_AVG" | tee -a "$POST_REBOOT_LOGFILE"

# Memory usage
MEM_USAGE=$(free | grep Mem | awk '{printf "%.1f%%", $3/$2 * 100.0}')
echo "🧠 Memory usage: $MEM_USAGE" | tee -a "$POST_REBOOT_LOGFILE"

# Disk usage of critical paths
echo "💾 Disk usage:" | tee -a "$POST_REBOOT_LOGFILE"
df -h / /tmp /mnt/QNAP 2>/dev/null | grep -E "(/$|/tmp$|/mnt/QNAP$)" | while read line; do
    echo "   $line" | tee -a "$POST_REBOOT_LOGFILE"
done

# Log the completion status to main automation log
echo "" | tee -a "$POST_REBOOT_LOGFILE"
echo "=== LOGGING TO MAIN AUTOMATION LOG ===" | tee -a "$POST_REBOOT_LOGFILE"

cat >> "$LOGFILE" << EOF
[$(date '+%Y-%m-%d %H:%M:%S')] === POST-REBOOT STATUS CHECK ===
Host: $(hostname)
Reboot Status: $REBOOT_STATUS
Uptime: $(uptime -p)
Docker: $DOCKER_STATUS
Runner: $RUNNER_STATUS
Load: $LOAD_AVG
Memory: $MEM_USAGE
Check completed successfully
================================================================
EOF

echo "✅ Status logged to: $LOGFILE" | tee -a "$POST_REBOOT_LOGFILE"
echo "✅ Detailed log available: $POST_REBOOT_LOGFILE" | tee -a "$POST_REBOOT_LOGFILE"

echo ""
echo "=== SUMMARY ===" | tee -a "$POST_REBOOT_LOGFILE"
if [ "$DOCKER_STATUS" == "ACTIVE" ] && [ "$RUNNER_STATUS" == "ACTIVE" ]; then
    echo "🎉 Post-reboot verification PASSED - All critical services running" | tee -a "$POST_REBOOT_LOGFILE"
    exit 0
else
    echo "⚠️  Post-reboot verification ISSUES - Some services need attention" | tee -a "$POST_REBOOT_LOGFILE"
    exit 1
fi