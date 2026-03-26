# Chromium with Chrome DevTools Protocol (CDP).
#
# Runs Chromium as a systemd service, listening for remote debugging
# connections via CDP (default port 9222).  Set `headless = true` to
# run in headless mode.
#
# Usage:
#
#   imports = [ ../../modules/chromium ];
#
#   services.chromium = {
#     enable = true;
#     headless = true;
#     remoteDebugging = "127.0.0.1:9222";
#     lang = "ru-RU";
#     acceptLang = "ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7";
#     timezone = "Europe/Moscow";
#   };
#
{ config, lib, pkgs, utils, ... }:

let
  cfg = config.services.chromium;

  inherit (lib)
    concatStringsSep filterAttrs mapAttrsToList mkIf
    optional optionals optionalAttrs optionalString splitString;

  # Parse "address:port" for CDP flags and firewall rule.
  rdParts   = splitString ":" cfg.remoteDebugging;
  rdAddress = builtins.elemAt rdParts 0;
  rdPort    = builtins.elemAt rdParts 1;

  gpuArgs =
    if cfg.enableGpu then
      (optional cfg.headless "--ozone-platform=headless") ++ [
        "--ignore-gpu-blocklist"
        "--disable-software-rasterizer"
        "--enable-gpu-rasterization"
        "--enable-zero-copy"
        "--use-gl=angle"
        "--use-angle=vulkan"
        "--enable-features=VaapiVideoDecoder,VaapiVideoEncoder,Vulkan,DefaultANGLEVulkan"
      ]
    else [
      "--disable-gpu"
      "--disable-software-rasterizer"
      "--disable-vulkan"
    ];

  webglArgs = {
    native      = [ ];
    swiftshader = [ "--use-gl=angle" "--use-angle=swiftshader" ];
    disable     = [ "--disable-webgl" "--disable-webgl2" ];
  }.${cfg.webglMode};

  webgpuArgs = optionals cfg.enableWebGPU [
    "--enable-unsafe-webgpu"
  ];

  # Auto-generate UA from the package version so it always matches
  # the real browser binary.
  effectiveUserAgent =
    if cfg.userAgent != null then cfg.userAgent
    else "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
       + "(KHTML, like Gecko) Chrome/${cfg.package.version} Safari/537.36";

  # Chromium only honours the *last* --disable-features flag,
  # so collect everything into a single list.
  allDisableFeatures =
    optional cfg.disableBatteryStatus "BatteryStatus"
    ++ optional cfg.disableHeadlessFlags "HeadlessMode";

  # --name=value flags derived from nullable options.
  valueFlags = filterAttrs (_: v: v != null) {
    "user-agent"    = effectiveUserAgent;
    "lang"          = cfg.lang;
    "accept-lang"   = cfg.acceptLang;
    "user-data-dir" = cfg.userDataDir;
    "proxy-server"  = cfg.proxyServer;
  };

  # Block Chromium from reaching these localhost ports.
  blockRule = p:
    let s = toString p; in
    "MAP localhost:${s} ~NOTFOUND, "
    + "MAP 127.0.0.1:${s} ~NOTFOUND, "
    + "MAP [::1]:${s} ~NOTFOUND";

  screenSize = optionalString (cfg.screenSize != null)
    "${toString cfg.screenSize.width},${toString cfg.screenSize.height}";

  # Final command line
  chromiumArgs = [
    "${cfg.package}/bin/chromium"
  ]
  # Headless + stealth
  ++ optionals cfg.headless [
    "--headless=new"
    "--disable-background-networking"
    "--disable-notifications"
    "--disable-ipc-flooding-protection"
    "--disable-blink-features=AutomationControlled"
    "--disable-infobars"
  ]
  # Hardened base
  ++ [
    "--disable-sync"
    "--disable-dbus"
    "--no-default-browser-check"
    "--disable-component-extensions-with-background-pages"
    "--password-store=basic"
    "--use-mock-keychain"
  ]
  # CDP
  ++ optionals (cfg.remoteDebugging != null) [
    "--remote-debugging-address=${rdAddress}"
    "--remote-debugging-port=${rdPort}"
  ]
  # GPU / WebGL / WebGPU
  ++ gpuArgs ++ webglArgs ++ webgpuArgs
  # disable-features (must be a single flag)
  ++ optional (allDisableFeatures != [])
    "--disable-features=${concatStringsSep "," allDisableFeatures}"
  # Screen size
  ++ optionals (screenSize != "") [
    "--ozone-override-screen-size=${screenSize}"
    "--window-size=${screenSize}"
  ]
  # WebRTC / host-rules
  ++ optional (cfg.webrtcPolicy != "default")
    "--webrtc-ip-handling-policy=${cfg.webrtcPolicy}"
  ++ optional (cfg.blockLocalPorts != [])
    "--host-rules=${concatStringsSep ", " (map blockRule cfg.blockLocalPorts)}"
  # Value flags
  ++ mapAttrsToList (n: v: "--${n}=${v}") valueFlags
  # Boolean flags
  ++ optional cfg.disableTranslate "--disable-translate"
  ++ optional cfg.noFirstRun       "--no-first-run";

in
{
  imports = [ ./options.nix ];

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    systemd.services.chromium = {
      description = "Chromium"
        + optionalString (cfg.remoteDebugging != null) " (CDP ${cfg.remoteDebugging})";

      wantedBy = [ "multi-user.target" ];
      after    = [ "network.target" ];

      environment = {
        HOME = "/var/lib/chromium";
        # Point D-Bus at a nonexistent socket so Chromium silently
        # fails to connect without spamming error logs.
        DBUS_SESSION_BUS_ADDRESS = "unix:path=/tmp/nosocket";
        DBUS_SYSTEM_BUS_ADDRESS  = "unix:path=/tmp/nosocket";
      }
      // optionalAttrs (cfg.timezone != null) { TZ = cfg.timezone; }
      // optionalAttrs (cfg.lang != null) {
        LANGUAGE = cfg.lang;
        LC_ALL   = "${builtins.replaceStrings ["-"] ["_"] cfg.lang}.UTF-8";
      };

      serviceConfig = {
        ExecStart  = utils.escapeSystemdExecArgs chromiumArgs;
        Restart    = "on-failure";
        RestartSec = 10;

        # Sandboxing
        DynamicUser      = true;
        StateDirectory   = "chromium";
        WorkingDirectory = "/var/lib/chromium";
        ProtectSystem    = "strict";
        ProtectHome      = true;
        PrivateTmp       = true;
        NoNewPrivileges  = true;
        ReadWritePaths   = [ "/var/lib/chromium" ];

        # GPU access
        SupplementaryGroups = optionals cfg.enableGpu [ "video" "render" ];
        DeviceAllow         = optionals cfg.enableGpu [ "char-drm rw" ];

        # Suppress unavoidable Chromium noise on headless systems.
        LogFilterPatterns = [
          "~dbus/"
          "~DEPRECATED_ENDPOINT"
          "~shared_memory_switch"
          "~gpu_blocklist"
          "~maxDynamic"
          "~command_buffer_proxy_impl"
        ];
      };
    };

    networking.firewall = mkIf (cfg.openFirewall && cfg.remoteDebugging != null) {
      allowedTCPPorts = [ (lib.toInt rdPort) ];
    };
  };
}
