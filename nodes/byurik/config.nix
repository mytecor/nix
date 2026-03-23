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
    webrtcPolicy = "default"; # unrestricted — avoids "WebRTC disabled" fingerprint
    disableBatteryStatus = true; # prevent 100%/charging headless fingerprint
    disableHeadlessFlags = true; # disable HeadlessMode feature flag
    webglMode = "native"; # keep real GPU; change to "swiftshader" to hide HW model
    blockLocalPorts = [ 22 3389 ]; # block port scanning (SSH, RDP) from websites
    userDataDir = "/var/lib/headless-chromium/profile"; # persistent profile (anti-incognito)
    screenSize = "1366x768"; # sets both screen resolution and window size

    # User-Agent is auto-generated from the actual Chromium package version.
    # No need to hardcode — this prevents version mismatch between UA and
    # real JS/CSS feature set (which detectors like CreepJS check).
    # Uncomment to override:
    # userAgent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36";

    # Locale & timezone — should be consistent with the IP geo.
    lang = "ru-RU";
    acceptLang = "ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7";
    timezone = "Europe/Moscow";

    # Install common fonts so the font fingerprint looks realistic.
    # CreepJS uses FontFace.load() to test ~51 specific fonts; document.fonts.check()
    # gives false positives due to fallback.  corefonts provides the Microsoft
    # families (Arial, Times New Roman, Verdana, etc.) that Linux normally lacks.
    fontPackages = with pkgs; [
      corefonts # Arial, Times New Roman, Verdana, Georgia, Comic Sans, Impact, Trebuchet, Courier New, etc.
      liberation_ttf # Liberation family (metric-compatible with Arial, Times, Courier)
      noto-fonts # Noto Sans/Serif (wide Unicode coverage)
      noto-fonts-cjk-sans # CJK fonts (very common on desktop Linux)
      noto-fonts-color-emoji # Emoji support
      dejavu_fonts # DejaVu (standard Linux fallback)
      roboto # Roboto (common on Linux/Android)
      ubuntu-classic # Ubuntu font family
      freefont_ttf # GNU FreeFont (FreeSerif, FreeSans, FreeMono)
      source-code-pro # Adobe Source Code Pro (popular dev font)
      source-sans-pro # Adobe Source Sans (common on web)
      source-serif-pro # Adobe Source Serif
      inter # Inter (modern UI font)
      fira # Fira Sans/Mono (Mozilla)
      fira-code # Fira Code (ligature monospace, tested by CreepJS)
      hack-font # Hack (popular monospace)
      cantarell-fonts # GNOME default UI font
      dina-font # Dina programming font
      open-sans # Open Sans (very popular)
      lato # Lato (common Google Font)
      # Note: Calibri/Cambria/Consolas/Segoe UI (vistafonts) are not in nixpkgs.
      # corefonts covers the most commonly tested MS fonts.
    ];
  };

  # Patchright MCP (browser automation via existing CDP)
  services.patchright-mcp = {
    enable = true;
    cdpEndpoint = "http://127.0.0.1:9222";
    port = 8931;
    host = "0.0.0.0";
    openFirewall = true;

    # NOTE: --user-agent and --viewport-size are ignored when using
    # --cdp-endpoint (CdpContextFactory uses browser.contexts()[0]
    # directly and never applies contextOptions).  All browser-level
    # settings must be configured in headless-chromium above.

    # Stealth init script — patches JS-level headless fingerprints
    # (screen dimensions, battery API, permissions, etc.) that cannot
    # be fixed via Chromium CLI flags alone.
    initScripts = [ ../../modules/patchright-mcp/stealth.js ];
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
