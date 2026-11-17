{ config, pkgs, ... }:
let
  wallpaperDir = "${config.home.homeDirectory}/Pictures/Wallpapers";

  # Regenerates every themed config from the given image, then reloads the
  # apps that can't pick up file changes on their own.
  setWallpaper = pkgs.writeShellApplication {
    name = "set-wallpaper";
    runtimeInputs = with pkgs; [
      matugen hyprpaper coreutils findutils imagemagick gawk hyprland util-linux
    ];
    text = ''
      WALLPAPER_DIR="${wallpaperDir}"
      STATE="$HOME/.cache/current-wallpaper"

      if [ "''${1:-}" = "--random" ]; then
        img=$(find "$WALLPAPER_DIR" -type f \
          \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
          | shuf -n1)
      elif [ -n "''${1:-}" ]; then
        img="$1"
      else
        echo "usage: set-wallpaper [--random | /path/to/image]" >&2
        exit 1
      fi

      if [ -z "$img" ] || [ ! -f "$img" ]; then
        echo "set-wallpaper: no image found (looked in $WALLPAPER_DIR)" >&2
        exit 1
      fi

      # Pick a Material You source colour from the image ourselves.
      #
      # `matugen image` would normally do this, but matugen 4.0.0 fails with
      # "IO error: not a terminal" in its image code path — and this script
      # runs from a Hyprland keybind, which never has a TTY. `matugen color`
      # works fine, so quantise here and feed it a hex colour instead.
      #
      # The most *frequent* colour is usually near-black and makes a drab
      # palette, so score on chroma and penalise near-black/near-white.
      pick_source_color() {
        magick "$1" -resize 200x200 -colors 8 -depth 8 \
            -format '%c' histogram:info: 2>/dev/null \
          | sed -nE 's/^ *([0-9]+):.*(#[0-9A-Fa-f]{6}).*/\1 \2/p' \
          | gawk '
              {
                count = $1; hex = $2;
                r = strtonum("0x" substr(hex, 2, 2));
                g = strtonum("0x" substr(hex, 4, 2));
                b = strtonum("0x" substr(hex, 6, 2));
                max = (r > g ? (r > b ? r : b) : (g > b ? g : b));
                min = (r < g ? (r < b ? r : b) : (g < b ? g : b));
                lum    = (max + min) / 510.0;
                chroma = (max - min) / 255.0;
                penalty = (lum < 0.12 || lum > 0.92) ? 0.25 : 1.0;
                score = (chroma * 2 + 0.15) * penalty * (1 + log(count + 1) / 20);
                if (score > best) { best = score; bestHex = hex }
              }
              END { print (bestHex == "" ? "#3a7d8c" : bestHex) }
            '
      }

      src=$(pick_source_color "$img")
      if [ -z "$src" ]; then
        echo "set-wallpaper: could not derive a colour from $img" >&2
        exit 1
      fi

      printf '%s\n' "$img" > "$STATE"

      # Rewrites Colors.qml, hypr/colors.lua, kitty/colors.conf and
      # hyprlock-colors.conf from templates, then runs each post_hook.
      matugen color hex "$src" --mode dark

      # hyprpaper 0.8.4 dropped the `preload`/`unload` IPC verbs and loads the
      # image on demand, so `wallpaper` is the only call needed.
      #
      # If hyprpaper isn't reachable (it died, or never started), bring the
      # supervisor up and retry — otherwise only the colours would change and
      # the old/blank background would stay. The daemon also applies $STATE
      # itself once hyprpaper is ready, so either path lands the image.
      if ! hyprctl hyprpaper wallpaper ",$img" >/dev/null 2>&1; then
        echo "set-wallpaper: hyprpaper not reachable, starting wallpaper-daemon" >&2
        setsid -f ${wallpaperDaemon}/bin/wallpaper-daemon >/dev/null 2>&1 < /dev/null || true
        applied=0
        for _ in $(seq 1 30); do
          sleep 0.2
          if hyprctl hyprpaper wallpaper ",$img" >/dev/null 2>&1; then applied=1; break; fi
        done
        if [ "$applied" -ne 1 ]; then
          echo "set-wallpaper: could not reach hyprpaper; colours still applied" >&2
        fi
      fi

      echo "wallpaper set: $img (source colour $src)"
    '';
  };
  # Supervises hyprpaper: starts it, restores the last wallpaper as soon as
  # its IPC is up (hyprpaper.conf names no image, so a bare hyprpaper shows
  # nothing), and restarts it if it ever exits. Started from Hyprland's
  # autostart and, as a fallback, by set-wallpaper.
  wallpaperDaemon = pkgs.writeShellApplication {
    name = "wallpaper-daemon";
    runtimeInputs = with pkgs; [ hyprpaper hyprland coreutils util-linux procps ];
    text = ''
      STATE="$HOME/.cache/current-wallpaper"
      LOCK="''${XDG_RUNTIME_DIR:-/tmp}/wallpaper-daemon.lock"

      # Single instance.
      exec 9>"$LOCK"
      flock -n 9 || exit 0

      restore() {
        [ -s "$STATE" ] || return 0
        img=$(head -n1 "$STATE")
        [ -f "$img" ] || return 0
        for _ in $(seq 1 50); do
          if hyprctl hyprpaper wallpaper ",$img" >/dev/null 2>&1; then return 0; fi
          sleep 0.1
        done
        echo "wallpaper-daemon: could not restore $img" >&2
      }

      quick_deaths=0
      while true; do
        # Stop once the compositor is gone (e.g. after logout).
        hyprctl version >/dev/null 2>&1 || exit 0

        # An unsupervised hyprpaper left over from before would hold the IPC
        # socket and make ours fail; take over from it.
        pkill -u "$(id -u)" -x hyprpaper 2>/dev/null && sleep 0.3

        started=$(date +%s)
        hyprpaper &
        pid=$!
        restore
        wait "$pid" || true

        if [ $(( $(date +%s) - started )) -lt 5 ]; then
          quick_deaths=$((quick_deaths + 1))
        else
          quick_deaths=0
        fi
        if [ "$quick_deaths" -ge 5 ]; then
          echo "wallpaper-daemon: hyprpaper keeps crashing on start; giving up" >&2
          exit 1
        fi
        echo "wallpaper-daemon: hyprpaper exited, restarting" >&2
        sleep 1
      done
    '';
  };
in
{
  home.packages = [ pkgs.matugen setWallpaper wallpaperDaemon ];

  xdg.configFile."matugen/config.toml".text = ''
    [config]

    [templates.quickshell]
    input_path = "${config.xdg.configHome}/matugen/templates/Colors.qml"
    output_path = "${config.xdg.configHome}/quickshell/Colors.qml"
    # Quickshell hot-reloads QML on file change, so no reload hook is needed.

    [templates.hyprland]
    input_path = "${config.xdg.configHome}/matugen/templates/colors.lua"
    output_path = "${config.xdg.configHome}/hypr/colors.lua"
    post_hook = "hyprctl reload || true"

    [templates.kitty]
    input_path = "${config.xdg.configHome}/matugen/templates/kitty-colors.conf"
    output_path = "${config.xdg.configHome}/kitty/colors.conf"
    # SIGUSR1 makes running kitty instances re-read their config in place.
    post_hook = "pkill -USR1 kitty || true"

    [templates.hyprlock]
    input_path = "${config.xdg.configHome}/matugen/templates/hyprlock-colors.conf"
    output_path = "${config.xdg.configHome}/hypr/hyprlock-colors.conf"
  '';

  xdg.configFile."matugen/templates/Colors.qml".text = ''
    pragma Singleton
    import QtQuick

    // GENERATED BY MATUGEN — edits here are overwritten on wallpaper change.
    QtObject {
        readonly property color background: "{{colors.surface.default.hex}}"
        readonly property color surface: "{{colors.surface_container.default.hex}}"
        readonly property color surfaceBright: "{{colors.surface_container_high.default.hex}}"
        // NOTE: these must NOT be named on*/onPrimary — QML parses an
        // `on<Name>` property as a signal handler for `<name>`, so Material
        // You's on_surface / on_primary roles are renamed here.
        readonly property color text: "{{colors.on_surface.default.hex}}"
        readonly property color textDim: "{{colors.on_surface_variant.default.hex}}"
        readonly property color primary: "{{colors.primary.default.hex}}"
        readonly property color textOnPrimary: "{{colors.on_primary.default.hex}}"
        readonly property color secondary: "{{colors.secondary.default.hex}}"
        readonly property color tertiary: "{{colors.tertiary.default.hex}}"
        readonly property color error: "{{colors.error.default.hex}}"
        readonly property color outline: "{{colors.outline_variant.default.hex}}"
    }
  '';

  # Hyprland's Lua config dofile()s this and reads it as a plain table.
  xdg.configFile."matugen/templates/colors.lua".text = ''
    -- GENERATED BY MATUGEN — edits here are overwritten on wallpaper change.
    return {
        primary = "rgb({{colors.primary.default.hex_stripped}})",
        surface = "rgb({{colors.surface_container.default.hex_stripped}})",
        text    = "rgb({{colors.on_surface.default.hex_stripped}})",
        outline = "rgb({{colors.outline_variant.default.hex_stripped}})",
    }
  '';

  xdg.configFile."matugen/templates/kitty-colors.conf".text = ''
    # GENERATED BY MATUGEN — edits here are overwritten on wallpaper change.
    background {{colors.surface.default.hex}}
    foreground {{colors.on_surface.default.hex}}
    cursor {{colors.primary.default.hex}}
    selection_background {{colors.primary.default.hex}}
    selection_foreground {{colors.on_primary.default.hex}}
    active_border_color {{colors.primary.default.hex}}
    inactive_border_color {{colors.outline_variant.default.hex}}
    active_tab_background {{colors.primary.default.hex}}
    active_tab_foreground {{colors.on_primary.default.hex}}
    inactive_tab_background {{colors.surface_container.default.hex}}
    inactive_tab_foreground {{colors.on_surface_variant.default.hex}}
  '';

  xdg.configFile."matugen/templates/hyprlock-colors.conf".text = ''
    # GENERATED BY MATUGEN — edits here are overwritten on wallpaper change.
    $lockPrimary = rgb({{colors.primary.default.hex_stripped}})
    $lockSurface = rgb({{colors.surface_container.default.hex_stripped}})
    $lockOnSurface = rgb({{colors.on_surface.default.hex_stripped}})
  '';

  xdg.configFile."hypr/hyprpaper.conf".text = ''
    ipc = on
    splash = false
  '';

  # Every matugen output_path must exist before first launch, otherwise
  # Hyprland/kitty/hyprlock reference undefined variables on a fresh boot.
  # These are writable real files (not store symlinks) and are only seeded
  # when absent, so a generated palette is never overwritten by a rebuild.
  home.activation.seedMatugenOutputs =
    config.lib.dag.entryAfter [ "writeBoundary" ] (
      let
        hyprFallback = pkgs.writeText "colors.lua" ''
          -- Fallback palette — replaced by matugen on first wallpaper change.
          return {
              primary = "rgb(c7bfff)",
              surface = "rgb(1f1e26)",
              text    = "rgb(e5e1e9)",
              outline = "rgb(484553)",
          }
        '';
        hyprlockFallback = pkgs.writeText "hyprlock-colors.conf" ''
          # Fallback palette — replaced by matugen on first wallpaper change.
          $lockPrimary = rgb(c7bfff)
          $lockSurface = rgb(1f1e26)
          $lockOnSurface = rgb(e5e1e9)
        '';
        kittyFallback = pkgs.writeText "colors.conf" ''
          # Fallback palette — replaced by matugen on first wallpaper change.
          background #14131a
          foreground #e5e1e9
          cursor #c7bfff
          selection_background #c7bfff
          selection_foreground #2e2660
        '';
      in
      ''
        seed() {
          if [ ! -e "$1" ]; then
            run mkdir -p "$(dirname "$1")"
            run cp "$2" "$1"
            run chmod 644 "$1"
          fi
        }
        seed "${config.xdg.configHome}/hypr/colors.lua" ${hyprFallback}
        seed "${config.xdg.configHome}/hypr/hyprlock-colors.conf" ${hyprlockFallback}
        seed "${config.xdg.configHome}/kitty/colors.conf" ${kittyFallback}
      ''
    );
}
