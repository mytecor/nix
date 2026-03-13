# Swap partition (8G by default, override with myDisko.partitions.swap.size).
{
  myDisko.partitions = {
    swap = {
      size = "8G";
      content = {
        type = "swap";
        resumeDevice = true;
      };
    };
  };
}
