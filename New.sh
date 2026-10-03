#!/usr/bin/env bash
# =============================================================================
# t60-void-full-setup.sh
# Kompletní desktop setup FrankenPad T60 na Void Linuxu — i3 + picom + dunst +
# ly login manager + power/thermal/memory ladění.
# Hardware: T7600 Core 2 Duo / 945GM / 4GB RAM / SATA SSD (sda) / CCFL panel.
#
#   chmod +x t60-void-full-setup.sh
#   ./t60-void-full-setup.sh
#
# Spustit jako NORMÁLNÍ user (ne root), sudo se zeptá samo kde je potřeba.
# Re-run je bezpečný (idempotentní), ale přepíše dotfiles — pokud sis v nich
# něco ručně doladila, zálohuj si to zvlášť.
#
# !!! PO DOBĚHNUTÍ JE NUTNÝ REBOOT !!!  (kvůli thinkpad_acpi fan_control,
#     group membership a přechodu na ly). Detaily viz výpis na konci.
# =============================================================================

set -euo pipefail

echo "=== FrankenPad T60 — kompletní Void i3 setup ==="

# ---------- 0. sanity checks ----------
if [ "$(id -u)" -eq 0 ]; then
    echo "CHYBA: nespouštěj jako root. Spusť jako svůj user — sudo se zeptá samo."
    exit 1
fi
command -v xbps-install >/dev/null 2>&1 || { echo "Tohle je jen pro Void Linux."; exit 1; }
command -v sudo        >/dev/null 2>&1 || { echo "Chybí sudo."; exit 1; }
echo "-> ověřuji sudo (možná se zeptá na heslo)"
sudo -v

# =============================================================================
# 1. BALÍČKY
# =============================================================================
echo "-> instaluji hlavní sadu balíčků"
sudo xbps-install -Sy \
    xorg-minimal xorg-fonts xorg-input-drivers xinit setxkbmap \
    xf86-video-intel \
    i3 dmenu i3status kitty xterm picom dunst feh \
    alsa-utils brightnessctl \
    wpa_supplicant dhcpcd \
    pcmanfm xarchiver zathura zathura-pdf-mupdf firefox \
    zip unzip p7zip \
    arc-theme papirus-icon-theme \
    udisks2 udiskie gvfs elogind polkit dbus \
    xfburn \
    tlp powertop \
    earlyoom zramen \
    thinkfan lm_sensors \
    cronie \
    dosfstools \
    bluez blueman

# wine potřebuje multilib repo ZVLÁŠŤ a napřed (32bit knihovny jsou v jiném repu)
echo "-> přidávám multilib repo a instaluji wine"
sudo xbps-install -Sy void-repo-multilib
sudo xbps-install -Sy
sudo xbps-install -Sy wine wine-mono wine-gecko winetricks

# Nerd Font zvlášť a "best effort" — přesný název balíčku se v repu občas mění,
# ať jedna nejistá položka neshodí celou instalaci výše.
echo "-> zkouším nainstalovat Nerd Font (když selže, dořeš ručně dle výpisu na konci)"
sudo xbps-install -Sy nerd-fonts || \
    echo "   (nerd-fonts nenainstalováno — spusť: xbps-query -Rs nerd  a vyber si)"

# =============================================================================
# 2. SYSTÉMOVÉ KONFIGY (vyžadují root)
# =============================================================================

echo "-> Intel driver (UXA + TearFree) — modesetting je na 945GM nespolehlivý"
sudo mkdir -p /etc/X11/xorg.conf.d
sudo tee /etc/X11/xorg.conf.d/20-intel.conf > /dev/null <<'EOF'
Section "Device"
    Identifier  "Intel Graphics"
    Driver      "intel"
    Option      "AccelMethod"  "uxa"
    Option      "TearFree"     "true"
EndSection
EOF

echo "-> thinkpad_acpi fan_control (projeví se až po rebootu)"
sudo tee /etc/modprobe.d/thinkpad_acpi.conf > /dev/null <<'EOF'
options thinkpad_acpi fan_control=1
EOF

echo "-> TLP config (laděno: šetřit baterku, ale nezabít už tak slabý výkon)"
sudo tee /etc/tlp.conf > /dev/null <<'EOF'
TLP_ENABLE=1
TLP_DEFAULT_MODE=BAT
TLP_PERSISTENT_DEFAULT=0

# ondemand i na baterce ZÁMĚRNĚ — powersave governor pinuje nejnižší frekvenci
# a na T7600 by byl stroj k nepoužití.
CPU_SCALING_GOVERNOR_ON_AC=ondemand
CPU_SCALING_GOVERNOR_ON_BAT=ondemand
CPU_SCALING_MIN_FREQ_ON_AC=0
CPU_SCALING_MAX_FREQ_ON_AC=0
CPU_SCALING_MIN_FREQ_ON_BAT=0
CPU_SCALING_MAX_FREQ_ON_BAT=0

DISK_DEVICES="sda"
DISK_APM_LEVEL_ON_AC="254 254"
DISK_APM_LEVEL_ON_BAT="128 128"
SATA_LINKPWR_ON_AC="medium_power"
SATA_LINKPWR_ON_BAT="min_power"

RUNTIME_PM_ON_AC=auto
RUNTIME_PM_ON_BAT=auto

PCIE_ASPM_ON_AC=default
PCIE_ASPM_ON_BAT=powersave

WIFI_PWR_ON_AC=off
WIFI_PWR_ON_BAT=on

SOUND_POWER_SAVE_ON_AC=0
SOUND_POWER_SAVE_ON_BAT=1
SOUND_POWER_SAVE_CONTROLLER=Y

# USB autosuspend vypnutý — dělá lagy/odpojování myši, XP-Pen tabletu a dock USB.
USB_AUTOSUSPEND=0

WOL_DISABLE=Y

# Nabíjecí prahy na T60 potřebují tp_smapi; pro max výdrž nech nabíjet na 100%.
#START_CHARGE_THRESH_BAT0=75
#STOP_CHARGE_THRESH_BAT0=80
EOF

echo "-> thinkfan — agresivní chladicí křivka (coretemp indices [2,3])"
sudo tee /etc/thinkfan.yaml > /dev/null <<'EOF'
sensors:
  - hwmon: /sys/class/hwmon
    name: coretemp
    indices: [2, 3]

fans:
  - tpacpi: /proc/acpi/ibm/fan

levels:
  - [0, 0, 48]
  - [1, 44, 55]
  - [2, 51, 62]
  - [3, 58, 70]
  - [4, 65, 78]
  - [7, 73, 32767]
EOF

echo "-> zram swappiness (zram je rychlý, default 60 je laděný na pomalý disk)"
sudo mkdir -p /etc/sysctl.d
sudo tee /etc/sysctl.d/99-zram.conf > /dev/null <<'EOF'
vm.swappiness=150
EOF
sudo sysctl --system >/dev/null || true

echo "-> týdenní fstrim přes cron"
sudo mkdir -p /etc/cron.d
FSTRIM_BIN="$(command -v fstrim || echo /usr/bin/fstrim)"
echo "0 3 * * 6 root ${FSTRIM_BIN} /" | sudo tee /etc/cron.d/fstrim > /dev/null

echo "-> dhcpcd: ignoruj eth0 (žádný kabel → jinak spamuje tty)"
if ! grep -q "^denyinterfaces eth0" /etc/dhcpcd.conf 2>/dev/null; then
    echo "denyinterfaces eth0" | sudo tee -a /etc/dhcpcd.conf > /dev/null
fi

# =============================================================================
# 3. SKUPINY (audio/video pro amixer, brightnessctl)
# =============================================================================
echo "-> přidávám $(whoami) do skupin audio, video (projeví se po relogu/rebootu)"
sudo usermod -aG audio,video "$(whoami)"

# =============================================================================
# 4. UŽIVATELSKÉ DOTFILES
# =============================================================================
echo "-> zapisuji uživatelské configy"
mkdir -p ~/.config/i3/scripts ~/.config/i3status ~/.config/picom \
         ~/.config/dunst ~/.config/gtk-3.0 ~/Pictures

# ---- i3 ----
cat > ~/.config/i3/config <<'EOF'
set $mod Mod4
font pango:JetBrainsMono Nerd Font 9

gaps inner 6
gaps outer 2

# české qwerty rozložení
exec_always --no-startup-id setxkbmap cz qwerty

# terminál + launcher
bindsym $mod+Return exec kitty
bindsym $mod+d exec --no-startup-id dmenu_run -fn "JetBrainsMono Nerd Font-10"
bindsym $mod+Shift+q kill

# split / layout
bindsym $mod+h split h
bindsym $mod+v split v
bindsym $mod+f fullscreen toggle
bindsym $mod+Shift+space floating toggle

# focus (šipky)
bindsym $mod+Left focus left
bindsym $mod+Down focus down
bindsym $mod+Up focus up
bindsym $mod+Right focus right

# přesun oken
bindsym $mod+Shift+Left move left
bindsym $mod+Shift+Down move down
bindsym $mod+Shift+Up move up
bindsym $mod+Shift+Right move right

# resize mode
mode "resize" {
    bindsym Left  resize shrink width 10 px
    bindsym Right resize grow width 10 px
    bindsym Up    resize shrink height 10 px
    bindsym Down  resize grow height 10 px
    bindsym Return mode "default"
    bindsym Escape mode "default"
}
bindsym $mod+r mode "resize"

# workspaces
bindsym $mod+1 workspace 1
bindsym $mod+2 workspace 2
bindsym $mod+3 workspace 3
bindsym $mod+Shift+1 move container to workspace 1
bindsym $mod+Shift+2 move container to workspace 2
bindsym $mod+Shift+3 move container to workspace 3

bindsym $mod+Shift+r restart
bindsym $mod+Shift+e exec i3-msg exit

# bluetooth GUI na vyžádání (applet NEběží automaticky)
bindsym $mod+b exec --no-startup-id blueman-manager

# démoni na pozadí
exec --no-startup-id picom --config ~/.config/picom/picom.conf
exec --no-startup-id dunst
exec --no-startup-id udiskie
exec_always --no-startup-id sh -c 'test -f ~/Pictures/wallpaper.jpg && feh --bg-fill ~/Pictures/wallpaper.jpg'

# multimediální klávesy (OSD přes dunst)
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

# ---- i3status ----
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
cpu_usage { format = "CPU %usage" }
memory { format = "RAM %used"; threshold_degraded = "10%" }
wireless _first_ { format_up = "W: %essid %quality"; format_down = "W: down" }
volume master { format = "VOL %volume" }
battery 0 { format = "BAT %status %percentage %remaining" }
tztime local { format = "%d.%m %H:%M" }
EOF

# ---- picom (vč. fixů na tearing u fullscreen videa) ----
cat > ~/.config/picom/picom.conf <<'EOF'
backend = "xrender";
vsync = true;
unredirect-fullscreen-windows = false;

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

# ---- dunst ----
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

# ---- OSD skript ----
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
      -h string:x-dunst-stack-tag:vol "Hlasitost: ${v}%" ;;
  bright_*)
    b=$(brightnessctl get); m=$(brightnessctl max); p=$((b * 100 / m))
    dunstify -a osd -u low -i display-brightness -h int:value:"$p" \
      -h string:x-dunst-stack-tag:bright "Jas: ${p}%" ;;
esac
EOF
chmod +x ~/.config/i3/scripts/osd.sh

# ---- GTK vzhled (jinak pcmanfm vypadá rozbitě) ----
cat > ~/.config/gtk-3.0/settings.ini <<'EOF'
[Settings]
gtk-theme-name=Arc-Dark
gtk-icon-theme-name=Papirus-Dark
EOF

# ---- .xinitrc jako fallback pro ly ----
cat > ~/.xinitrc <<'EOF'
exec i3
EOF

# ---- úklid starého startx hacku (kdyby stroj dřív jel na autologin+startx) ----
for pf in "$HOME/.bash_profile" "$HOME/.zprofile"; do
    [ -f "$pf" ] || continue
    if grep -q 'exec startx' "$pf"; then
        cp "$pf" "${pf}.bak.$(date +%s)"
        awk '
            /\[ "\$\(tty\)" = "\/dev\/tty1" \]/ {inb=1}
            inb==0 {print}
            inb==1 && /^fi$/ {inb=0}
        ' "${pf}.bak."* > "$pf" 2>/dev/null || true
        echo "-> odstraněn startx hack z $pf (záloha vedle s příponou .bak.*)"
    fi
done

# =============================================================================
# 5. SLUŽBY (runit)
# =============================================================================
echo "-> zapínám runit služby"
# systémové (automount, polkit)
sudo ln -sf /etc/sv/dbus       /var/service/
sudo ln -sf /etc/sv/elogind    /var/service/
sudo ln -sf /etc/sv/polkitd    /var/service/
sudo ln -sf /etc/sv/udisks2    /var/service/
# síť
sudo ln -sf /etc/sv/dhcpcd         /var/service/
sudo ln -sf /etc/sv/wpa_supplicant /var/service/
# power / mem / thermal
sudo ln -sf /etc/sv/tlp      /var/service/
sudo ln -sf /etc/sv/zramen   /var/service/
sudo ln -sf /etc/sv/earlyoom /var/service/
sudo ln -sf /etc/sv/thinkfan /var/service/
# cron
sudo ln -sf /etc/sv/crond    /var/service/

# ---- ly: build ZE ZDROJE (není ve Void repu) + zapnutí na tty2 ----
# ly se staví přes zig; vyžaduje RELEASE zig 0.16.x (ne -dev). Když verze nesedí
# nebo build spadne, ly se PŘESKOČÍ a zbytek systému doběhne — přihlášení pak
# vyřešíš ručně (viz poznámky na konci).
echo "-> instaluji build dependencies pro ly"
sudo xbps-install -Sy base-devel git zig pam-devel libxcb-devel xorg-server xauth

LY_SRC="$HOME/src/ly"
ly_ok=0
if command -v zig >/dev/null 2>&1; then
    ZIG_VER="$(zig version 2>/dev/null || echo none)"
else
    ZIG_VER="none"
fi

case "$ZIG_VER" in
    0.16.*)
        echo "-> stavím ly ze zdroje (zig $ZIG_VER)"
        mkdir -p "$HOME/src"
        if [ -d "$LY_SRC/.git" ]; then
            git -C "$LY_SRC" pull --ff-only || echo "   (git pull selhal — stavím stávající checkout)"
        else
            git clone https://github.com/fairyglade/ly.git "$LY_SRC" || echo "   (git clone selhal)"
        fi
        if [ -f "$LY_SRC/build.zig" ] && ( cd "$LY_SRC" && zig build && sudo zig build installexe -Dinit_system=runit ); then
            ly_ok=1
        else
            echo "   !! ly build selhal — viz zig výstup výše."
        fi
        ;;
    *)
        echo "   !! zig verze '$ZIG_VER' — ly chce RELEASE 0.16.x. Build PŘESKOČEN."
        echo "      Správný zig stáhni z https://ziglang.org/download/ a build spusť ručně."
        ;;
esac

if [ "$ly_ok" -eq 1 ]; then
    echo "-> ly nainstalováno, zapínám na tty2 a shazuji tam getty"
    [ -d /etc/sv/agetty-tty2 ] && sudo touch /etc/sv/agetty-tty2/down
    [ -e /var/service/agetty-tty2 ] && sudo unlink /var/service/agetty-tty2
    sudo ln -sf /etc/sv/ly /var/service/
else
    echo "   POZOR: ly NEnainstalováno — po rebootu nebudeš mít login manager."
    echo "   Dočasné přihlášení: přihlas se v tty a spusť 'startx' (pokud máš ~/.xinitrc)."
fi

# Bluetooth NEzapínáme automaticky (BT jsi řešila jako vypnuté). Když budeš chtít:
#   sudo ln -sf /etc/sv/bluetoothd /var/service/

# =============================================================================
# 6. WIFI (volitelné, interaktivní)
# =============================================================================
echo
read -r -p "Přidat teď wifi síť? SSID (Enter = přeskočit): " WIFI_SSID
if [ -n "$WIFI_SSID" ]; then
    read -r -s -p "Heslo: " WIFI_PASS; echo
    wpa_passphrase "$WIFI_SSID" "$WIFI_PASS" | sudo tee -a /etc/wpa_supplicant/wpa_supplicant.conf > /dev/null
    sudo sv restart wpa_supplicant dhcpcd 2>/dev/null || true
fi

# =============================================================================
# 7. SHRNUTÍ
# =============================================================================
cat <<'EOF'

==============================================================
HOTOVO — ale teď je POTŘEBA REBOOT.
==============================================================
Reboot je nutný kvůli:
  - thinkpad_acpi fan_control (thinkfan bez něj nenaběhne)
  - group membership audio/video (amixer, brightnessctl)
  - přechodu na ly (login manager)

PO REBOOTU tě chytne ly → vyber session i3, přihlas se.
(Pokud se u ly výše vypsalo PŘESKOČEN/selhal, login manager NEBĚŽÍ —
 přihlas se v tty a spusť 'startx', a build ly dořeš ručně dle bodu 1.)

Ještě ručně (skript to za tebe udělat nemůže):
  1. LY (když se build nepovedl):  ly se staví ze zdroje, ne z repa, a chce
     RELEASE zig 0.16.x. Když měl tvůj zig špatnou verzi, stáhni správný z
     https://ziglang.org/download/ a pak:
       cd ~/src/ly && zig build && sudo zig build installexe -Dinit_system=runit
       sudo touch /etc/sv/agetty-tty2/down
       sudo ln -sf /etc/sv/ly /var/service/
     Config je /etc/ly/config.lua (plně okomentovaný, Lua — ne .ini).
     Ověření configu:  ly --validate-config /etc/ly/config.lua
     UPDATE ly později:  cd ~/src/ly && git pull && zig build && sudo zig build installnoconf
     (installnoconf = nepřepíše tvůj config)
  2. THINKFAN ověř, než mu začneš věřit:  sudo thinkfan -n
     (chvíli nech běžet, sleduj přepínání levelů, pak Ctrl+C)
     Pozn.: coretemp indices jsou [2,3] — když thinkfan hlásí
     špatné čtení, zkontroluj:  for f in /sys/class/hwmon/hwmon*/temp*_input; do echo "$f=$(cat $f)"; done
  3. WALLPAPER:  hoď obrázek do ~/Pictures/wallpaper.jpg
  4. FIREFOX:    doinstaluj z addons uBlock Origin + h264ify
                 (h264ify = nižší CPU u videa, na 945GM znatelné)
  5. NERD FONT:  pokud se nenainstaloval, xbps-query -Rs nerd a vyber
  6. SSD noatime (volitelné, uspoří zápisy) — zkontroluj /etc/fstab a
     k řádkům / a /boot přidej do options ",noatime". fstab needitovat
     naslepo — radši ručně, překlep = nenaboot.

Rychlé ověření po rebootu:
  sudo tlp-stat -s            # TLP běží?
  cat /proc/sys/vm/swappiness # má být 150
  cat /proc/acpi/ibm/fan      # řádek commands: level = fan control OK
  free -h                     # vidíš zram swap?
  sv status /var/service/*    # přehled služeb

Bluetooth je nainstalovaný, ale NEběží automaticky. $mod+b otevře
blueman-manager. Trvale zapnout:  sudo ln -sf /etc/sv/bluetoothd /var/service/
==============================================================
EOF
