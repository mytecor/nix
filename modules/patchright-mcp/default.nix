# Patchright MCP — browser automation MCP server using Patchright.
#
# Runs a Patchright MCP server as a systemd service, connecting to an
# existing headless Chromium instance via CDP (Chrome DevTools Protocol).
#
# Usage:
#
#   imports = [ ../../modules/patchright-mcp ];
#
#   services.patchright-mcp = {
#     enable = true;
#     cdpEndpoint = "http://127.0.0.1:9222";
#     port = 8931;
#   };
#
{ config, lib, pkgs, utils, ... }:

let
  cfg = config.services.patchright-mcp;

  # Bundled stealth.js is always included first, then user-supplied scripts.
  allInitScripts = [ ./stealth.js ] ++ cfg.initScripts;

  # Only pass --headless when Patchright manages its own browser.
  # When connecting to an existing CDP endpoint the browser is already
  # running and the flag is meaningless (and leaks headless fingerprints
  # into Patchright's own launch logic).
  #
  # Each element is escaped for systemd's ExecStart word-splitting rules
  # so that values containing spaces (e.g. user-agent strings) or globs
  # (e.g. --allowed-hosts "*") are passed correctly.
  args = utils.escapeSystemdExecArgs ([
    "${cfg.package}/bin/mcp-server-patchright"
  ] ++ lib.optional (cfg.cdpEndpoint == null)
    "--headless"
    ++ lib.optional (cfg.cdpEndpoint != null)
    "--cdp-endpoint=${cfg.cdpEndpoint}"
    ++ lib.optional (cfg.port != null)
    "--port=${toString cfg.port}"
    ++ lib.optional (cfg.host != null)
    "--host=${cfg.host}"
    ++ lib.optional (cfg.browser != null)
    "--browser=${cfg.browser}"
    ++ lib.optional (cfg.viewportSize != null)
    "--viewport-size=${cfg.viewportSize}"
    ++ lib.optional (cfg.userAgent != null)
    "--user-agent=${cfg.userAgent}"
    ++ lib.optional (cfg.proxyServer != null)
    "--proxy-server=${cfg.proxyServer}"
    ++ lib.optional cfg.ignoreHttpsErrors
    "--ignore-https-errors"
    ++ lib.optional cfg.blockServiceWorkers
    "--block-service-workers"
    ++ lib.optionals (cfg.caps != [])
    [ "--caps=${lib.concatStringsSep "," cfg.caps}" ]
    ++ lib.optionals (cfg.openFirewall && cfg.allowedHosts != null)
    [ "--allowed-hosts" cfg.allowedHosts ]
    ++ lib.concatMap (s: [ "--init-script" s ]) allInitScripts
    ++ cfg.extraArgs
  );

in
{
  options.services.patchright-mcp = {
    enable = lib.mkEnableOption "Patchright MCP server (browser automation via CDP)";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../../packages/patchright-mcp.nix { };
      defaultText = lib.literalExpression "pkgs.callPackage ../../packages/patchright-mcp.nix { }";
      description = "The patchright-mcp package to use.";
    };

    cdpEndpoint = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "http://127.0.0.1:9222";
      description = "CDP endpoint to connect to an existing browser instance.";
    };

    port = lib.mkOption {
      type = lib.types.nullOr lib.types.port;
      default = 8931;
      description = "Port for the MCP HTTP/SSE transport. Set to null for stdio mode.";
    };

    host = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "127.0.0.1";
      description = "Address to bind the MCP server to.";
    };

    browser = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ "chrome" "firefox" "webkit" "msedge" ]);
      default = null;
      description = "Browser to use (only relevant without cdpEndpoint).";
    };

    viewportSize = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "1280x720";
      description = "Browser viewport size in pixels (e.g. '1280x720').";
    };

    userAgent = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Custom user agent string.";
    };

    proxyServer = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "socks5://127.0.0.1:1080";
      description = "Proxy server URL.";
    };

    ignoreHttpsErrors = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Ignore HTTPS errors.";
    };

    blockServiceWorkers = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Block service workers.";
    };

    caps = lib.mkOption {
      type = lib.types.listOf (lib.types.enum [ "vision" "pdf" "devtools" ]);
      default = [ ];
      description = "Additional capabilities to enable.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the MCP port in the firewall.";
    };

    allowedHosts = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = if cfg.openFirewall then "*" else null;
      defaultText = lib.literalExpression ''if openFirewall then "*" else null'';
      description = "Allowed hosts for DNS rebinding protection. Defaults to `\"*\"` when `openFirewall` is enabled.";
    };

    initScripts = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = ''
        JavaScript files evaluated via --init-script before any page script.
        Useful for stealth patches (screen spoofing, API overrides, etc.).
        Each path is passed as a separate --init-script argument.
      '';
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra command-line arguments passed to patchright-mcp.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.patchright-mcp = {
      description = "Patchright MCP Server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ]
        ++ lib.optional (config.services.chromium.enable or false)
        "chromium.service";
      requires =
        lib.optional (config.services.chromium.enable or false)
        "chromium.service";

      serviceConfig = {
        ExecStart = args;
        Restart = "on-failure";
        RestartSec = 5;

        DynamicUser = true;
        StateDirectory = "patchright-mcp";
        WorkingDirectory = "/var/lib/patchright-mcp";
        Environment = [
          "HOME=/var/lib/patchright-mcp"
          "PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1"
        ];

        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
        ReadWritePaths = [ "/var/lib/patchright-mcp" ];
      };
    };

    networking.firewall = lib.mkIf (cfg.openFirewall && cfg.port != null) {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}
