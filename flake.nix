{
  description = "Minimal GRUB theme with safer portable installation and NixOS support";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = lib.genAttrs systems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          minimal-grub-theme = pkgs.callPackage ./nix/package.nix { };
        in
        {
          default = minimal-grub-theme;
          inherit minimal-grub-theme;
        }
      );

      checks = forAllSystems (system: {
        package = self.packages.${system}.minimal-grub-theme;
      });

      nixosModules.default = import ./nix/module.nix;
    };
}
