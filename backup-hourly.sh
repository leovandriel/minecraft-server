#!/bin/bash
set -e
exec &>> /opt/minecraft/logs/backup-hourly.log
echo "$(date -Is): archiving"
tar -cpf "/opt/minecraft/backup/hourly-$(date -Is).tar" /opt/minecraft/server
echo "$(date -Is): cleanup"
find /opt/minecraft/backup/hourly* -mtime +1 -exec rm {} \;
echo "$(date -Is): backup complete"
