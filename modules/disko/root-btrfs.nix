# Root partition: btrfs with zstd compression and noatime.
{
  myDisko.partitions = {
    root = {
      size = "100%";
      content = {
        type = "btrfs";
        extraArgs = [ "-f" ];
        mountpoint = "/";
        mountOptions = [
          "compress=zstd"
          "noatime"
        ];
      };
    };
  };
}
