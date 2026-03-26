{ lib, pkgs, ... }:

{
  options.services.chromium = {
    enable = lib.mkEnableOption "Chromium with CDP remote debugging";

    headless = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Run Chromium in headless mode (--headless=new, Chrome 112+).
        Uses the same rendering path as headed Chrome.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.chromium;
      defaultText = lib.literalExpression "pkgs.chromium";
      description = "The Chromium package to use.";
    };

    remoteDebugging = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "127.0.0.1:9222";
      description = ''
        CDP remote debugging endpoint in "address:port" format.
        When null, remote debugging is disabled.
      '';
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
        WebGL rendering mode.

        - "native": use real hardware GPU
        - "swiftshader": software renderer (Google SwiftShader)
        - "disable": disable WebGL entirely
      '';
    };

    enableWebGPU = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable WebGPU support (--enable-unsafe-webgpu, Vulkan backend).
        Requires `enableGpu = true` and a Vulkan-capable GPU driver.
      '';
    };

    userDataDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/var/lib/chromium/profile";
      description = ''
        Persistent user data directory for Chromium profile.
        When set, Chromium keeps cookies, localStorage, history, etc.
        across restarts.  When null, Chromium creates a temporary
        profile each launch.
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the remote debugging port in the firewall.";
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
      type = lib.types.nullOr (lib.types.submodule {
        options = {
          width = lib.mkOption {
            type = lib.types.ints.positive;
            example = 1366;
            description = "Screen width in pixels.";
          };
          height = lib.mkOption {
            type = lib.types.ints.positive;
            example = 768;
            description = "Screen height in pixels.";
          };
        };
      });
      default = null;
      example = { width = 1366; height = 768; };
      description = ''
        Virtual screen resolution.
        Sets both the Ozone screen size and the Chromium window size so that
        screen.width/screen.height match the viewport.
      '';
    };

    userAgent = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36";
      description = ''
        Override the User-Agent string.  When null (the default), a standard
        Chrome UA is auto-generated from the actual Chromium package version,
        ensuring the UA always matches the real browser binary.
      '';
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

        - "default": no restrictions
        - "default_public_interface_only": only expose public IP
        - "default_public_and_private_interfaces": expose both
        - "disable_non_proxied_udp": block non-proxied UDP
      '';
    };

    disableBatteryStatus = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Disable the Battery Status API.
        When disabled, navigator.getBattery() rejects.
      '';
    };

    disableHeadlessFlags = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Disable the HeadlessMode feature flag.
      '';
    };

    lang = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "ru-RU";
      description = ''
        Primary language for the browser UI (--lang flag).
        Also sets navigator.language and Intl defaults.
      '';
    };

    acceptLang = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7";
      description = ''
        Accept-Language header value (--accept-lang flag).
      '';
    };

    timezone = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "Europe/Moscow";
      description = ''
        Timezone for the browser process (TZ env variable).
      '';
    };

    blockLocalPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [ ];
      example = [ 22 3389 ];
      description = ''
        Block Chromium from connecting to these ports on localhost
        via --host-rules.
      '';
    };
  };
}
