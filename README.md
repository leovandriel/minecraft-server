# Minecraft Server

Set up a small, automatically maintained Paper server for Java Edition on a
Debian home server.

This setup is intentionally simple:

- Debian stable
- Paper, using the latest final Minecraft release with a stable or beta build
- Java version recommended by Paper
- Java Edition clients on the local network
- Offline authentication; no Microsoft account required
- systemd and `screen`
- Hourly and daily local snapshots
- Weekly automatic Paper updates
- Debian unattended upgrades

The server files and worlds live in `/srv/minecraft`. Backups live in
`/var/backups/minecraft`.

Start with the base system described in
[debian-server](https://github.com/leovandriel/debian-server).

## Install Java and tools

Paper currently requires Java 25. Paper recommends Amazon Corretto on Debian.
Check [Paper's Java installation guide](https://docs.papermc.io/misc/java-install/)
in case the required Java version has changed.

```shell
sudo apt update
sudo apt install ca-certificates curl gnupg jq screen

curl --fail --silent --show-error https://apt.corretto.aws/corretto.key |
  sudo gpg --yes --dearmor -o /usr/share/keyrings/corretto-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/corretto-keyring.gpg] https://apt.corretto.aws stable main" |
  sudo tee /etc/apt/sources.list.d/corretto.list

sudo apt update
sudo apt install java-25-amazon-corretto-jdk libxi6 libxtst6 libxrender1
java -version
```

## Create the service account and directories

Create a system account that cannot log in interactively:

```shell
sudo adduser --system --group --home /srv/minecraft --no-create-home minecraft
```

If an older `minecraft` account already exists, update its home instead:

```shell
sudo usermod --home /srv/minecraft minecraft
```

Create the server and backup directories:

```shell
sudo install -d -o minecraft -g minecraft -m 0750 /srv/minecraft
sudo install -d -m 0750 /var/backups/minecraft
```

## Install the maintenance scripts

From this repository, install the scripts:

```shell
sudo install -m 0755 bin/download-paper /usr/local/sbin/download-paper
sudo install -m 0755 bin/snapshot-hourly /usr/local/sbin/snapshot-hourly
sudo install -m 0755 bin/snapshot-daily /usr/local/sbin/snapshot-daily
sudo install -m 0755 bin/update-server /usr/local/sbin/update-server
```

Create and rotate the maintenance log:

```shell
sudo touch /var/log/minecraft-maintenance.log
sudo chmod 0644 /var/log/minecraft-maintenance.log
sudo install -m 0644 etc/minecraft-maintenance.logrotate \
  /etc/logrotate.d/minecraft-maintenance
```

## Download Paper

The downloader finds the newest final Minecraft release for which Paper
publishes a stable or beta build. It downloads to a temporary file, verifies
Paper's SHA-256 checksum, and stages the result as `paper.jar.new`.

```shell
sudo /usr/local/sbin/download-paper
sudo mv /srv/minecraft/paper.jar.new /srv/minecraft/paper.jar
sudo chown minecraft:minecraft /srv/minecraft/paper.jar
tail /var/log/minecraft-maintenance.log
```

Stable Paper builds are preferred. A beta is accepted when the latest final
Minecraft release does not have a stable Paper build yet. Alpha builds and
Minecraft prereleases or release candidates are ignored.

## Install the systemd service

Install and load the service:

```shell
sudo install -m 0644 etc/minecraft.service \
  /etc/systemd/system/minecraft.service
sudo systemctl daemon-reload
```

Start Paper once so it creates its initial configuration:

```shell
sudo systemctl start minecraft
systemctl status minecraft --no-pager
```

Paper stops until its EULA is accepted. Read the EULA, then edit:

```shell
sudo -u minecraft nano /srv/minecraft/eula.txt
```

Set `eula=true` only if you agree.

Install the example server properties and replace `X` in the server name:

```shell
sudo install -o minecraft -g minecraft -m 0644 \
  opt/server.properties /srv/minecraft/server.properties
sudo -u minecraft nano /srv/minecraft/server.properties
```

This configuration uses `online-mode=false`, allowing Java clients to connect
without Microsoft authentication. On a trusted LAN this is convenient, but
usernames are not securely verified. This LAN-only setup leaves the allowlist
off so family and guests can join without administration. Do not grant operator
privileges to a player name: someone using the same name would receive those
privileges. Use the server console for administration instead.

The example accepts up to five players, sends a 24-chunk view distance, keeps
the 10-chunk simulation distance, disables spawn protection, and pauses world
ticks after the server has been empty for 60 seconds. Gameplay rules otherwise
retain their vanilla defaults.

Enable and start the server:

```shell
sudo systemctl enable --now minecraft
systemctl status minecraft --no-pager
sudo tail -f /srv/minecraft/logs/latest.log
```

The service uses a 4 GiB heap. Adjust `-Xms4G -Xmx4G` in
`/etc/systemd/system/minecraft.service` if the machine has substantially more
or less memory, then run `sudo systemctl daemon-reload` and restart Minecraft.
The command intentionally relies on modern Java's garbage-collector defaults,
as recommended by [Paper's start-script guide](https://docs.papermc.io/misc/tools/start-script-gen/).

## Use the server console

Attach to the console:

```shell
sudo -u minecraft screen -r minecraft
```

Detach without stopping the server by pressing `Ctrl+A`, then `D`.

Useful commands include:

```text
list
say Server maintenance soon
whitelist on
whitelist add PLAYER_NAME
save-all flush
stop
```

Do not use `/reload`; restart the service when configuration or plugins change.
The whitelist commands are optional if access is already restricted to a
trusted LAN.

## Configure the firewall

Allow Java Edition only from the local network. Replace the subnet if needed:

```shell
sudo ufw allow proto tcp from 192.168.7.0/24 to any port 25565
sudo ufw status
```

Do not forward port 25565 on the router if the server should remain LAN-only.
Connect a Java Edition client running the same Minecraft version to the server's
LAN hostname or address; port 25565 is the default and does not need to be typed.

## Schedule backups and updates

Edit root's crontab:

```shell
sudo crontab -e
```

Add the contents of [`etc/crontab`](etc/crontab):

```cron
30 * * * * /usr/local/sbin/snapshot-hourly
15 3 * * * /usr/local/sbin/snapshot-daily
0 5 * * 0 /usr/local/sbin/update-server
```

The schedule:

- Keeps hourly snapshots for one day.
- Keeps compressed daily snapshots for 30 days.
- Checks for the latest eligible Minecraft/Paper release every Sunday at 05:00
  and installs it when it has changed.
- Keeps the previous Paper JAR as `/srv/minecraft/paper.jar.previous`.

The snapshot scripts briefly pause world saving, flush changes to disk, archive
the server, and resume saving. The weekly updater downloads and verifies Paper
before stopping Minecraft, then creates a stopped-server snapshot before
installing the staged JAR.

Test each task:

```shell
sudo /usr/local/sbin/snapshot-hourly
sudo /usr/local/sbin/snapshot-daily
sudo /usr/local/sbin/update-server
tail -100 /var/log/minecraft-maintenance.log
sudo ls -lh /var/backups/minecraft
```

Paper discourages unattended production updates and beta builds can contain
regressions. This family server deliberately favors staying current, uses no
additional plugins, and accepts that tradeoff. The pre-update snapshot is the
recovery point if a new Minecraft release changes the world format. If a future
Paper release requires a newer Java major version, update Java manually before
that Paper update can start successfully.

## Debian updates

Use `unattended-upgrades` as described by the base server setup. A local override
can enable cleanup and schedule reboots:

```shell
sudo nano /etc/apt/apt.conf.d/99unattended-upgrades-local
```

```text
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "04:10";
```

Minecraft maintenance runs at 05:00 so it does not overlap the OS reboot window.

## Restore a snapshot

Stop Minecraft and preserve the current directory before restoring:

```shell
sudo systemctl stop minecraft
sudo mv /srv/minecraft /srv/minecraft.before-restore
```

Restore a daily snapshot, replacing `X`:

```shell
sudo tar -C / -xzpf /var/backups/minecraft/daily-X.tar.gz
sudo chown -R minecraft:minecraft /srv/minecraft
sudo systemctl start minecraft
```

For an hourly `.tar` snapshot, omit `z`:

```shell
sudo tar -C / -xpf /var/backups/minecraft/hourly-X.tar
```

Verify the world before deleting `/srv/minecraft.before-restore`.

## Optional SSH tunnel

The server is intended for LAN use. If remote access is needed later, an SSH
tunnel avoids exposing Minecraft directly to the internet.

Create a restricted account and authorized-key file:

```shell
sudo adduser --system --group --no-create-home mctunnel
sudo install -d -m 0755 /etc/ssh/authorized-keys
sudo install -o mctunnel -g mctunnel -m 0600 /dev/null \
  /etc/ssh/authorized-keys/mctunnel
sudo nano /etc/ssh/authorized-keys/mctunnel
```

Install [`etc/sshd_config-tunnel`](etc/sshd_config-tunnel) as an SSH drop-in,
add `mctunnel` to any existing `AllowUsers` directive, validate, and reload:

```shell
sudo install -m 0644 etc/sshd_config-tunnel \
  /etc/ssh/sshd_config.d/20-minecraft-tunnel.conf
sudo sshd -t
sudo systemctl reload ssh
```

From a client:

```shell
ssh -NL 25565:localhost:25565 mctunnel@SERVER_ADDRESS
```

Connect Minecraft to `localhost` while the tunnel is running.

## Troubleshooting

```shell
systemctl status minecraft --no-pager
sudo journalctl -u minecraft -n 100 --no-pager
sudo tail -100 /srv/minecraft/logs/latest.log
tail -100 /var/log/minecraft-maintenance.log
sudo -u minecraft screen -ls
sudo ufw status
java -version
```

If a weekly update fails after changing Minecraft versions, stop the service,
restore the corresponding pre-update daily snapshot, and use
`paper.jar.previous` only with world data created by that older release.

## License

MIT
