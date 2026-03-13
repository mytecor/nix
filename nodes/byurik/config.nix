{ config, ... }:

{
  imports = [
    ../../hardware/intel-n100.nix
    ../../profiles/worker.nix
    ../../modules/wireless.nix
  ];

  # Disk
  myDisko.device = "/dev/sda";

  # Secrets
  sops.defaultSopsFile = ./secrets.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.secrets.root_password_hash.neededForUsers = true;

  # Users
  users.users.root.hashedPasswordFile = config.sops.secrets.root_password_hash.path;

  # Network
  networking.hostName = "byurik";

  system.stateVersion = "24.11";
}
