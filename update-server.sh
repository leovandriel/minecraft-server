#!/bin/bash
set -e
exec &>> /opt/minecraft/logs/update-server.log
echo "$(date -Is): stop"
systemctl stop minecraft
echo "$(date -Is): backup"
sudo /opt/minecraft/script/backup-daily.sh
echo "$(date -Is): download"
sudo -u minecraft /opt/minecraft/script/download-paper.sh
echo "$(date -Is): start"
systemctl start minecraft
echo "$(date -Is): update complete"
