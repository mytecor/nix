# SOCKS5 proxy over Reticulum (mytecor/rns-proxy).
#
# Provides two independent systemd services:
#   services.rns-proxy.server  — exit-node that relays TCP on behalf of clients
#   services.rns-proxy.client  — local SOCKS5 listener that tunnels via RNS
#
{ config, lib, inputs, ... }:

let
  cfg = config.services.rns-proxy;
  rnsCfg = config.services.rns;
  defaultPkg = inputs.rns-proxy.packages.${config.nixpkgs.hostPlatform.system}.default;

  # When the RNS module is enabled on the same host, derive the systemd
  # unit name so rns-proxy services wait for rnsd / reticulum-go.
  rnsEnabled = rnsCfg.enable;
  rnsUnit = "rns.service";
  dependsOnRns = rnsEnabled;
in
{
  options.services.rns-proxy = {
    server = {
      enable = lib.mkEnableOption "RNS SOCKS5 proxy server (exit node)";

      package = lib.mkOption {
        type = lib.types.package;
        default = defaultPkg;
        description = "The rns-proxy package to use.";
      };

      identityFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path to the persistent identity file. If null, uses the default (~/.reticulum/rns_proxy_identity).";
      };

      debug = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable verbose debug logging.";
      };
    };

    client = {
      enable = lib.mkEnableOption "RNS SOCKS5 proxy client";

      package = lib.mkOption {
        type = lib.types.package;
        default = defaultPkg;
        description = "The rns-proxy package to use.";
      };

      serverAddress = lib.mkOption {
        type = lib.types.str;
        description = "RNS destination hash of the remote server (hex string).";
      };

      listenPort = lib.mkOption {
        type = lib.types.port;
        default = 1080;
        description = "Local SOCKS5 listen port.";
      };

      debug = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable verbose debug logging.";
      };
    };
  };

  config = lib.mkMerge [
    # ── Server ──────────────────────────────────────────────────────────
    (lib.mkIf cfg.server.enable {
      environment.systemPackages = [ cfg.server.package ];

      systemd.services.rns-proxy-server = {
        description = "RNS SOCKS5 Proxy Server (exit node)";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ] ++ lib.optional dependsOnRns rnsUnit;
        requires = lib.optional dependsOnRns rnsUnit;

        serviceConfig = {
          ExecStart = lib.concatStringsSep " " ([
            "${cfg.server.package}/bin/rns-proxy"
          ] ++ lib.optional cfg.server.debug "--debug"
            ++ [ "server" ]
            ++ lib.optionals (cfg.server.identityFile != null) [
              "--identity-file" cfg.server.identityFile
            ]);

          Restart = "on-failure";
          RestartSec = 10;

          DynamicUser = true;
          StateDirectory = "rns-proxy-server";
          WorkingDirectory = "/var/lib/rns-proxy-server";
          Environment = "HOME=/var/lib/rns-proxy-server";

          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          NoNewPrivileges = true;
          ReadWritePaths = [ "/var/lib/rns-proxy-server" ];
        };
      };
    })

    # ── Client ──────────────────────────────────────────────────────────
    (lib.mkIf cfg.client.enable {
      environment.systemPackages = [ cfg.client.package ];

      systemd.services.rns-proxy-client = {
        description = "RNS SOCKS5 Proxy Client";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ] ++ lib.optional dependsOnRns rnsUnit;
        requires = lib.optional dependsOnRns rnsUnit;

        serviceConfig = {
          ExecStart = lib.concatStringsSep " " ([
            "${cfg.client.package}/bin/rns-proxy"
          ] ++ lib.optional cfg.client.debug "--debug"
            ++ [
              "client"
              "--server" cfg.client.serverAddress
              "--port" (toString cfg.client.listenPort)
            ]);

          Restart = "on-failure";
          RestartSec = 10;

          DynamicUser = true;
          StateDirectory = "rns-proxy-client";
          WorkingDirectory = "/var/lib/rns-proxy-client";
          Environment = "HOME=/var/lib/rns-proxy-client";

          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          NoNewPrivileges = true;
          ReadWritePaths = [ "/var/lib/rns-proxy-client" ];
        };
      };
    })
  ];
}
