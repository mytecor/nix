# Worker profile: base server with GPT boot + btrfs root.
{
  imports = [
    ../modules/base.nix
    ../modules/server.nix
    ../modules/disko
    ../modules/disko/boot.nix
    ../modules/disko/root-btrfs.nix
  ];
}
