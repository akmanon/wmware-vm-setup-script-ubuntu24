#!/bin/bash

echo ">>> Host keygen Add service..."

sudo tee /etc/systemd/system/regen-ssh-keys.service > /dev/null <<EOF
[Unit]
Description=Regenerate SSH Host Keys
ConditionPathExists=!/etc/ssh/ssh_host_rsa_key
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/ssh-keygen -A
ExecStartPost=/bin/systemctl disable regen-ssh-keys.service

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable regen-ssh-keys.service


echo ">>> Stopping logging services..."
systemctl stop rsyslog
systemctl stop systemd-journald

echo ">>> Cleaning machine ID..."
rm -f /etc/machine-id /var/lib/dbus/machine-id
systemd-machine-id-setup



echo ">>> Removing SSH host keys..."
rm -f /etc/ssh/ssh_host_*

echo ">>> Cleaning cloud-init (if used)..."
cloud-init clean --logs

echo ">>> Cleaning user history..."
unset HISTFILE
rm -f /root/.bash_history
rm -f /home/*/.bash_history

echo ">>> Cleaning logs..."
find /var/log -type f -exec truncate -s 0 {} \;

echo ">>> Removing temporary files..."
rm -rf /tmp/*
rm -rf /var/tmp/*


echo ">>> Cleaning package cache..."
apt clean
apt autoremove -y

echo ">>> Zeroing free space to shrink disk image..."
dd if=/dev/zero of=/EMPTY bs=1M || true
rm -f /EMPTY

echo ">>> Syncing disks..."
sync

echo ">>> VM is ready for cloning."
