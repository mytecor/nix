{ config, ... }:

{
  imports = [
    ../../hardware/intel-n100.nix
    ../../profiles/worker.nix
    ../../modules/wireless.nix
    ../../modules/rns
  ];

  # Disk
  myDisko.device = "/dev/sda";

  # Reticulum
  services.rns = {
    enable = true;
    implementation = "reticulum-go";
    interfaces = {
      "Auto Discovery" = {
        type = "AutoInterface";
        enabled = true;
        group_id = "reticulum";
        discovery_scope = "link";
        discovery_port = 29716;
        data_port = 42671;
      };
      "Quad4 TCP" = {
        type = "TCPClientInterface";
        target_host = "rns.quad4.io";
        target_port = 4242;
      };
      "Local UDP" = {
        type = "UDPInterface";
        address = "0.0.0.0:4242";
      };
    };
    openFirewall = true;
  };

  # Secrets
  sops.defaultSopsFile = ./secrets.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.secrets.root_password_hash.neededForUsers = true;

  # Users
  users.users.root.hashedPasswordFile = config.sops.secrets.root_password_hash.path;
}
