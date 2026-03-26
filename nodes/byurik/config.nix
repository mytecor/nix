{ config, pkgs, ... }:

{
  imports = [
    ../../hardware/intel-n100.nix
    ../../profiles/worker.nix
    ../../modules/wireless.nix
    ../../modules/rns
    ../../modules/rns-proxy
    ../../modules/fonts
    ../../modules/chromium
    ../../modules/patchright-mcp
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
    destination = "7959c25d1fe14de475bfaec114a58cf3"; # hex hash of the remote RNS exit server
    listenAddress = "0.0.0.0:1080";
    openFirewall = true;
  };

  # Chromium (CDP on localhost)
  services.chromium = {
    enable = true;
    headless = true;
    remoteDebugging = "127.0.0.1:9222";
    enableGpu = true;
    enableWebGPU = true;
    webglMode = "native"; # keep real GPU; change to "swiftshader" to hide HW model
    userDataDir = "/var/lib/chromium/profile"; # persistent profile
    screenSize = { width = 1366; height = 768; };
  } // import ../../modules/chromium/stealth.nix {
    blockLocalPorts = [ 22 3389 ]; # block port scanning (SSH, RDP) from websites
    lang = "ru-RU";
    acceptLang = "ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7";
    timezone = "Europe/Moscow";
  };

  # Patchright MCP (browser automation via existing CDP)
  services.patchright-mcp = {
    enable = true;
    cdpEndpoint = "http://127.0.0.1:9222";
    port = 8931;
    host = "0.0.0.0";
    openFirewall = true;
  };

  # Locale — must be generated so LC_ALL=ru_RU.UTF-8 works in Chromium
  i18n.supportedLocales = [ "ru_RU.UTF-8/UTF-8" "en_US.UTF-8/UTF-8" ];

  # Secrets
  sops.defaultSopsFile = ./secrets.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.secrets.root_password_hash.neededForUsers = true;

  # Users
  users.users.root.hashedPasswordFile = config.sops.secrets.root_password_hash.path;
}
