# Minecraft Server

*Setting up a Minecraft server from scratch.*

Features:

- OS: Debian stable
- Server: Paper
- SSH: OpenSSH
- Firewall: UFW
- Java: OpenJDK JRE
- Auto update OS
- Auto update server
- Auto local backup
- Logs
- Encrypted drive with USB unlock

## Bootable USB

First step is creating a bootable USB to do a fresh install of Debian.

- Visit [https://www.debian.org/download](https://www.debian.org/download)
- Download the latest "netinst" of the "stable" release.
- Verify download using the SHA checksum.
- Determine the name of the USB drive, something of the kind `/dev/diskX`
- Copy the image, replacing `X`:

```bash
sudo dd if=debian-X-X-netinst.iso of=/dev/diskX bs=1024k status=progress
```

## Installation

Boot of the USB and follow instructions. Do:

- Not create a root user.
- Use LVM with encrypted drive.
- Not install a desktop environment.
- Install SSH server.

## Inspect Server

On server, get the fingerprint of the public key and the IP address:

```bash
ssh-keygen -E md5 -lf /etc/ssh/ssh_host_rsa_key.pub
ssh-keygen -E md5 -lf /etc/ssh/ssh_host_ecdsa_key.pub
ssh-keygen -E md5 -lf /etc/ssh/ssh_host_ed25519_key.pub
hostname -I
```

## Client SSH

On client, update your ssh config according to
[`ssh_config`](config/ssh_config), replacing `X` with hostname and IP address:

```bash
nano ~/.ssh/config
```

Copy SSH key, replacing `X` with hostname:

```bash
ssh-copy-id X
```

SSH into server using private key, replacing `X` with hostname:

```bash
ssh X
```

*From here on, all commands are to be run on the server over SSH.*

## Server SSH

Update the SSH config according to [`sshd_config`](config/sshd_config),
replacing `X`:

```bash
sudo nano /etc/ssh/sshd_config
```

Restart SSH service:

```bash
sudo systemctl restart sshd
systemctl status sshd
```

## Firewall

Set up UFW firewall, with ssh and Minecraft server ports:

```bash
sudo apt update && sudo apt upgrade
sudo apt install ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 25565
sudo ufw allow 19132
sudo ufw enable
sudo ufw status
```

## USB Passphrase

Insert USB stick. Find USB and encrypted drive:

```bash
lsblk
```

Create a random passphrase, write it to USB, and add it to LUKS, replacing `X`
according to the above listing:

```bash
head -c 256 /dev/urandom > passphrase
sudo dd if=passphrase of=/dev/sdX bs=1
sudo cryptsetup luksAddKey /dev/sdaX passphrase
rm passphrase
```

Find the `id` of the USB drive:

```bash
ls -l /dev/disk/by-id
```

In `crypttab`, replace `none` with the ID and append
`,keyscript=/bin/passphrase-from-usb`.

```bash
sudo nano /etc/crypttab
```

Create the script file according to
[`passphrase-from-usb`](config/passphrase-from-usb) and make it executable:

```bash
sudo nano /bin/passphrase-from-usb
sudo chmod 755 /bin/passphrase-from-usb
```

Update initramfs:

```bash
sudo update-initramfs -u
```

Restart the system to confirm change:

```bash
sudo shutdown -r now
```

## Auto Update OS

Set up Unattended Upgrades:

```bash
sudo apt install unattended-upgrades
```

Update the config according to
[`50unattended-upgrades`](config/50unattended-upgrades):

```bash
sudo nano /etc/apt/apt.conf.d/50unattended-upgrades
```

Create auto-upgrade according to [`20auto-upgrades`](config/20auto-upgrades):

```bash
sudo nano /etc/apt/apt.conf.d/20auto-upgrades
```

## Download Paper

Add `minecraft` user:

```bash
sudo groupadd --system minecraft
sudo useradd --system --gid minecraft --shell /usr/sbin/nologin --home-dir /opt/minecraft minecraft
```

Create directories in `/opt`:

```bash
sudo mkdir /opt/minecraft /opt/minecraft/server /opt/minecraft/server/plugins /opt/minecraft/logs /opt/minecraft/script /opt/minecraft/backup
sudo chown minecraft.minecraft /opt/minecraft/server /opt/minecraft/server/plugins /opt/minecraft/logs
```

Create download script according to
[`download-paper.sh`](script/download-paper.sh):

```bash
sudo nano /opt/minecraft/script/download-paper.sh
```

Make script executable and execute:

```bash
sudo chmod +x /opt/minecraft/script/download-paper.sh
sudo -u minecraft /opt/minecraft/script/download-paper.sh
tail /opt/minecraft/logs/download-paper.log
```

## Paper Service

Install screen and openJDK:

```bash
sudo apt install screen
sudo apt install openjdk-17-jre
```

Create service according to [`minecraft.service`](config/minecraft.service):

```bash
sudo nano /etc/systemd/system/minecraft.service
```

Run the service once and accept the EULA:

```bash
sudo systemctl start minecraft
sudo nano /opt/minecraft/server/eula.txt
```

Update server settings according to
[`server.properties`](config/server.properties):

```bash
sudo nano /opt/minecraft/server/server.properties
```

If server.properties was not created, you can debug by running:

```bash
cd /opt/minecraft/server
sudo -u minecraft /usr/bin/java -jar paper.jar --nogui
```

Load plugins and update Geyser settings according to
[`config.yaml`](config/config.yaml):

```bash
sudo systemctl start minecraft
sudo nano /opt/minecraft/server/plugins/Geyser-Spigot/config.yml
```

Enable and run the service:

```bash
sudo systemctl enable minecraft
sudo systemctl restart minecraft
systemctl status minecraft
```

Inspect the logs and run commands using:

```bash
sudo -u minecraft screen -R minecraft
(ctrl+a d)
tail /opt/minecraft/server/logs/latest.log
```

## Auto Backup Server

Create hourly update script according to
[`backup-hourly.sh`](script/backup-hourly.sh):

```bash
sudo nano /opt/minecraft/script/backup-hourly.sh
```

Create daily update script according to
[`backup-daily.sh`](script/backup-daily.sh):

```bash
sudo nano /opt/minecraft/script/backup-daily.sh
```

Make scripts executable:

```bash
sudo chmod +x /opt/minecraft/script/backup-hourly.sh
sudo chmod +x /opt/minecraft/script/backup-daily.sh
```

Update `crontab` according to [`crontab`](config/crontab):

```bash
sudo crontab -e
```

Test run hourly backup:

```bash
sudo /opt/minecraft/script/backup-hourly.sh
tail /opt/minecraft/logs/backup-hourly.log
```

## Auto Update Server

Create update script according to [`update-server.sh`](script/update-server.sh):

```bash
sudo nano /opt/minecraft/script/update-server.sh
```

Make script executable:

```bash
sudo chmod +x /opt/minecraft/script/update-server.sh
```

Update `crontab` according to [`crontab`](config/crontab):

```bash
sudo crontab -e
```

Test run:

```bash
sudo /opt/minecraft/script/update-server.sh
tail /opt/minecraft/logs/update-server.log
tail /opt/minecraft/logs/backup-daily.log
systemctl status minecraft
```

## Tunneling

If you prefer not to expose the Paper server to the network, use SSH tunneling.

Remove the port from UFW, replacing `X`:

```bash
sudo ufw delete allow X
```

Update server port, back to default (25565), see
[`server.properties-tunnel`](config/server.properties-tunnel):

```bash
sudo nano /opt/minecraft/server/server.properties
sudo systemctl restart minecraft
```

Locally, set up a tunnel:

```bash
ssh -NL 25565:localhost:25565 192.168.X.X
```

You can now connect to the server using the address `localhost`.

To allow others to connect, create a new system user:

```bash
sudo groupadd --system mctunnel
sudo useradd --system --gid mctunnel --shell /usr/sbin/nologin mctunnel
```

To allow public key logins, append the public key to authorized keys:

```bash
sudo mkdir /etc/ssh/authorized-keys
sudo touch /etc/ssh/authorized-keys/mctunnel
sudo chown mctunnel.mctunnel /etc/ssh/authorized-keys/mctunnel
sudo nano /etc/ssh/authorized-keys/mctunnel
```

Client-side, an SSH key can be generated and installed:

```bash
ssh-keygen -t ed25519
cat ~/.ssh/id_ed25519.pub
```

Update the SSH config according to
[`sshd_config-tunnel`](config/sshd_config-tunnel), replacing `X`:

```bash
sudo nano /etc/ssh/sshd_config
sudo systemctl restart ssh
```

Others can now set up a tunnel:

```bash
ssh -NL 25565:localhost:25565 mctunnel@192.168.X.X
```

Optionally, to allow password logins, set a password and update the SSH config
according to [`sshd_config-passwd`](config/sshd_config-passwd):

```bash
sudo passwd mctunnel
sudo nano /etc/ssh/sshd_config
```

## License

MIT
