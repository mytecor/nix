# Base disko module: declares myDisko.device and myDisko.partitions,
# assembles them into disko.devices.
#
# Partition modules (boot.nix, root-btrfs.nix, swap.nix, etc.)
# add entries to myDisko.partitions via mkOption merging.
{ config, lib, ... }:

let
  cfg = config.myDisko;
in
{
  options.myDisko = {
    device = lib.mkOption {
      type = lib.types.str;
      description = "Block device path for the main disk (e.g. /dev/sda, /dev/nvme0n1).";
    };

    partitions = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Partition definitions merged into disko.devices.disk.main.content.partitions.";
    };
  };

  config.disko.devices.disk.main = {
    type = "disk";
    device = cfg.device;
    content = {
      type = "gpt";
      partitions = cfg.partitions;
    };
  };
}
