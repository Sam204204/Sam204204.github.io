#!/bin/bash
# Usage : sudo bash clean.sh
[ "$(id -u)" -eq 0 ] || { echo "lance avec sudo"; exit 1; }

U="${SUDO_USER:-$USER}"
UHOME=$(getent passwd "$U" | cut -d: -f6)

logkeys -k 2>/dev/null
rm -f /run/logkeys.pid

for pid in $(pgrep -f 'socat.*EXEC'); do
  kill -TERM "$pid" 2>/dev/null
  sleep 0.2
  kill -9 "$pid" 2>/dev/null
done
pkill -9 -f 'pty.spawn' 2>/dev/null

rm -f /tmp/b.sh /tmp/.cb.log /dev/shm/.kl /dev/shm/.h

if [ -n "$UHOME" ] && [ -f "$UHOME/.bashrc" ]; then
  sed -i '/SUDO:\$USER/d' "$UHOME/.bashrc"
  chown "$U:$U" "$UHOME/.bashrc"
fi

apt-get purge -y logkeys 2>/dev/null

echo "--- etat final ---"
pgrep -a logkeys || echo "logkeys : aucun"
pgrep -af 'socat.*EXEC' || echo "socat : aucun"
ls -la /dev/shm
echo "hooks restants : $(grep -c 'SUDO:' "$UHOME/.bashrc" 2>/dev/null)"
