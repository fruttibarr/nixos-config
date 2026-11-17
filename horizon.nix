{ pkgs, horizon, ... }:

{
  environment.systemPackages = [
    horizon.packages.${pkgs.stdenv.hostPlatform.system}.horizon-launcher
  ];

  hardware.graphics.enable = true;
}
