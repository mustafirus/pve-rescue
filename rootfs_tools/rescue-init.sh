#!/bin/bash
# Run-once interactive initialization script (called from .bashrc)
# Executes active actions only once per boot session

FLAG="/tmp/.init_done"

# If already initialized — exit immediately
[ -f "$FLAG" ] && return 0 2>/dev/null || { [ -f "$FLAG" ] && exit 0; }

# Wait for rescue-setup.service to finish (SSH keys fetch, MOTD)
systemctl is-active --quiet rescue-setup.service 2>/dev/null ||
    systemctl start --no-block rescue-setup.service 2>/dev/null
# Brief wait for network and key fetch
for i in $(seq 1 5); do
    systemctl is-active --quiet rescue-setup.service 2>/dev/null && break
    sleep 1
done

echo ""

# --- SSH setup ---
if [ -s /root/.ssh/authorized_keys ]; then
    # Keys exist — configure passwordless SSH
    NKEYS=$(grep -c . /root/.ssh/authorized_keys 2>/dev/null || echo 0)

    sed -i 's/^PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config.d/sshd_rescue.conf
    sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config.d/sshd_rescue.conf

    systemctl start ssh.service 2>/dev/null
    echo "SSH active (Key-based login enabled, $NKEYS key(s) loaded)"
else
    # No keys — ask user
    echo "SSH keys not found."
    read -r -p "Enable SSH via password? [y/N] " answer
    case "$answer" in
        [yY]|[yY][eE][sS])
            echo ""
            passwd root
            echo ""
            sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config.d/sshd_rescue.conf
            sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/sshd_rescue.conf

            systemctl start ssh.service 2>/dev/null
            IP=$(ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | head -1)
            echo "SSH active (Password login enabled)"
            [ -n "$IP" ] && echo "  Connect: ssh root@${IP%/*}"
            ;;
        *)
            echo "SSH disabled."
            ;;
    esac
fi

echo ""

# Mark initialization as done
touch "$FLAG"
