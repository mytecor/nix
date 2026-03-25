{ lib, pkgs, ... }:

{
  options.services.chromium = {
    enable = lib.mkEnableOption "Chromium with CDP remote debugging";

    headless = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Run Chromium in headless mode (--headless=new, Chrome 112+).
        Uses the same rendering path as headed Chrome with fewer fingerprints.
      '';
    };

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
        screen.width/screen.height match the viewport — avoiding the classic
        headless tell where viewport > screen.
      '';
    };

    # --- Anti-detect options ---

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

    blockLocalPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [ ];
      example = [ 22 3389 ];
      description = ''
        Block Chromium from connecting to these ports on localhost.
        Websites like BrowserScan probe local ports (SSH, RDP, etc.)
        via WebSocket to fingerprint the host.  Blocking access to
        these ports prevents detection of running services.
      '';
    };
  };
}
