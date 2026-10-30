#!/bin/bash
# à lancer avec sudo
U="${SUDO_USER:-$USER}"
UHOME=$(getent passwd "$U" | cut -d: -f6)

logkeys -k 2>/dev/null
rm -f /run/logkeys.pid
pkill -f 'socat.*TCP:' 2>/dev/null
pkill -f 'pty.spawn' 2>/dev/null

rm -f /tmp/b.sh /dev/shm/.kl /dev/shm/.h

sed -i '/SUDO:\$USER/d' "$UHOME/.bashrc"
chown "$U:$U" "$UHOME/.bashrc"

apt-get purge -y logkeys 2>/dev/null
echo "nettoye"
