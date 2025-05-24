#!/bin/bash

if [ $# -ne 3 ]; then
  echo "Usage: $0 <Static_ip> <gateway> <hostname>"
  exit 1
fi

# === CONFIGURE THESE ===
USERNAME="app-user"
SSH_PUB_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMXf92MOYeO1GKCAYOiP7BivVvkJQGKW+IhahD7nmFFe"
STATIC_IP=$1
GATEWAY=$2
NEW_HOSTNAME=$3
DNS="8.8.8.8"
INTERFACE=$(ip route | grep default | awk '{print $5}') # usually eth0 or ens33

echo ">>> Setting hostname..."
hostnamectl set-hostname "$NEW_HOSTNAME"
echo "127.0.1.1 $NEW_HOSTNAME" >> /etc/hosts

echo ">>> Setting timezone to IST (Asia/Kolkata)..."
timedatectl set-timezone Asia/Kolkata

# === 1. Create user and setup passwordless sudo ===
if ! id "$USERNAME" &>/dev/null; then
    adduser --disabled-password --gecos "" $USERNAME
fi

usermod -aG sudo $USERNAME
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME
chmod 440 /etc/sudoers.d/$USERNAME

# === 2. Set up SSH key ===
mkdir -p /home/$USERNAME/.ssh
echo "$SSH_PUB_KEY" > /home/$USERNAME/.ssh/authorized_keys
chmod 600 /home/$USERNAME/.ssh/authorized_keys
chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh

# === 3. Regenerate machine ID ===
rm -f /etc/machine-id /var/lib/dbus/machine-id
systemd-machine-id-setup

echo ">>> Removing existing Netplan configs..."
rm -f /etc/netplan/*.yaml


# === 4. Set static IP ===
cat <<EOF > /etc/netplan/01-netcfg.yaml
network:
  version: 2
  ethernets:
    $INTERFACE:
      dhcp4: no
      addresses: [$STATIC_IP/24]
      gateway4: $GATEWAY
      nameservers:
          addresses: [$DNS]
EOF

netplan apply

echo ">>> Disabling Swap"
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab # Persist across reboots
echo "Setup complete. Reboot recommended."