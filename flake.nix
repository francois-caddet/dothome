{
  description = "Home Manager configuration of fcaddet";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixneovim.url = "github:nixneovim/nixneovim";
  };

  outputs = { nixpkgs, home-manager, nixneovim, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          nixneovim.overlays.default
        ];
      };
    in {
      homeConfigurations = {
        "fcaddet" = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;

          # Specify your home configuration modules here, for example,
          # the path to your home.nix.
          modules = [ ./home.nix ./nvim.nix ./nixos.nix ];

          # Optionally use extraSpecialArgs
          # to pass through arguments to home.nix
	  extraSpecialArgs = { inherit nixneovim; username = "fcaddet"; };
        };
        "f_caddet" = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;

          # Specify your home configuration modules here, for example,
          # the path to your home.nix.
          modules = [ ./home.nix ./nvim.nix ];

          # Optionally use extraSpecialArgs
          # to pass through arguments to home.nix
	  extraSpecialArgs = { inherit nixneovim; username = "f_caddet"; };
        };
      };
    };
  }
