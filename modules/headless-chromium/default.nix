# Headless Chromium with Chrome DevTools Protocol (CDP).
#
# Runs Chromium in headless mode as a systemd service, listening for
# remote debugging connections via CDP (default port 9222).
#
# Usage:
#
#   imports = [ ../../modules/headless-chromium ];
#
#   services.headless-chromium = {
#     enable = true;
#     port = 9222;
#   };
#
{ config, lib, pkgs, ... }:

let
  cfg = config.services.headless-chromium;

  gpuArgs = if cfg.enableGpu then [
    "--ozone-platform=headless"
    "--use-gl=angle"
    "--use-angle=gles-egl"
    "--enable-gpu-rasterization"
    "--enable-zero-copy"
    "--enable-features=VaapiVideoDecoder,VaapiVideoEncoder"
  ] else [
    "--disable-gpu"
    "--disable-software-rasterizer"
    "--disable-vulkan"
  ];

  # Features that must be disabled.  Chromium only honours the *last*
  # --disable-features flag, so we collect everything into one list and
  # emit a single flag.
  gpuDisableFeatures = if cfg.enableGpu then [
    "UseChromeOSDirectVideoDecoder" "Vulkan" "VulkanFromANGLE" "DefaultANGLEVulkan"
  ] else [
    "Vulkan" "VulkanFromANGLE" "UseChromeOSDirectVideoDecoder"
  ];

  webglArgs = {
    "native" = [ ]; # use whatever GPU is present (real hardware fingerprint)
    "swiftshader" = [
      "--use-gl=angle"
      "--use-angle=swiftshader"
    ];
    "disable" = [
      "--disable-webgl"
      "--disable-webgl2"
    ];
  }.${cfg.webglMode};

  webrtcArgs = lib.optional (cfg.webrtcPolicy != "default")
    "--webrtc-ip-handling-policy=${cfg.webrtcPolicy}";

  # Collect ALL --disable-features into a single flag.  Chromium only
  # honours the *last* --disable-features on the command line, so having
  # multiple flags causes earlier ones to be silently ignored.
  allDisableFeatures = gpuDisableFeatures
    ++ lib.optional cfg.disableBatteryStatus "BatteryStatus"
    ++ lib.optional cfg.disableHeadlessFlags "HeadlessMode";
  disableFeaturesArgs = lib.optional (allDisableFeatures != [])
    "--disable-features=${lib.concatStringsSep "," allDisableFeatures}";

  # Always use --headless=new (Chrome 112+): same rendering path as headed
  # Chrome, fewer fingerprints than classic --headless.
  headlessArg = "--headless=new";

  # Derive the Chromium major version from the package.  This is used to
  # auto-generate the User-Agent string when userAgent is null, ensuring
  # the UA always matches the actual browser binary.
  chromiumVersion = cfg.package.version or "0.0.0.0";
  chromiumMajor = builtins.head (builtins.split "\\." chromiumVersion);

  effectiveUserAgent = if cfg.userAgent != null
    then cfg.userAgent
    else "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/${chromiumVersion} Safari/537.36";

  # Override the User-Agent string to remove "HeadlessChrome" — the single
  # most obvious headless tell.  The default auto-generates a UA from the
  # actual Chromium package version to avoid version mismatches.
  userAgentArgs = [ "--user-agent=${effectiveUserAgent}" ];

  # Language / locale flags.  Without these, headless Chrome sends no
  # Accept-Language header and navigator.language defaults to "en-US" which
  # may not match the expected locale for the IP/timezone.
  langArgs = lib.optional (cfg.lang != null)
    "--lang=${cfg.lang}"
    ++ lib.optional (cfg.acceptLang != null)
    "--accept-lang=${cfg.acceptLang}";

  # Timezone is controlled via the TZ environment variable rather than a
  # Chromium flag — Chromium inherits timezone from the OS/env.
  timezoneEnv = lib.optional (cfg.timezone != null)
    "TZ=${cfg.timezone}";

  userDataDirArgs = lib.optional (cfg.userDataDir != null)
    "--user-data-dir=${cfg.userDataDir}";

  # Both flags are needed so that screen.width/height matches the viewport:
  #   --ozone-override-screen-size  → sets screen.width / screen.height
  #   --window-size                 → sets the window (and thus viewport) size
  # NOTE: Both flags use comma-separated format: "1366,768" (not "1366x768").
  # The ozone flag is unreliable on some Chromium versions (known regression),
  # so JS-level screen patching via init-script is also recommended.
  screenArgs = lib.optionals (cfg.screenSize != null) (
    let commaSep = builtins.replaceStrings [ "x" ] [ "," ] cfg.screenSize;
    in [
      "--ozone-override-screen-size=${commaSep}"
      "--window-size=${commaSep}"
    ]
  );

  # Build the argument list.  We keep it as a list so that the systemd
  # ExecStart escaping can properly quote arguments that contain spaces
  # (e.g. the --user-agent string).
  chromiumArgsList = [
    "${cfg.package}/bin/chromium"
    headlessArg
    "--no-sandbox"
    "--disable-dev-shm-usage"
    "--disable-background-networking"
    "--disable-blink-features=AutomationControlled"
    "--disable-sync"
    "--disable-notifications"
    "--disable-dbus"
    "--no-default-browser-check"
    "--disable-infobars"
    "--disable-component-extensions-with-background-pages"
    "--disable-ipc-flooding-protection"
    "--password-store=basic"
    "--use-mock-keychain"
    "--remote-debugging-address=127.0.0.1"
    "--remote-debugging-port=${toString cfg.port}"
  ] ++ gpuArgs
    ++ webglArgs
    ++ webrtcArgs
    ++ disableFeaturesArgs
    ++ userAgentArgs
    ++ langArgs
    ++ userDataDirArgs
    ++ screenArgs
    ++ lib.optional (cfg.proxyServer != null)
    "--proxy-server=${cfg.proxyServer}"
    ++ lib.optional cfg.disableTranslate
    "--disable-translate"
    ++ lib.optional cfg.noFirstRun
    "--no-first-run"
    ++ lib.optional (cfg.blockLocalPorts != [])
    "--host-rules=${lib.concatStringsSep ", " (map (p:
      "MAP localhost:${toString p} ~NOTFOUND, MAP 127.0.0.1:${toString p} ~NOTFOUND, MAP [::1]:${toString p} ~NOTFOUND"
    ) cfg.blockLocalPorts)}"
    ++ cfg.extraArgs;

  # Escape each argument for systemd ExecStart: double-quote any
  # argument that contains characters special to systemd's command-line
  # parser (spaces, quotes, semicolons, percent signs, etc.).
  escapeForSystemd = arg:
    if lib.hasInfix " " arg
       || lib.hasInfix "\"" arg
       || lib.hasInfix ";" arg
       || lib.hasInfix "%" arg
    then "\"${lib.replaceStrings ["\"" "%" "\\"] ["\\\"" "%%" "\\\\"] arg}\""
    else arg;

  chromiumArgs = lib.concatStringsSep " " (map escapeForSystemd chromiumArgsList);

in
{
  options.services.headless-chromium = {
    enable = lib.mkEnableOption "Headless Chromium with CDP remote debugging";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.chromium;
      defaultText = lib.literalExpression "pkgs.chromium";
      description = "The Chromium package to use.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 9222;
      description = "CDP remote debugging port.";
    };

    enableGpu = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable GPU acceleration (requires hardware.graphics and working DRI).";
    };

    webglMode = lib.mkOption {
      type = lib.types.enum [ "native" "swiftshader" "disable" ];
      default = "native";
      description = ''
        WebGL rendering mode. Controls the GPU renderer fingerprint visible
        to websites via UNMASKED_VENDOR_WEBGL / UNMASKED_RENDERER_WEBGL.

        - "native": use real hardware GPU (exposes actual GPU model)
        - "swiftshader": software renderer (shows "Google SwiftShader")
        - "disable": disable WebGL entirely (absence is itself a fingerprint)
      '';
    };

    disableWebrtcLeak = lib.mkOption {
      type = lib.types.bool;
      default = false;
      visible = false;
      description = "Deprecated: use webrtcPolicy instead.";
    };

    webrtcPolicy = lib.mkOption {
      type = lib.types.enum [
        "default"
        "default_public_interface_only"
        "default_public_and_private_interfaces"
        "disable_non_proxied_udp"
      ];
      default = "default";
      description = ''
        WebRTC IP handling policy.

        - "default": no restrictions (leaks local + public IPs)
        - "default_public_interface_only": WebRTC works but only
          exposes the public IP — hides local/VPN IPs.  Looks natural
          to detectors (WebRTC is not "disabled") while preventing
          the most common leak vector.
        - "default_public_and_private_interfaces": expose both
        - "disable_non_proxied_udp": fully block non-proxied UDP
          (shows as "WebRTC: disabled" — suspicious fingerprint)
      '';
    };

    disableBatteryStatus = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Disable the Battery Status API.  In headless mode the API always
        returns level=1 charging=true which is a known fingerprint.
        Disabling it makes navigator.getBattery() reject — consistent with
        desktop machines that have no battery.
      '';
    };

    disableHeadlessFlags = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Disable the HeadlessMode feature flag.  This prevents JavaScript
        from detecting headless mode via internal Chrome feature flags.
      '';
    };

    userAgent = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36";
      description = ''
        Override the User-Agent string.  When null (the default), a standard
        Chrome UA is auto-generated from the actual Chromium package version,
        ensuring the UA always matches the real browser binary.  This avoids
        the common pitfall where a hardcoded UA drifts out of sync with the
        Chromium version in nixpkgs.
      '';
    };

    lang = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "ru-RU";
      description = ''
        Primary language for the browser UI (--lang flag).
        Also affects navigator.language and Intl defaults.
      '';
    };

    acceptLang = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7";
      description = ''
        Accept-Language header value (--accept-lang flag).
        Controls which languages websites see in the HTTP request.
      '';
    };

    timezone = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "Europe/Moscow";
      description = ''
        Timezone for the browser process (via TZ env variable).
        Chromium inherits timezone from the OS environment.
        Should match the locale/IP for consistency.
      '';
    };

    fontPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = lib.literalExpression ''
        with pkgs; [
          corefonts
          liberation_ttf
          noto-fonts
          noto-fonts-color-emoji
        ]
      '';
      description = ''
        Font packages to install system-wide.  Headless Linux systems
        typically have very few fonts (often just DejaVu), which is a
        strong fingerprint.  Adding common fonts (Liberation, Noto,
        corefonts) makes the font fingerprint realistic.
      '';
    };

    userDataDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/var/lib/headless-chromium/profile";
      description = ''
        Persistent user data directory for Chromium profile.
        When set, Chromium keeps cookies, localStorage, history, etc.
        across restarts — avoiding the "incognito/clean profile" fingerprint.
        When null, Chromium creates a temporary profile each launch.
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the CDP port in the firewall.";
    };

    proxyServer = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "socks5://127.0.0.1:1080";
      description = "Proxy server URL (e.g. socks5://127.0.0.1:1080).";
    };

    disableTranslate = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Disable the translate popup.";
    };

    noFirstRun = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Skip the first-run wizard.";
    };

    screenSize = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "1366x768";
      description = ''
        Virtual screen resolution as 'WxH' (e.g. '1920x1080').
        Sets both the Ozone screen size and the Chromium window size so that
        screen.width/screen.height match the viewport — avoiding the classic
        headless tell where viewport > screen.
      '';
    };

    blockLocalPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [ ];
      example = [ 22 3389 ];
      description = ''
        Block Chromium from connecting to these ports on localhost.
        Websites like BrowserScan probe local ports (SSH, RDP, etc.)
        via WebSocket to fingerprint the host.  Blocking access to
        these ports prevents detection of running services.
        Uses iptables owner-based filtering on the Chromium user.
      '';
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra command-line arguments passed to Chromium.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    # Install requested font packages so Chromium can use them.
    # Without fonts, the font fingerprint is a dead giveaway (1/51 fonts).
    fonts.packages = cfg.fontPackages;

    systemd.services.headless-chromium = {
      description = "Headless Chromium (CDP)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        ExecStart = chromiumArgs;
        Restart = "on-failure";
        RestartSec = 10;

        DynamicUser = true;
        StateDirectory = "headless-chromium";
        WorkingDirectory = "/var/lib/headless-chromium";
        Environment = [
          "HOME=/var/lib/headless-chromium"
          # Point D-Bus at a nonexistent socket inside PrivateTmp
          # so Chromium silently fails to connect without error logs.
          "DBUS_SESSION_BUS_ADDRESS=unix:path=/tmp/nosocket"
          "DBUS_SYSTEM_BUS_ADDRESS=unix:path=/tmp/nosocket"
        ] ++ timezoneEnv
          # Set locale env vars so Intl APIs (DateTimeFormat, NumberFormat, etc.)
          # default to the configured language instead of the system locale.
          # This fixes the "language mismatch" detection on BrowserScan/CreepJS.
          # NOTE: glibc expects underscore (ru_RU), not BCP-47 dash (ru-RU).
          ++ lib.optionals (cfg.lang != null) (
            let glibcLocale = builtins.replaceStrings ["-"] ["_"] cfg.lang;
            in [
              "LANGUAGE=${cfg.lang}"
              "LC_ALL=${glibcLocale}.UTF-8"
            ]
          );

        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
        ReadWritePaths = [ "/var/lib/headless-chromium" ];

        # Suppress unavoidable Chromium noise on headless systems.
        LogFilterPatterns = [
          "~dbus/"
          "~DEPRECATED_ENDPOINT"
          "~shared_memory_switch"
          "~gpu_blocklist"
          "~maxDynamic"
        ];
        SupplementaryGroups = lib.optionals cfg.enableGpu [ "video" "render" ];
        DeviceAllow = lib.optionals cfg.enableGpu [
          "char-drm rw"
        ];
      };
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}
