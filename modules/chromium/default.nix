# Chromium with Chrome DevTools Protocol (CDP).
#
# Runs Chromium as a systemd service, listening for remote debugging
# connections via CDP (default port 9222).  Set `headless = true` to
# run in headless mode.
#
# Anti-detect options (userAgent, webrtcPolicy, lang, timezone, etc.)
# are available directly under services.chromium.*.
#
# Usage:
#
#   imports = [ ../../modules/chromium ];
#
#   services.chromium = {
#     enable = true;
#     headless = true;
#     port = 9222;
#     disableBatteryStatus = true;
#     disableHeadlessFlags = true;
#     lang = "ru-RU";
#     acceptLang = "ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7";
#     timezone = "Europe/Moscow";
#   };
#
{ config, lib, pkgs, utils, ... }:

let
  cfg = config.services.chromium;

  # Helper: emit "--name=value" when value is non-null, empty list otherwise.
  optFlag = name: value:
    lib.optional (value != null) "--${name}=${value}";

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
  gpuDisableFeatures = [
    "Vulkan" "VulkanFromANGLE" "UseChromeOSDirectVideoDecoder"
  ] ++ lib.optional cfg.enableGpu "DefaultANGLEVulkan";

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

  # --- Anti-detect ---

  # Auto-generate User-Agent from the actual Chromium package version so
  # the UA always matches the real browser binary.
  effectiveUserAgent =
    if cfg.userAgent != null
    then cfg.userAgent
    else "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/${cfg.package.version} Safari/537.36";

  blockLocalPortsArgs = lib.optional (cfg.blockLocalPorts != [])
    "--host-rules=${lib.concatStringsSep ", " (map (p:
      "MAP localhost:${toString p} ~NOTFOUND, MAP 127.0.0.1:${toString p} ~NOTFOUND, MAP [::1]:${toString p} ~NOTFOUND"
    ) cfg.blockLocalPorts)}";

  # Anti-detect CLI args.
  antiDetectArgs = [
    "--disable-blink-features=AutomationControlled"
    "--disable-infobars"
    "--user-agent=${effectiveUserAgent}"
  ] ++ lib.optional (cfg.webrtcPolicy != "default")
       "--webrtc-ip-handling-policy=${cfg.webrtcPolicy}"
    ++ optFlag "lang" cfg.lang
    ++ optFlag "accept-lang" cfg.acceptLang
    ++ blockLocalPortsArgs;

  # Anti-detect --disable-features entries.
  antiDetectDisableFeatures =
    lib.optional cfg.disableBatteryStatus "BatteryStatus"
    ++ lib.optional cfg.disableHeadlessFlags "HeadlessMode";

  # --- End anti-detect ---

  # Collect ALL --disable-features into a single flag.  Chromium only
  # honours the *last* --disable-features on the command line, so having
  # multiple flags causes earlier ones to be silently ignored.
  allDisableFeatures = gpuDisableFeatures
    ++ antiDetectDisableFeatures;

  disableFeaturesArgs = lib.optional (allDisableFeatures != [])
    "--disable-features=${lib.concatStringsSep "," allDisableFeatures}";

  # Both flags are needed so that screen.width/height matches the viewport:
  #   --ozone-override-screen-size  -> sets screen.width / screen.height
  #   --window-size                 -> sets the window (and thus viewport) size
  # NOTE: Both flags use comma-separated format: "1366,768" (not "1366x768").
  screenArgs = lib.optionals (cfg.screenSize != null) (
    let commaSep = "${toString cfg.screenSize.width},${toString cfg.screenSize.height}";
    in [
      "--ozone-override-screen-size=${commaSep}"
      "--window-size=${commaSep}"
    ]
  );

  # Build the argument list.  utils.escapeSystemdExecArgs handles quoting
  # of arguments that contain spaces, percent signs, dollar signs, etc.
  chromiumArgs = [
    "${cfg.package}/bin/chromium"
  ] ++ lib.optional cfg.headless
    # Use --headless=new (Chrome 112+): same rendering path as
    # headed Chrome, fewer fingerprints than classic --headless.
    "--headless=new"
  ++ [
    "--no-sandbox"
    "--disable-dev-shm-usage"
    "--disable-background-networking"
    "--disable-sync"
    "--disable-notifications"
    "--disable-dbus"
    "--no-default-browser-check"
    "--disable-component-extensions-with-background-pages"
    "--disable-ipc-flooding-protection"
    "--password-store=basic"
    "--use-mock-keychain"
    "--remote-debugging-address=127.0.0.1"
    "--remote-debugging-port=${toString cfg.port}"
  ] ++ gpuArgs
    ++ webglArgs
    ++ disableFeaturesArgs
    ++ screenArgs
    ++ optFlag "user-data-dir" cfg.userDataDir
    ++ optFlag "proxy-server" cfg.proxyServer
    ++ lib.optional cfg.disableTranslate "--disable-translate"
    ++ lib.optional cfg.noFirstRun "--no-first-run"
    ++ antiDetectArgs;

in
{
  imports = [ ./options.nix ];

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    systemd.services.chromium = {
      description = "Chromium (CDP)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      # Environment as an attrset — cleaner than "KEY=VALUE" strings
      # and lets NixOS handle escaping.
      environment = {
        HOME = "/var/lib/chromium";
        # Point D-Bus at a nonexistent socket inside PrivateTmp
        # so Chromium silently fails to connect without error logs.
        DBUS_SESSION_BUS_ADDRESS = "unix:path=/tmp/nosocket";
        DBUS_SYSTEM_BUS_ADDRESS = "unix:path=/tmp/nosocket";
      } // lib.optionalAttrs (cfg.timezone != null) {
        TZ = cfg.timezone;
      } // lib.optionalAttrs (cfg.lang != null) (
        # Locale env vars so Intl APIs (DateTimeFormat, NumberFormat, etc.)
        # default to the configured language instead of the system locale.
        # NOTE: glibc expects underscore (ru_RU), not BCP-47 dash (ru-RU).
        let glibcLocale = builtins.replaceStrings ["-"] ["_"] cfg.lang;
        in {
          LANGUAGE = cfg.lang;
          LC_ALL = "${glibcLocale}.UTF-8";
        }
      );

      serviceConfig = {
        ExecStart = utils.escapeSystemdExecArgs chromiumArgs;
        Restart = "on-failure";
        RestartSec = 10;

        DynamicUser = true;
        StateDirectory = "chromium";
        WorkingDirectory = "/var/lib/chromium";

        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
        ReadWritePaths = [ "/var/lib/chromium" ];

        # Suppress unavoidable Chromium noise on headless systems.
        LogFilterPatterns = [
          "~dbus/"
          "~DEPRECATED_ENDPOINT"
          "~shared_memory_switch"
          "~gpu_blocklist"
          "~maxDynamic"
        ];
        SupplementaryGroups = lib.optionals cfg.enableGpu [ "video" "render" ];
        DeviceAllow = lib.optionals cfg.enableGpu [ "char-drm rw" ];
      };
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}
