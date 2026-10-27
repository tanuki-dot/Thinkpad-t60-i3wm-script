# ThinkPad T60 i3wm Setup Script

A lightweight setup script for turning a ThinkPad T60 into a usable Linux workstation with i3wm, Picom, ThinkPad hotkeys, and a basic ALSA sound setup.

![Machine](https://img.shields.io/badge/ThinkPad-T60-black)
![Status](https://img.shields.io/badge/status-partial-working)

This repo is a personal setup project built for a machine that was my daily driver from 2024 to 2026. It handled 720p 60fps YouTube playback before Google’s aggressive A/B testing and the web became too heavy for this hardware. On a 13.10-based setup, it’s still a little rough around the edges, but it gets the job done.

## What this setup includes

- i3 window manager configuration
- Picom compositor setup
- ThinkPad hotkey support
- Basic ALSA audio configuration
- A simple script-based install flow for a T60

## Notes

Bluetooth audio still does not work reliably yet. I plan to revisit that later and improve it in future updates.

## Why this exists

This was built as a practical way to make an older ThinkPad usable again with a minimalist Linux environment. The goal was simple: keep an aging machine functional without overcomplicating the setup.

## Project status

The setup works well enough for daily use on the machine it was built for, but it is still a personal project and not a polished general-purpose solution.

## Future plans

- improve Bluetooth audio support
- document a USB-C charging modification
- add support for 1.8V chips on the Raspberry Pi SPI programmer
- clean up and expand the setup instructions

## Extra hardware project

I also built a small Raspberry Pi-based SPI programmer as a handy gadget for flashing chips. It is useful for hardware work, though it currently supports 3.3V flashing only.

## Final thoughts

I hope someone enjoys this project or finds it useful. It’s a little rough around the edges, but it works and was made for a real machine with real use in mind.
