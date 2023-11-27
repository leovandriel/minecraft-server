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
- Auto local snapshot
- Encrypted drive with USB unlock
- Remote lookup of dynamic IP
- Logs

## Bootable USB

First step is creating a bootable USB to do a fresh install of Debian.

- Visit [https://www.debian.org/download](https://www.debian.org/download)
- Download the latest "netinst" of the "stable" release.
- Verify download using the SHA checksum.
- Determine the name of the USB drive, something of the kind `/dev/diskX`
- Copy the image, replacing `X`:

```shell
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

```shell
ssh-keygen -E md5 -lf /etc/ssh/ssh_host_rsa_key.pub
ssh-keygen -E md5 -lf /etc/ssh/ssh_host_ecdsa_key.pub
ssh-keygen -E md5 -lf /etc/ssh/ssh_host_ed25519_key.pub
hostname -I
```

## Client SSH

On client, update your ssh config according to [`ssh/config`](ssh/config),
replacing `X` with hostname and IP address:

```shell
nano ~/.ssh/config
```

Copy SSH key, replacing `X` with hostname:

```shell
ssh-copy-id X
```

SSH into server using private key, replacing `X` with hostname:

```shell
ssh X
```

*From here on, all commands are to be run on the server over SSH.*

## Server SSH

Update the SSH config according to [`sshd_config`](etc/sshd_config), replacing
`X`:

```shell
sudo nano /etc/ssh/sshd_config
```

Restart SSH service:

```shell
sudo systemctl restart sshd
systemctl status sshd
```

## Firewall

Set up UFW firewall, with ssh and Minecraft server ports (25565 for Java
Edition, 19132:19133 for Bedrock):

```shell
sudo apt update && sudo apt upgrade
sudo apt install ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow proto tcp from 192.168.0.0/16 to any port 25565
sudo ufw allow proto tcp from 192.168.0.0/16 to any port 19132:19133
sudo ufw allow proto udp from 192.168.0.0/16 to any port 19132:19133
sudo ufw enable
sudo ufw status
```

Additionally, if you want to make the server accessible outside of your network:

```shell
sudo ufw allow 25565/tcp
sudo ufw allow 19132:19133/tcp
sudo ufw allow 19132:19133/udp
```

## USB Passphrase

Have you server boot without requiring you to enter disk encryption passphrase.

Insert USB stick. Find USB and encrypted drive:

```shell
lsblk
```

Create a random passphrase, write it to USB, and add it to LUKS, replacing `X`
according to the above listing:

```shell
head -c 256 /dev/urandom > passphrase
sudo dd if=passphrase of=/dev/sdX bs=1
sudo cryptsetup luksAddKey /dev/sdaX passphrase
rm passphrase
```

Find the `id` of the USB drive:

```shell
ls -l /dev/disk/by-id
```

In `crypttab`, replace `none` with the ID and append
`,keyscript=/usr/local/bin/passphrase-from-usb`.

```shell
sudo nano /etc/crypttab
```

Create the script file according to
[`passphrase-from-usb`](bin/passphrase-from-usb) and make it executable:

```shell
sudo nano /usr/local/bin/passphrase-from-usb
sudo chmod 755 /usr/local/bin/passphrase-from-usb
```

Update initramfs:

```shell
sudo update-initramfs -u
```

Restart the system to confirm change:

```shell
sudo shutdown -r now
```

## Auto Update OS

Keep your software up to date, automatically.

Set up Unattended Upgrades:

```shell
sudo apt install unattended-upgrades
```

Update the config according to
[`50unattended-upgrades`](etc/50unattended-upgrades):

```shell
sudo nano /etc/apt/apt.conf.d/50unattended-upgrades
```

Create auto-upgrade according to [`20auto-upgrades`](etc/20auto-upgrades):

```shell
sudo nano /etc/apt/apt.conf.d/20auto-upgrades
```

## Download Paper

Download Paper and plugins, automatically.

Add `minecraft` user:

```shell
sudo groupadd --system minecraft
sudo useradd --system --gid minecraft --shell /usr/sbin/nologin --home-dir /opt/minecraft minecraft
```

Create home folder in `/opt`:

```shell
sudo mkdir -p /opt/minecraft/server/plugins
sudo chown -R minecraft:minecraft /opt/minecraft
ls -la /opt/minecraft
```

Create log file in `/var/log`:

```shell
sudo touch /var/log/minecraft.log
sudo chown minecraft:minecraft /var/log/minecraft.log
ls -la /var/log
```

Create download script according to [`download-paper`](bin/download-paper):

```shell
sudo nano /usr/local/bin/download-paper
```

Make script executable and execute:

```shell
sudo chmod +x /usr/local/bin/download-paper
sudo -u minecraft /usr/local/bin/download-paper
tail /var/log/minecraft.log
```

## Paper Service

Set up the Paper server, as a service.

Install screen and openJDK:

```shell
sudo apt install screen openjdk-17-jre
```

Create service according to [`minecraft.service`](etc/minecraft.service):

```shell
sudo nano /etc/systemd/system/minecraft.service
```

Start the service:

```shell
sudo systemctl start minecraft
systemctl status minecraft
```

Once the service has stopped, accept the EULA (`eula=true`):

```shell
sudo -u minecraft nano /opt/minecraft/server/eula.txt
```

Update server settings according to
[`server.properties`](opt/server.properties), replacing `X`:

```shell
sudo -u minecraft nano /opt/minecraft/server/server.properties
```

Optionally, if server.properties was not created, you can debug by running:

```shell
cd /opt/minecraft/server
sudo -u minecraft /usr/bin/java -jar paper.jar --nogui
```

Make sure to exit (Ctrl+C) before continuing.

Load plugins and update Geyser settings according to
[`config.yaml`](opt/config.yaml), replacing `X`:

```shell
sudo systemctl start minecraft
sudo -u minecraft nano /opt/minecraft/server/plugins/Geyser-Spigot/config.yml
```

Enable and run the service:

```shell
sudo systemctl enable minecraft
sudo systemctl restart minecraft
systemctl status minecraft
```

To view the server log:

```shell
tail /opt/minecraft/server/logs/latest.log
```

To run commands (`Ctrl+a d` to exit):

```shell
sudo -u minecraft screen -R minecraft
```

## Auto Snapshot Server

Make sure to keep a shapshot of the server folder in case the server gets
corrupted or someone destroys your precious creation.

Create snapshot folder in `/opt`:

```shell
sudo mkdir -p /opt/snapshot
```

Create hourly update script according to
[`snapshot-hourly`](bin/snapshot-hourly):

```shell
sudo nano /usr/local/bin/snapshot-hourly
```

Create daily update script according to [`snapshot-daily`](bin/snapshot-daily):

```shell
sudo nano /usr/local/bin/snapshot-daily
```

Make scripts executable:

```shell
sudo chmod +x /usr/local/bin/snapshot-hourly
sudo chmod +x /usr/local/bin/snapshot-daily
```

Update `crontab` according to [`crontab`](etc/crontab):

```shell
sudo crontab -e
```

Test run hourly snapshot:

```shell
sudo /usr/local/bin/snapshot-hourly
tail /var/log/minecraft.log
```

## Auto Update Server

Keep your software up to date, automatically.

Create update script according to [`update-server`](bin/update-server):

```shell
sudo nano /usr/local/bin/update-server
```

Make script executable:

```shell
sudo chmod +x /usr/local/bin/update-server
```

Update `crontab` according to [`crontab`](etc/crontab):

```shell
sudo crontab -e
```

Test run:

```shell
sudo /usr/local/bin/update-server
tail /var/log/minecraft.log
systemctl status minecraft
```

## Tunneling

If you prefer not to expose the Paper server to the network, use SSH tunneling.

Locally, set up a tunnel:

```shell
ssh -NL 25565:localhost:25565 192.168.X.X
```

You can now connect to the server using the address `localhost`.

To allow others to connect, create a new system user:

```shell
sudo groupadd --system mctunnel
sudo useradd --system --gid mctunnel --shell /usr/sbin/nologin mctunnel
```

To allow public key logins, append the public key to authorized keys:

```shell
sudo mkdir /etc/ssh/authorized-keys
sudo touch /etc/ssh/authorized-keys/mctunnel
sudo chown mctunnel:mctunnel /etc/ssh/authorized-keys/mctunnel
sudo nano /etc/ssh/authorized-keys/mctunnel
```

Client-side, an SSH key can be generated and installed:

```shell
ssh-keygen -t ed25519
cat ~/.ssh/id_ed25519.pub
```

Update the SSH config according to
[`sshd_config-tunnel`](etc/sshd_config-tunnel), replacing `X`:

```shell
sudo nano /etc/ssh/sshd_config
sudo systemctl restart ssh
```

Others can now set up a tunnel:

```shell
ssh -NL 25565:localhost:25565 mctunnel@192.168.X.X
```

Optionally, to allow password logins, set a password and update the SSH config
according to [`sshd_config-passwd`](etc/sshd_config-passwd):

```shell
sudo passwd mctunnel
sudo nano /etc/ssh/sshd_config
```

## Auto Close Port

If you use your minecraft server only intermittently, it might be best to keep
minecraft ports closed by default. The following will auto-close the port at
night.

Create close port script according to [`close-port`](bin/close-port):

```shell
sudo nano /usr/local/bin/close-port
```

Make script executable:

```shell
sudo chmod +x /usr/local/bin/close-port
```

Update `crontab` according to [`crontab`](etc/crontab):

```shell
sudo crontab -e
```

Test script:

```shell
sudo /usr/local/bin/close-port
tail /var/log/minecraft.log
sudo ufw status
```

Open Minecraft port again:

```shell
sudo ufw allow 25565/tcp 
sudo ufw allow 19132:19133/tcp
sudo ufw allow 19132:19133/udp
```

## Dynamic IP

If you are running your server from home you might have a dynamic IP address and
get locked out.

Create track ip script according to [`track-ip`](bin/track-ip), replacing `X`
with a unique url-safe base64 key between 11 and 22 characters:

```shell
sudo nano /usr/local/bin/track-ip
```

Make script executable:

```shell
sudo chmod +x /usr/local/bin/track-ip
```

Update `crontab` according to [`crontab-minecraft`](etc/crontab-minecraft):

```shell
sudo -u minecraft crontab -e
```

Test script:

```shell
sudo -u minecraft /usr/local/bin/track-ip
tail /var/log/minecraft.log
```

Now, you can [https://ip.leovandriel.com/X](https://ip.leovandriel.com/X),
replacing `X`.

## Restore Snapshot

In case of a calamity, or to test the snapshot.

*NB: the following will **overwrite** your existing minecraft server folder.
Make sure you have a backup before continuing.*

First stop the server:

```shell
sudo systemctl stop minecraft
```

Extract the tarball, replacing `X`:

```shell
sudo tar -C / -xvf /opt/snapshot/X.tar
sudo tar -C / -xzvf /opt/snapshot/X.tar.gz
```

Restart the server:

```shell
sudo systemctl start minecraft
systemctl status minecraft
```

Alternatively, if you have an older backup, and you only want to restore certain
files, e.g. the world map, you can first extract to `/tmp`:

```shell
sudo tar -C /tmp -xvf /opt/snapshot/X.tar
sudo tar -C /tmp -xzvf /opt/snapshot/X.tar.gz
sudo mv /tmp/opt/minecraft/server/X /opt/minecraft/server
sudo rm -rf /tmp/opt/minecraft
```

## CLI Client

Don't want to run the slow and bulky Minecraft Launcher?

On your client, install [portablemc](https://github.com/mindstorm38/portablemc)
and launch directly into server, replacing `X`:

```shell
pip install --user portablemc
portablemc start --username X --server 192.168.X.X
```

Or if you prefer to keep it completely contained with one folder:

```shell
mkdir ~/minecraft
cd ~/minecraft
python3 -m venv venv
source ./venv/bin/activate
pip install --upgrade pip
pip install portablemc
deactivate
touch launch
chmod +x launch
nano launch
```

And paste the following, replacing `X`:

```bash
#!/bin/bash
set -e
source ./venv/bin/activate
portablemc --main-dir ./main --work-dir ./work start --username X --server 192.168.X.X
```

And launch right into the server with `./launch`.

## License

MIT
