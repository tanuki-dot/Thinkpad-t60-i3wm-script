#!/usr/bin/e

set -euo pipefail

echo "=== FrankenPad T60 - Void i3 setup ==="

# ---------- 0. sanity checks ----------
if [ "$(id -u)" -eq 0 ]; then
    echo "Nespouštěj jako root - spusť jako svůj user, sudo se zeptá samo, kde bude potřeba."
    exit 1
fi

command -v xbps-install >/dev/null 2>&1 || {
    echo "xbps-install nenalezen - tenhle skript je pro Void Linux."
    exit 1
}

command -v sudo >/dev/null 2>&1 || {
    echo "Chybí sudo."
    exit 1
}

echo "-> ověřuji sudo (možná se zeptá na heslo)"
sudo -v

# ---------- 1. balíčky ----------
echo "-> instaluji balíčky"
sudo xbps-install -Sy \
    xorg-minimal xorg-fonts xorg-input-drivers xinit setxkbmap \
    xf86-video-intel \
    i3 dmenu i3status \
    picom \
    dunst alsa-utils brightnessctl \
    feh \
    wpa_supplicant dhcpcd

# ---------- 2. Intel UXA fix ----------
echo "-> nastavuji Intel driver (UXA, TearFree)"
sudo mkdir -p /etc/X11/xorg.conf.d
sudo tee /etc/X11/xorg.conf.d/20-intel.conf > /dev/null <<'EOF'
Section "Device"
    Identifier  "Intel Graphics"
    Driver      "intel"
    Option      "AccelMethod"  "uxa"
    Option      "TearFree"     "true"
EndSection
EOF

# ---------- 3. group membership ----------
echo "-> přidávám do skupin audio, video"
sudo usermod -aG audio,video "$(whoami)"

# ---------- 4. dotfiles ----------
echo "-> zapisuji config soubory"
mkdir -p ~/.config/i3/scripts
mkdir -p ~/.config/i3status
mkdir -p ~/.config/picom
mkdir -p ~/.config/dunst
mkdir -p ~/Pictures

cat > ~/.config/i3/config <<'EOF'
set $mod Mod4

font pango:JetBrainsMono Nerd Font 9

gaps inner 6
gaps outer 2

bindsym $mod+Return exec kitty
bindsym $mod+d exec --no-startup-id dmenu_run -fn "JetBrainsMono Nerd Font-10"
bindsym $mod+Shift+q kill

bindsym $mod+h split h
bindsym $mod+v split v
bindsym $mod+f fullscreen toggle
bindsym $mod+Shift+space floating toggle

bindsym $mod+1 workspace 1
bindsym $mod+2 workspace 2
bindsym $mod+3 workspace 3
bindsym $mod+Shift+1 move container to workspace 1
bindsym $mod+Shift+2 move container to workspace 2
bindsym $mod+Shift+3 move container to workspace 3

bindsym $mod+Shift+r restart
bindsym $mod+Shift+e exec i3-msg exit

exec --no-startup-id picom --config ~/.config/picom/picom.conf
exec --no-startup-id dunst
exec_always --no-startup-id sh -c 'test -f ~/Pictures/wallpaper.jpg && feh --bg-fill ~/Pictures/wallpaper.jpg'

bindsym XF86AudioRaiseVolume   exec --no-startup-id ~/.config/i3/scripts/osd.sh vol_up
bindsym XF86AudioLowerVolume   exec --no-startup-id ~/.config/i3/scripts/osd.sh vol_down
bindsym XF86AudioMute          exec --no-startup-id ~/.config/i3/scripts/osd.sh vol_mute
bindsym XF86MonBrightnessUp    exec --no-startup-id ~/.config/i3/scripts/osd.sh bright_up
bindsym XF86MonBrightnessDown  exec --no-startup-id ~/.config/i3/scripts/osd.sh bright_down

bar {
    status_command i3status
    position top
    font pango:JetBrainsMono Nerd Font 10
    colors {
        background          #1a1a1acc
        statusline          #cccccc
        separator           #666666
        focused_workspace   #9b6bdf #9b6bdf #1a1a1a
        active_workspace    #333333 #333333 #ffffff
        inactive_workspace  #1a1a1a #1a1a1a #888888
        urgent_workspace    #e06c75 #e06c75 #1a1a1a
    }
}
EOF

cat > ~/.config/i3status/config <<'EOF'
general {
    colors = true
    interval = 5
}

order += "cpu_usage"
order += "memory"
order += "wireless _first_"
order += "volume master"
order += "battery 0"
order += "tztime local"

cpu_usage {
    format = "CPU %usage"
}
memory {
    format = "RAM %used"
    threshold_degraded = "10%"
}
wireless _first_ {
    format_up = "W: %essid %quality"
    format_down = "W: down"
}
volume master {
    format = "VOL %volume"
}
battery 0 {
    format = "BAT %status %percentage %remaining"
}
tztime local {
    format = "%d.%m %H:%M"
}
EOF

cat > ~/.config/picom/picom.conf <<'EOF'
backend = "xrender";

fading = true;
fade-in-step = 0.03;
fade-out-step = 0.03;

shadow = true;
shadow-radius = 6;
shadow-opacity = 0.5;

opacity-rule = [
    "90:class_g = 'kitty'"
];
EOF

cat > ~/.config/dunst/dunstrc <<'EOF'
[global]
transparency = 15
corner_radius = 6
frame_color = "#9b6bdf"
progress_bar = true
progress_bar_height = 10
progress_bar_min_width = 150
font = JetBrainsMono Nerd Font 10
EOF

cat > ~/.config/i3/scripts/osd.sh <<'EOF'
#!/bin/sh
case "$1" in
  vol_up)      amixer -q sset Master 5%+ unmute ;;
  vol_down)    amixer -q sset Master 5%- unmute ;;
  vol_mute)    amixer -q sset Master toggle ;;
  bright_up)   brightnessctl set +10% ;;
  bright_down) brightnessctl set 10%- ;;
esac

case "$1" in
  vol_*)
    v=$(amixer get Master | grep -oP '\d+(?=%)' | head -1)
    dunstify -a osd -u low -i audio-volume-high -h int:value:"$v" \
      -h string:x-dunst-stack-tag:vol "Hlasitost: ${v}%"
    ;;
  bright_*)
    b=$(brightnessctl get); m=$(brightnessctl max)
    p=$((b * 100 / m))
    dunstify -a osd -u low -i display-brightness -h int:value:"$p" \
      -h string:x-dunst-stack-tag:bright "Jas: ${p}%"
    ;;
esac
EOF
chmod +x ~/.config/i3/scripts/osd.sh

cat > ~/.xinitrc <<'EOF'
exec i3
EOF

case "${SHELL:-}" in
    *zsh) PROFILE="$HOME/.zprofile" ;;
    *)    PROFILE="$HOME/.bash_profile" ;;
esac

if ! grep -q "exec startx" "$PROFILE" 2>/dev/null; then
    cat >> "$PROFILE" <<'EOF'

if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec startx
fi
EOF
fi

# ---------- 5. síť (volitelné) ----------
echo
read -r -p "Nastavit wifi teď? SSID (Enter = přeskočit): " WIFI_SSID
if [ -n "$WIFI_SSID" ]; then
    read -r -s -p "Heslo: " WIFI_PASS
    echo
    wpa_passphrase "$WIFI_SSID" "$WIFI_PASS" | sudo tee -a /etc/wpa_supplicant/wpa_supplicant.conf > /dev/null
fi

sudo ln -sf /etc/sv/dhcpcd /var/service/ 2>/dev/null || true
sudo ln -sf /etc/sv/wpa_supplicant /var/service/ 2>/dev/null || true

# ---------- 6. shrnutí ----------
echo
echo "=== Hotovo ==="
echo "Ještě zbývá ručně:"
echo "  - odhlásit se / rebootnout, ať se projeví group membership (audio, video)"
echo "  - hodit obrázek do ~/Pictures/wallpaper.jpg (jinak zůstane černé pozadí)"
echo "  - dohledat Nerd Font: xbps-query -Rs nerd"
echo "Pak stačí: startx"
