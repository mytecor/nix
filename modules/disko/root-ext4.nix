# Root partition: ext4.
{
  myDisko.partitions = {
    root = {
      size = "100%";
      content = {
        type = "filesystem";
        format = "ext4";
        mountpoint = "/";
        mountOptions = [ "noatime" ];
      };
    };
  };
}
