{ config, pkgs, ... }:

{
  imports = [
    ../../hardware/intel-n100.nix
    ../../profiles/worker.nix
    ../../modules/wireless.nix
    ../../modules/rns
    ../../modules/rns-proxy
    ../../modules/headless-chromium
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

  # Headless Chromium (CDP on localhost)
  services.headless-chromium = {
    enable = true;
    port = 9222;
    enableGpu = true;
    disableWebrtcLeak = true; # prevent real IP leak via WebRTC
    disableBatteryStatus = true; # prevent 100%/charging headless fingerprint
    disableHeadlessFlags = true; # disable HeadlessMode feature flag
    webglMode = "native"; # keep real GPU; change to "swiftshader" to hide HW model
    userDataDir = "/var/lib/headless-chromium/profile"; # persistent profile (anti-incognito)
    screenSize = "1366x768"; # sets both screen resolution and window size

    # Remove "HeadlessChrome" from User-Agent — the #1 headless tell.
    # Must match the real Chrome version on the system.
    userAgent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36";

    # Locale & timezone — should be consistent with the IP geo.
    lang = "ru-RU";
    acceptLang = "ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7";
    timezone = "Europe/Moscow";

    # Install common fonts so the font fingerprint looks realistic (not 1/51).
    fontPackages = with pkgs; [
      liberation_ttf # Liberation family (metric-compatible with Arial, Times, Courier)
      noto-fonts # Noto Sans/Serif (wide Unicode coverage)
      noto-fonts-color-emoji # Emoji support
      dejavu_fonts # DejaVu (already present, but explicit)
      roboto # Roboto (common on Linux)
      ubuntu-classic # Ubuntu fonts
      freefont_ttf # GNU FreeFont
    ];
  };

  # Patchright MCP (browser automation via existing CDP)
  services.patchright-mcp = {
    enable = true;
    cdpEndpoint = "http://127.0.0.1:9222";
    port = 8931;
    host = "0.0.0.0";
    openFirewall = true;

    # Override UA and viewport at the Patchright level too, in case
    # the MCP server creates new contexts/pages.
    userAgent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36";
    viewportSize = "1366x768";
  };

  # Secrets
  sops.defaultSopsFile = ./secrets.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.secrets.root_password_hash.neededForUsers = true;

  # Users
  users.users.root.hashedPasswordFile = config.sops.secrets.root_password_hash.path;
}
