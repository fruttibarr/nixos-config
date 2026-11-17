{ config, pkgs, quickshell, ... }:
{
  home.username = "chasec";
  home.homeDirectory = "/home/chasec";
  home.stateVersion = "26.05";

  imports = [
    ./hyprland.nix
    ./quickshell.nix
    ./kitty.nix
    ./matugen.nix
    ./lockscreen.nix
  ];

  home.packages = with pkgs; [
    fuzzel # app launcher
    wlogout # power menu
    hyprpaper # wallpaper daemon
    grim
    slurp # screenshot region select
    wl-clipboard
    playerctl
    brightnessctl
    pamixer
    hyprpicker
    spotify-player # terminal Spotify client (streams itself; needs Premium)

    # Cursor themes offered in Settings › Mouse & Touchpad › Cursor. Keep
    # this list in sync with `pointer.theme` in
    # quickshell/services/HyprSettings.qml.
    bibata-cursors
    phinger-cursors
    capitaine-cursors
    catppuccin-cursors.mochaDark
    catppuccin-cursors.mochaLight
    rose-pine-cursor
    graphite-cursors
    vimix-cursors
  ];

  # Default cursor — replaces Hyprland's built-in fallback. Also writes
  # ~/.icons/default and the GTK/X11 settings so every toolkit agrees. The
  # settings panel can switch it live; hyprland.nix sets the matching env.
  home.pointerCursor = {
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };

  # spotify_player ships no .desktop file; this makes it show up in the
  # island's app launcher. It registers with MPRIS, so the island's
  # now-playing, the control-center media card and the media keys all work.
  xdg.desktopEntries.spotify-player = {
    name = "Spotify";
    genericName = "Music Player (terminal)";
    comment = "Spotify in the terminal, with album art";
    exec = "kitty -1 --class spotify_player -e spotify_player";
    icon = "spotify";
    terminal = false;
    categories = [ "Audio" "Music" "Player" ];
  };

  # BlueZ pairing agent. Without one, pairing from the control center fails:
  # nothing answers BlueZ's pairing handshake, which even "just works"
  # devices (speakers, headphones, controllers) need. NoInputNoOutput accepts
  # without prompting — safe because the adapter is only *pairable* while the
  # control center's Bluetooth page is open (BluetoothPage.qml).
  systemd.user.services.bt-agent = {
    Unit = {
      Description = "BlueZ pairing agent (NoInputNoOutput)";
      After = [ "dbus.service" ];
    };
    Service = {
      ExecStart = "${pkgs.bluez-tools}/bin/bt-agent --capability=NoInputNoOutput";
      # bt-agent turns the adapter pairable (indefinitely) when it starts;
      # switch that back off so only the Bluetooth page opens the window.
      ExecStartPost = "${pkgs.bash}/bin/sh -c 'sleep 1; ${pkgs.bluez}/bin/bluetoothctl pairable off >/dev/null'";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "default.target" ];
  };

  programs.home-manager.enable = true;

  programs.fish = {
    enable = true;
    # home-manager 26.05's man-page completion generator calls
    # share/fish/tools/create_manpage_completions.py, which fish 4.9 (from
    # nixpkgs-unstable) no longer ships — the build fails. fish's own bundled
    # completions still work; this only skips the auto-generated extras.
    generateCompletions = false;
    # No "Welcome to fish" banner on every new terminal.
    interactiveShellInit = ''
      set -g fish_greeting
    '';
  };
  fonts.fontconfig.enable = true;
}
