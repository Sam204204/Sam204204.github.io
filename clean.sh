#!/bin/bash
SELF="$HOME/.local/share/.whelper.sh"

pkill -f "whelper.sh" 2>/dev/null
crontab -l 2>/dev/null | grep -vF "$SELF" | crontab -
rm -f "$HOME/.config/autostart/whelper.desktop"
rm -f "$SELF" /tmp/w.sh
[ -f "$HOME/.ssh/authorized_keys" ] && sed -i '/demo-badusb/d' "$HOME/.ssh/authorized_keys"
echo "Nettoyage termine."
