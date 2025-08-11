{
  description = "Home Manager configuration of fcaddet";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";
    vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    vscode-extensions.inputs.nixpkgs.follows = "nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ flake-parts, ... }:
  # https://flake.parts/module-arguments.html
  flake-parts.lib.mkFlake { inherit inputs; } (top@{ config, withSystem, moduleWithSystem, ... }: {
    imports = [
      # Optional: use external flake logic, e.g.
      # inputs.foo.flakeModules.default
        inputs.home-manager.flakeModules.home-manager
    ];
    flake = {
    nixpkgs.overlays = [
          inputs.nixvim.overlays.default
          inputs.vscode-extensions.overlays.default
	  ];
        homeModules.fcaddet = {
        imports = [
          ./home.nix
    inputs.nixvim.homeModules.nixvim
    ./nvim.nix
    ./nixos.nix
  ];
        };
homeConfigurations.fcaddet = inputs.home-manager.lib.homeManagerConfiguration {
          pkgs = import inputs.nixpkgs {
            system = "x86_64-linux";
            overlays = config.flake.nixpkgs.overlays;
          };
      modules = [ 
            config.flake.homeModules.fcaddet
            {
          home.username = "fcaddet";
            }
      ];
    };
homeConfigurations.f_caddet = inputs.home-manager.lib.homeManagerConfiguration {
          pkgs = import inputs.nixpkgs {
            system = "x86_64-linux";
            overlays = config.flake.nixpkgs.overlays;
          };
      modules = [ 
            config.flake.homeModules.fcaddet
            {
          home.username = "f_caddet";
            }
      ];
    };
};
    systems = [
      # systems for which you want to build the `perSystem` attributes
      "x86_64-linux"
      # ...
    ];
    perSystem = { config, pkgs, ... }: {
      # Recommended: move all package definitions here.
      # e.g. (assuming you have a nixpkgs input)
      # packages.foo = pkgs.callPackage ./foo/package.nix { };
      # packages.bar = pkgs.callPackage ./bar/package.nix {
      #   foo = config.packages.foo;
      # };
    };
  });
}
