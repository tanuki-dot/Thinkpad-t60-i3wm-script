# thinkpad t60 i3 setup script

one script that takes a fresh void linux install on a t60 and leaves you with a working i3 desktop. intel tearing fix, i3 + picom + dunst + i3status, thinkpad media keys with little osd popups, alsa sound, optional wifi. its the setup off my own t60 that was my daily driver from 2024 to 2026. handled 720p60 youtube until google's a/b testing made the web too heavy for the hardware. still a bit rough but it does the job.

![host](https://img.shields.io/badge/host-thinkpad%20t60-black)
![distro](https://img.shields.io/badge/distro-void-blue)
![wm](https://img.shields.io/badge/wm-i3-success)
![status](https://img.shields.io/badge/status-partial-yellow)

> [!NOTE]
> void only. it uses xbps and runit, so it wont work on other distros as is. run it as your normal user, not root, sudo asks when it needs to.

> [!WARNING]
> run it with `bash`, not `sh`. it uses `set -euo pipefail` which plain sh doesnt do.

* * *

## contents

[#contents](#contents)

1. [what it is](#1-what-it-is)
2. [what it does](#2-what-it-does)
3. [what you need](#3-what-you-need)
4. [run it](#4-run-it)
5. [keybinds](#5-keybinds)
6. [whats configured](#6-whats-configured)
7. [gotchas](#7-gotchas)
8. [todo](#8-todo)
9. [links](#9-links)

* * *

## 1. what it is

[#1-what-it-is](#1-what-it-is)

one file, `t60-void-full-setup.sh`. it installs the desktop, drops all the config, and sets up autologin into i3. the goal was simple, keep an aging machine usable with a minimal setup without overcomplicating it. built for my own t60, so its a personal project, not a polished general purpose thing.

## 2. what it does

[#2-what-it-does](#2-what-it-does)

walks through in order:

- sanity checks: refuses to run as root, checks youre on void (xbps) and have sudo
- installs xorg + i3 and the usual bits: picom, dunst, i3status, dmenu, feh, alsa-utils, brightnessctl, setxkbmap, wpa_supplicant, dhcpcd, xf86-video-intel
- drops an intel driver conf for the i945 gpu (uxa + tearfree), kills the tearing
- adds you to the audio and video groups
- writes configs for i3, i3status, picom, dunst and a little osd script
- sets up autostart: `exec i3` in xinitrc, and `startx` on tty1 login
- optional wifi: asks for ssid/password, writes it with wpa_passphrase, enables the dhcpcd and wpa_supplicant runit services

## 3. what you need

[#3-what-you-need](#3-what-you-need)

- a thinkpad t60 with the intel gpu (i945). other t60s and thinkpads mostly work, but the intel conf is aimed at this one.
- a fresh void linux install with base and xbps working
- your normal user with sudo rights

## 4. run it

[#4-run-it](#4-run-it)

```
git clone https://github.com/tanuki-dot/Thinkpad-t60-i3wm-script
cd Thinkpad-t60-i3wm-script
bash t60-void-full-setup.sh
```

it asks for your sudo password, and near the end asks if you want to set wifi now (enter to skip). when its done: reboot so the group changes take, then login on tty1 and it drops you straight into i3 via startx.

## 5. keybinds

[#5-keybinds](#5-keybinds)

mod is Super (the thinkpad/windows key).

| keys              | does                     |
|-------------------|--------------------------|
| mod+Return        | terminal (kitty)         |
| mod+d             | dmenu                    |
| mod+Shift+q       | kill window              |
| mod+h / mod+v     | split horizontal / vertical |
| mod+f             | fullscreen               |
| mod+Shift+Space   | floating toggle          |
| mod+1..3          | switch workspace         |
| mod+Shift+1..3    | move window to workspace |
| mod+Shift+r       | restart i3               |
| mod+Shift+e       | exit i3                  |
| volume / brightness keys | media keys, with an osd popup |

## 6. whats configured

[#6-whats-configured](#6-whats-configured)

- **i3**: super mod, jetbrainsmono nerd font, small gaps, purple (`#9b6bdf`) bar theme, autostarts picom + dunst + wallpaper
- **i3status**: cpu, ram, wifi, volume, battery, date/time
- **picom**: xrender backend, fades, soft shadows, kitty at 90% opacity
- **dunst**: rounded corners, transparent, purple frame, progress bars for the osd
- **osd.sh**: amixer for volume (5% steps), brightnessctl for brightness (10% steps), both pop a dunstify bar

## 7. gotchas

[#7-gotchas](#7-gotchas)

| thing                     | whats up                                               |
|---------------------------|--------------------------------------------------------|
| no terminal / wrong font  | the config wants kitty and jetbrainsmono nerd font but the script installs neither. install both or the mod+Return bind and the fonts fall back. `xbps-query -Rs nerd` to find a font. |
| black background          | no wallpaper unless you drop one at `~/Pictures/wallpaper.jpg` |
| no sound at first         | audio/video groups only kick in after a reboot or relogin |
| bluetooth audio           | not reliable yet, on the todo                          |

## 8. todo

[#8-todo](#8-todo)

- fix bluetooth audio
- document the usb-c charging mod
- add 1.8v chip support on the raspberry pi spi programmer
- tidy up and expand the setup

## 9. links

[#9-links](#9-links)

- void handbook: [https://docs.voidlinux.org](https://docs.voidlinux.org)
- i3 user guide: [https://i3wm.org/docs/userguide.html](https://i3wm.org/docs/userguide.html)
- my t60 libreboot writeup: [https://github.com/tanuki-dot/t60-libreboot](https://github.com/tanuki-dot/t60-libreboot)
- raspberry bay, the spi programmer living in the t60 ultrabay: [https://github.com/tanuki-dot/raspberry-bay](https://github.com/tanuki-dot/raspberry-bay)
