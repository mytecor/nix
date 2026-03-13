{
  imports = [
    ../../profiles/worker.nix
  ];

  # Disk
  myDisko.device = "/dev/sda";

  # Network
  networking.hostName = "novaga";

  system.stateVersion = "24.11";
}
