Minecraft Server
================

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

## Bootable USB

First step is creating a bootable USB to do a fresh install of Debian. 

- Visit https://www.debian.org/download
- Download the latest "netinst" of the "stable" release. 
- Verify download using the SHA checksum.
- Determine the name of the USB drive, something of the kind `/dev/diskX`
- Copy the image, replacing `X`:

```
sudo dd if=debian-X-X-netinst.iso of=/dev/diskX bs=1024k status=progress
```

## Install Debian

Boot of the USB and follow instructions. Skip installing a desktop environment and install SSH server.

Get the fingerprint of the public key:

```
ssh-keygen -E md5 -lf /etc/ssh/ssh_host_rsa_key.pub
ssh-keygen -E md5 -lf /etc/ssh/ssh_host_ecdsa_key.pub
ssh-keygen -E md5 -lf /etc/ssh/ssh_host_ed25519_key.pub
```

## Install SSH

Locally, verify above fingerprint and copy SSH key:

```
ssh-copy-id 192.168.X.X
```

SSH into server using password`:

```
ssh 192.168.X.X
```

Update the SSH config according to [`sshd_config`](config/sshd_config), replacing `X`:

```
sudo nano /etc/ssh/sshd_config
```

Restart SSH service and disconnect:

```
sudo systemctl restart sshd
systemctl status sshd
exit
```

SSH into server using public key:

```
ssh 192.168.X.X
```

Going forward, all instructions will be over SSH.

## Setup Firewall

Set up UFW firewall, with port 25565 for the Minecraft server:

```
sudo apt install ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 25565
sudo ufw enable
sudo ufw status
```

## Auto Update OS

Set up Unattended Upgrades:

```
sudo apt install unattended-upgrades
```

Update the config according to [`50unattended-upgrades`](config/50unattended-upgrades):

```
sudo nano /etc/apt/apt.conf.d/50unattended-upgrades
```

Create auto-upgrade according to [`20auto-upgrades`](config/20auto-upgrades):

```
sudo nano /etc/apt/apt.conf.d/20auto-upgrades
```

## Download Paper

Add `minecraft` user:

```
sudo groupadd --system minecraft
sudo useradd --system --gid minecraft --shell /usr/sbin/nologin --home-dir /opt/minecraft minecraft
```

Create directories in `/opt`:

```
sudo mkdir /opt/minecraft /opt/minecraft/server /opt/minecraft/logs /opt/minecraft/script /opt/minecraft/backup
sudo chown minecraft.minecraft /opt/minecraft/server /opt/minecraft/logs
```

Create download script according to [`download-paper.sh`](script/download-paper.sh):

```
sudo nano /opt/minecraft/script/download-paper.sh
```

Make script executable and execute:

```
sudo chmod +x /opt/minecraft/script/download-paper.sh
sudo -u minecraft /opt/minecraft/script/download-paper.sh
tail /opt/minecraft/logs/download-paper.log
```

## Create Service

Install screen and openJDK:

```
sudo apt install screen
sudo apt install openjdk-17-jre
```

Create service according to [`minecraft.service`](config/minecraft.service):

```
sudo nano /etc/systemd/system/minecraft.service
```

Run the service once and accept the EULA:

```
sudo systemctl start minecraft
sudo nano /opt/minecraft/server/eula.txt
```

Update server settings according to [`server.properties`](config/server.properties):

```
sudo nano /opt/minecraft/server/server.properties
```

Enable and run the service:

```
sudo systemctl enable minecraft
sudo systemctl start minecraft
systemctl status minecraft
```

Inspect the logs and run commands using:

```
sudo -u minecraft screen -R minecraft
(ctrl+a d)
tail /opt/minecraft/server/logs/latest.log
```

## Auto Backup Server

Create hourly update script according to [`backup-hourly.sh`](script/backup-hourly.sh):

```
sudo nano /opt/minecraft/script/backup-hourly.sh
```

Create daily update script according to [`backup-daily.sh`](script/backup-daily.sh):

```
sudo nano /opt/minecraft/script/backup-daily.sh
```

Make scripts executable:

```
sudo chmod +x /opt/minecraft/script/backup-hourly.sh
sudo chmod +x /opt/minecraft/script/backup-daily.sh
```

Update `crontab` according to [`crontab`](config/crontab):

```
sudo crontab -e
```

Test run hourly backup:

```
sudo /opt/minecraft/script/backup-hourly.sh
tail /opt/minecraft/logs/backup-hourly.log
```

## Auto Update Server

Create update script according to [`update-server.sh`](script/update-server.sh):

```
sudo nano /opt/minecraft/script/update-server.sh
```

Make script executable:

```
sudo chmod +x /opt/minecraft/script/update-server.sh
```

Update `crontab` according to [`crontab`](config/crontab):

```
sudo crontab -e
```

Test run:

```
sudo /opt/minecraft/script/update-server.sh
tail /opt/minecraft/logs/update-server.log
tail /opt/minecraft/logs/backup-daily.log
systemctl status minecraft
```

## Tunneling

If you prefer not to expose the Paper server to the network, use SSH tunneling. 

Remove the port from UFW, replacing `X`:

```
sudo ufw delete allow X
```

Update server port, back to default (25565), see [`server.properties-tunnel`](config/server.properties-tunnel):

```
sudo nano /opt/minecraft/server/server.properties
sudo systemctl restart minecraft
```

Locally, set up a tunnel:

```
ssh -NL 25565:localhost:25565 192.168.X.X
```

You can now connect to the server using the address `localhost`.

To allow others to connect, create a new system user:

```
sudo groupadd --system mctunnel
sudo useradd --system --gid mctunnel --shell /usr/sbin/nologin mctunnel
```

To allow public key logins, append the public key to authorized keys:

```
sudo mkdir /etc/ssh/authorized-keys
sudo touch /etc/ssh/authorized-keys/mctunnel
sudo chown mctunnel.mctunnel /etc/ssh/authorized-keys/mctunnel
sudo nano /etc/ssh/authorized-keys/mctunnel
```

Client-side, an SSH key can be generated and installed:

```
ssh-keygen -t ed25519
cat ~/.ssh/id_ed25519.pub
```

Update the SSH config according to [`sshd_config-tunnel`](config/sshd_config-tunnel), replacing `X`:

```
sudo nano /etc/ssh/sshd_config
sudo systemctl restart ssh
```

Others can now set up a tunnel:

```
ssh -NL 25565:localhost:25565 mctunnel@192.168.X.X
```

Optionally, to allow password logins, set a password and update the SSH config according to [`sshd_config-passwd`](config/sshd_config-passwd):

```
sudo passwd mctunnel
sudo nano /etc/ssh/sshd_config
```

## License

MIT
