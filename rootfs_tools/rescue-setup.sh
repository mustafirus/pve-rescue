#!/bin/bash
# Non-interactive setup: fetch SSH keys from cmdline, wait for network, generate MOTD
# Runs as systemd oneshot service before user login

# --- Fetch SSH keys from kernel cmdline ---
SSHKEYS_URL=""
for arg in $(cat /proc/cmdline); do
    case "$arg" in
        rescue.sshkeys=*) SSHKEYS_URL="${arg#rescue.sshkeys=}" ;;
    esac
done

if [ -n "$SSHKEYS_URL" ]; then
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    if wget -q --timeout=10 -O /tmp/sshkeys "$SSHKEYS_URL" 2>/dev/null; then
        NKEYS=$(grep -c . /tmp/sshkeys 2>/dev/null || echo 0)
        if [ "$NKEYS" -gt 0 ]; then
            cat /tmp/sshkeys >> /root/.ssh/authorized_keys
            chmod 600 /root/.ssh/authorized_keys
            echo "SSH: loaded $NKEYS key(s) from $SSHKEYS_URL"
        fi
        rm -f /tmp/sshkeys
    else
        echo "SSH: WARNING — failed to fetch keys from $SSHKEYS_URL"
    fi
fi

# --- Wait for network (max 15 sec) ---
echo "Waiting for network..."
for i in $(seq 1 15); do
    IP=$(ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | head -1)
    [ -n "$IP" ] && break
    sleep 1
done

# --- Generate MOTD ---
cat > /etc/motd <<MOTD

  ┌─────────────────────────────────────────┐
  │         PVE RESCUE SYSTEM               │
  │  Kernel: $(uname -r)
  │  $(printf "%-40s" "IPs: $(ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | tr '\n' ' ')")│
  │                                         │
  │  Proxmox chroot:  pve-chroot            │
  │  Manual ZFS:      zpool import -a -f -N │
  │  Manual LVM:      vgchange -ay          │
  │  Mount:           mount /dev/XXX /mnt   │
  └─────────────────────────────────────────┘

MOTD
