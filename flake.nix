{
  description = "chasec's NixOS + Hyprland + Quickshell rice";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    claude-code.url = "github:sadjow/claude-code-nix"; # or github:ryoppippi/nix-claude-code

    # Add the official Horizon repository
    horizon = {
      url = "github:horizon-rust/horizon";
      inputs.nixpkgs.follows = "nixpkgs";
    }; # <-- Added missing closing brace here

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Upstream is git.outfoxxed.me; the GitHub mirror is used so the flake
    # resolves via the tarball fetcher instead of requiring a git binary.
    quickshell = {
      url = "github:quickshell-mirror/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # Added `horizon` to outputs
  outputs = { self, nixpkgs, home-manager, quickshell, horizon, ... }:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        inherit system;
        # Passed `horizon` to configuration.nix
        specialArgs = { inherit quickshell horizon; };
        modules = [
          ./configuration.nix
          ./horizon.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            # Passed `horizon` to home/chasec.nix as well
            home-manager.extraSpecialArgs = { inherit quickshell horizon; };
            home-manager.users.chasec = import ./home/chasec.nix;
          }
        ];
      };
    };
}
