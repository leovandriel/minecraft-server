#!/bin/bash
set -e
exec &>> /opt/minecraft/logs/download-paper.log
echo "$(date -Is): fetch version"
version="$(wget -q -O- "https://api.papermc.io/v2/projects/paper" | sed -n "s/^.*\"\([0-9.]*\)\"]}$/\1/p")"
echo "$(date -Is): fetch build for $version"
build="$(wget -q -O- "https://api.papermc.io/v2/projects/paper/versions/$version" | sed -n "s/^.*,\([0-9]*\)]}$/\1/p")"
echo "$(date -Is): download binary for $build"
wget -q -O /opt/minecraft/server/paper.jar "https://api.papermc.io/v2/projects/paper/versions/$version/builds/$build/downloads/paper-$version-$build.jar"
echo "$(date -Is): download geyser"
wget -q -O /opt/minecraft/server/plugins/Geyser-Spigot.jar "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot"
echo "$(date -Is): download floodgate"
wget -q -O /opt/minecraft/server/plugins/Floodgate-Spigot.jar "https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot"
echo "$(date -Is): download complete"