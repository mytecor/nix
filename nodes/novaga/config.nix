{
  imports = [
    ../../hardware/intel-n100.nix
    ../../profiles/worker.nix
  ];

  # Disk
  myDisko.device = "/dev/sda";
}
