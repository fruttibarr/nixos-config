{ config, pkgs, lib, quickshell, ... }:
let
  qsPkg = quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # Every QML source except Colors.qml, which matugen owns at runtime.
  qmlSources = lib.cleanSourceWith {
    src = ./quickshell;
    filter = path: type: baseNameOf path != "Colors.qml";
  };
in
{
  home.packages = [
    qsPkg
    pkgs.hyprsunset # night light toggle in the control center
    pkgs.imagemagick # wallpaper picker thumbnails (`magick`)
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
