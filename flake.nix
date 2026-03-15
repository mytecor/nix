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

  outputs = inputs@{ nixpkgs, nixpkgs-stable, ... }:
    let
      mkNixosSystems =
        nodes:
        nixpkgs.lib.genAttrs nodes (name:
          nixpkgs.lib.nixosSystem {
            specialArgs = { inherit inputs; };
            modules = [
              { nixpkgs.config.allowUnfree = true; }
              ./nodes/${name}/config.nix
              {
                networking.hostName = name;
                system.stateVersion = inputs.nixpkgs-stable.lib.trivial.release;
              }
              ({ config, ... }: {
                _module.args.pkgs-stable = import nixpkgs-stable {
                  system = config.nixpkgs.hostPlatform.system;
                  config.allowUnfree = true;
                };
              })
            ];
          }
        );
    in
    {
      nixosConfigurations = mkNixosSystems [
        "novaga"
        "byurik"
      ];
    };
}
