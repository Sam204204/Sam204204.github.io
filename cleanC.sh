#!/bin/bash
# Usage : sudo bash clean.sh
# Recupere /dev/shm/.kl AVANT si tu veux garder le log.
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
pkill -9 -f 'bash -li' 2>/dev/null

if [ -n "$UHOME" ] && [ -f "$UHOME/.bashrc" ]; then
  sed -i '/# PICOHOOK-START/,/# PICOHOOK-END/d' "$UHOME/.bashrc"
  sed -i '/^$/N;/^\n$/D' "$UHOME/.bashrc"
  chown "$U" "$UHOME/.bashrc"
fi

if [ -f /dev/shm/.hadlogkeys ]; then
  :
fi
HAD=$(cat /dev/shm/.hadlogkeys 2>/dev/null || echo 1)
if [ "$HAD" = "0" ]; then
  apt-get purge -y logkeys 2>/dev/null
  echo "[+] logkeys purge (installe par le payload)"
else
  echo "[=] logkeys laisse en place (pre-installe)"
fi
rm -f /tmp/b.sh /tmp/.cb.log /dev/shm/.kl /dev/shm/.h /dev/shm/.km /dev/shm/.hadlogkeys

echo "--- etat final ---"
pgrep -a logkeys || echo "logkeys : aucun"
pgrep -af 'socat.*EXEC' || echo "socat : aucun"
pgrep -af 'bash -li' || echo "shell root orphelin : aucun"
ls -la /dev/shm
if [ -n "$UHOME" ]; then
  echo "hooks restants : $(grep -c 'PICOHOOK' "$UHOME/.bashrc" 2>/dev/null || echo 0)"
fi

