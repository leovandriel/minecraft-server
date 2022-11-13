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

## Install SSH

Locally, copy SSH key, replacing `X`:

```
ssh-copy-id 192.168.X.X
```

SSH into server using password, replacing `X`:

```
ssh 192.168.X.X
```

Update the SSH config according to [`sshd_config`](sshd_config), replacing `X`:

```
sudo nano /etc/ssh/sshd_config
```

Restart SSH service and disconnect:

```
sudo systemctl restart sshd
systemctl status sshd
exit
```

SSH into server using public key, replacing `X`:

```
ssh -p X 192.168.X.X
```

Going forward, all instructions will be over SSH.

## Setup Firewall

Set up UFW firewall, replacing `X` with SSH and server port:

```
sudo apt install ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow X
sudo ufw allow X
sudo ufw enable
sudo ufw status
```

## Auto Update OS

Set up Unattended Upgrades:

```
sudo apt install unattended-upgrades
```

Update the config according to [`50unattended-upgrades`](50unattended-upgrades):

```
sudo nano /etc/apt/apt.conf.d/50unattended-upgrades
```

Create auto-upgrade according to [`20auto-upgrades`](20auto-upgrades):

```
sudo nano /etc/apt/apt.conf.d/20auto-upgrades
```

## Download Paper

Create directories in `/opt` and add `minecraft` user:

```
sudo mkdir /opt/minecraft /opt/minecraft/server /opt/minecraft/logs /opt/minecraft/script /opt/minecraft/backup
sudo chown minecraft.minecraft /opt/minecraft/server /opt/minecraft/logs
sudo groupadd --system minecraft
sudo useradd --system --gid minecraft --shell /usr/sbin/nologin --home-dir /opt/minecraft minecraft
```

Create download script according to [`download-paper.sh`](download-paper.sh):

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

Create service according to [`minecraft.service`](minecraft.service):

```
sudo nano /etc/systemd/system/minecraft.service
```

Run the service once and accept the EULA:

```
sudo systemctl start minecraft
sudo nano /opt/minecraft/server/eula.txt
```

Update server settings according to [`server.properties`](server.properties), replacing `X`:

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

Create hourly update script according to [`backup-hourly.sh`](backup-hourly.sh):

```
sudo nano /opt/minecraft/script/backup-hourly.sh
```

Create daily update script according to [`backup-daily.sh`](backup-daily.sh):

```
sudo nano /opt/minecraft/script/backup-daily.sh
```

Make scripts executable:

```
sudo chmod +x /opt/minecraft/script/backup-hourly.sh
sudo chmod +x /opt/minecraft/script/backup-daily.sh
```

Update `crontab` according to [`crontab`](crontab):

```
sudo crontab -e
```

Test run hourly backup:

```
sudo /opt/minecraft/script/backup-hourly.sh
tail /opt/minecraft/logs/backup-hourly.log
```

## Auto Update Server

Create update script according to [`update-server.sh`](update-server.sh):

```
sudo nano /opt/minecraft/script/update-server.sh
```

Make script executable:

```
sudo chmod +x /opt/minecraft/script/update-server.sh
```

Update `crontab` according to [`crontab`](crontab):

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

Update server port, back to default (25565), see [`server.properties-tunnel`](server.properties-tunnel):

```
sudo nano /opt/minecraft/server/server.properties
sudo systemctl restart minecraft
```

Locally, set up a tunnel, replacing `X`:

```
ssh -NL 25565:localhost:25565 -p X 192.168.X.X
```

You can now connect to the server using the address `localhost`.

To allow others to connect, create a new user:

```
sudo groupadd --system mctunnel
sudo useradd --system --gid mctunnel --shell /usr/sbin/nologin mctunnel
sudo passwd mctunnel
```

Update the SSH config according to [`sshd_config-tunnel`](sshd_config-tunnel), replacing `X`:

```
sudo nano /etc/ssh/sshd_config
sudo systemctl restart ssh
```

Others can now set up a tunnel, replacing `X`:

```
ssh -NL 25565:localhost:25565 -p X mctunnel@192.168.X.X
```

## License

MIT
