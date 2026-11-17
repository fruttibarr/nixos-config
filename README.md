# nixos-config

My NixOS + Hyprland + Quickshell rice, built around a **dynamic island**: one
pill at the top of the screen that morphs into everything else.

<!-- Add a screenshot: put it in this repo (e.g. screenshots/desktop.png) and uncomment:
![desktop](screenshots/desktop.png)
-->

## The island

| State | How to open |
|---|---|
| Idle — workspaces · clock · live activity | always there |
| Peek — media controls, status, date | hover |
| OSD — volume / brightness | media & brightness keys |
| App launcher (fuzzy search, calculator) | `SUPER+D`, right-click the island |
| Control center (Wi‑Fi, Bluetooth, sound, toggles) | `SUPER+A`, click the island |
| Settings (Hyprland + shell, live) | `SUPER+I` |
| Wallpaper picker | `SUPER+SHIFT+W` |
| Run a command in kitty | `/` on an empty workspace |

Also: draw a terminal by dragging on empty desktop, notifications,
matugen colours generated from the wallpaper, and a rebindable keybind editor.

## Layout

```
flake.nix                 inputs: nixpkgs, home-manager, quickshell, horizon
configuration.nix         system: greetd, pipewire, fish, Hyprland
hardware-configuration.nix
home/
  chasec.nix              home-manager entry point
  hyprland.nix            Hyprland (Lua config) + keybinds
  quickshell.nix          deploys home/quickshell/
  quickshell/             the shell itself (QML)
    Island.qml            the dynamic island
    widgets/              launcher, control center, settings, …
    services/             audio, network, media, brightness, …
  kitty.nix, matugen.nix, lockscreen.nix
```

## Using it

```sh
git clone https://github.com/<you>/nixos-config ~/nixos-config
# replace hardware-configuration.nix with your own:
cp /etc/nixos/hardware-configuration.nix ~/nixos-config/
# change the username "chasec" in flake.nix / configuration.nix / home/chasec.nix
sudo nixos-rebuild switch --flake ~/nixos-config#nixos
```

> Flakes only see files tracked by git — `git add` new files before rebuilding.
