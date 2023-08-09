#!/bin/bash
set -e
exec &>> /opt/minecraft/logs/backup-daily.log
echo "$(date -Is): archiving"
tar -czpf "/opt/minecraft/backup/daily-$(date -Is).tar.gz" /opt/minecraft/server
echo "$(date -Is): cleanup"
find /opt/minecraft/backup/daily* -mtime +30 -exec rm {} \;
echo "$(date -Is): backup complete"
