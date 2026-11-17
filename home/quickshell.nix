{ config, pkgs, lib, quickshell, ... }:
let
  qsPkg = quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # Every QML source except Colors.qml, which matugen owns at runtime.
  qmlSources = lib.cleanSourceWith {
    src = ./quickshell;
    filter = path: type: baseNameOf path != "Colors.qml";
  };

  # Colour index for the wallpaper picker's search ("dark blue", "pink"...).
  # Appends one line per wallpaper not already in the index:
  #   <path relative to root>\t<count>:#RRGGBB <count>:#RRGGBB ...
  # (its 6 dominant colours, from a 48x48 downscale), so later runs only
  # process new files. Each worker appends its own line in a single small
  # write (atomic with O_APPEND), so killing a run midway never leaves a
  # torn line. Low priority and half the cores, so the desktop never stutters.
  wallpaperColors = pkgs.writeShellApplication {
    name = "wallpaper-colors";
    runtimeInputs = with pkgs; [ imagemagick findutils coreutils gawk util-linux ];
    text = ''
      root="$1"
      index="$2"
      mkdir -p "$(dirname "$index")"
      touch "$index"

      # One run at a time (the picker may be reopened mid-index).
      exec 9>"$index.lock"
      flock -n 9 || exit 0

      tmp=$(mktemp -d)
      trap 'rm -rf "$tmp"' EXIT

      cut -f1 "$index" | LC_ALL=C sort -u > "$tmp/done"
      find "$root" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
        -printf '%P\n' | LC_ALL=C sort > "$tmp/all"
      LC_ALL=C comm -23 "$tmp/all" "$tmp/done" > "$tmp/todo"

      jobs=$(( $(nproc) / 2 ))
      [ "$jobs" -lt 1 ] && jobs=1

      echo "todo $(wc -l < "$tmp/todo")"

      export WALL_ROOT="$root" WALL_INDEX="$index"
      # shellcheck disable=SC2016
      nice -n 19 xargs -d '\n' -P "$jobs" -n 8 sh -c '
        for f; do
          magick -define jpeg:size=96x96 "$WALL_ROOT/$f[0]" -resize "48x48!" -colors 6 -depth 8 \
              -format %c histogram:info:- 2>/dev/null \
            | awk -v f="$f" -v idx="$WALL_INDEX" '"'"'
                { n = $1; sub(":", "", n); for (i = 2; i <= NF; i++) if ($i ~ /^#/) { out = out (out ? " " : "") n ":" substr($i, 1, 7); break } }
                END { if (out) printf "%s\t%s\n", f, out >> idx }'"'"'
        done' sh < "$tmp/todo"
      echo "finished"
    '';
  };
in
{
  home.packages = [
    qsPkg
    pkgs.hyprsunset # night light toggle in the control center
    pkgs.imagemagick # wallpaper picker thumbnails (`magick`)
    wallpaperColors # wallpaper picker colour search
  ];

  # Quickshell QML sources are symlinked file-by-file from the Nix store
  # (`recursive`), so new widgets are picked up without listing them here and
  # the real, writable Colors.qml beside them is left alone.
  xdg.configFile."quickshell" = {
    source = qmlSources;
    recursive = true;
  };

  # Colors.qml is matugen's output path, so it must be a writable real file
  # rather than a store symlink. Seed it only if absent so a generated palette
  # is never clobbered by a rebuild.
  home.activation.seedQuickshellColors =
    config.lib.dag.entryAfter [ "writeBoundary" ] ''
      colorsFile="${config.xdg.configHome}/quickshell/Colors.qml"
      if [ ! -e "$colorsFile" ]; then
        run mkdir -p "$(dirname "$colorsFile")"
        run cp ${./quickshell/Colors.qml} "$colorsFile"
        run chmod 644 "$colorsFile"
      fi
    '';
}
