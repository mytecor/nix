# Unified Reticulum Network Stack module.
#
# Usage:
#
#   imports = [ ../../modules/rns ];
#
#   services.rns = {
#     enable = true;
#     implementation = "rnsd";
#     interfaces = { ... };
#   };
#
{ config, lib, pkgs, ... }:

let
  cfg = config.services.rns;
  shared = import ./options.nix { inherit lib; };

  reticulum-go-pkg = pkgs.callPackage ../../packages/reticulum-go.nix { };

  # All implementation-specific parameters in one place.
  impls = {
    reticulum-go = {
      serviceName = "reticulum-go";
      configDir = ".reticulum-go";
      mkConfigFile = shared.mkConfigFileGo;
      defaultPackage = reticulum-go-pkg;
      execStart = "${cfg.package}/bin/reticulum-go";
    };
    rnsd = {
      serviceName = "rnsd";
      configDir = ".reticulum";
      mkConfigFile = shared.mkConfigFilePy;
      defaultPackage = pkgs.python3Packages.rns;
      execStart = "${cfg.package}/bin/rnsd --service --config /var/lib/rnsd/.reticulum";
    };
  };

  impl = impls.${cfg.implementation};

  stateDir = "/var/lib/${impl.serviceName}";
  configFile = impl.mkConfigFile { inherit pkgs cfg; };
in
{
  options.services.rns = shared.mkOptions;

  config = lib.mkIf cfg.enable {
    services.rns.package = lib.mkDefault impl.defaultPackage;

    environment.systemPackages = [ cfg.package ];

    systemd.services.${impl.serviceName} = {
      description = "Reticulum Network Stack daemon (${impl.serviceName})";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      preStart = ''
        install -d -m 0700 ${stateDir}/${impl.configDir}
        cp --no-preserve=mode ${configFile} ${stateDir}/${impl.configDir}/config
      '';

      serviceConfig = {
        ExecStart = impl.execStart;
        Restart = "on-failure";
        RestartSec = 5;

        StateDirectory = impl.serviceName;
        WorkingDirectory = stateDir;

        DynamicUser = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
        ReadWritePaths = [ stateDir ];
        Environment = "HOME=${stateDir}";
      };
    };

    networking.firewall = lib.mkIf cfg.openFirewall (
      let ports = shared.collectPorts cfg.interfaces; in
      {
        allowedTCPPorts = ports;
        allowedUDPPorts = ports;
      }
    );
  };
}
