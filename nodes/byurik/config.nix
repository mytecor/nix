{ config, ... }:

{
  imports = [
    ../../hardware/intel-n100.nix
    ../../profiles/worker.nix
    ../../modules/wireless.nix
    ../../modules/rns
    ../../modules/rns-proxy
  ];

  # Disk
  myDisko.device = "/dev/sda";

  # Reticulum
  services.rns = {
    enable = true;
    logLevel = 7;
    implementation = "rnsd";
    interfaces = {
      "Auto Discovery" = {
        type = "AutoInterface";
        enabled = true;
        discovery_scope = "link";
        discovery_port = 29716;
        data_port = 42671;
      };
      # "Quad4 TCP" = {
      #   type = "TCPClientInterface";
      #   target_host = "rns.quad4.io";
      #   target_port = 4242;
      # };
      # "Local UDP" = {
      #   type = "UDPInterface";
      #   address = "0.0.0.0:4242";
      # };
    };
    openFirewall = true;
  };

  # SOCKS5 proxy over Reticulum
  services.rns-proxy.client = {
    enable = true;
    serverAddress = "7959c25d1fe14de475bfaec114a58cf3"; # hex hash of the remote RNS exit server
    listenPort = 1080;
  };

  # Secrets
  sops.defaultSopsFile = ./secrets.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.secrets.root_password_hash.neededForUsers = true;

  # Users
  users.users.root.hashedPasswordFile = config.sops.secrets.root_password_hash.path;
}
