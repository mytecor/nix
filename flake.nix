{
  description = "Mytecor homelab";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable-small";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nixpkgs-stable,
      disko,
      sops-nix,
      ...
    }:
    let

      mkNixosSystem =
        {
          system,
          modules ? [ ],
          specialArgs ? { },
        }:
        let
          specialArgsMerged =
            { inherit inputs; }
            // specialArgs
            // {
              pkgs-stable = import nixpkgs-stable {
                inherit system;
                config = {
                  allowUnfree = true;
                };
              };
            };
        in
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = specialArgsMerged;
          modules = [
            disko.nixosModules.disko
            sops-nix.nixosModules.sops
          ] ++ modules;
        };

    in
    {
      nixosConfigurations = {
        novaga = mkNixosSystem {
          system = "x86_64-linux";
          modules = [
            ./nodes/novaga/config.nix
          ];
        };

        byurik = mkNixosSystem {
          system = "x86_64-linux";
          modules = [
            ./nodes/byurik/config.nix
          ];
        };
      };
    };
}
