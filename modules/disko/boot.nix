# BIOS boot (1M) + EFI System Partition (512M, vfat, /boot).
{
  myDisko.partitions = {
    boot = {
      size = "1M";
      type = "EF02";
    };
    ESP = {
      size = "512M";
      type = "EF00";
      content = {
        type = "filesystem";
        format = "vfat";
        mountpoint = "/boot";
        mountOptions = [ "umask=0077" ];
      };
    };
  };
}
