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
  serviceName = "rns";
  configDir = ".reticulum";
  stateDir = "/var/lib/${serviceName}";

  impls = {
    reticulum-go = {
      mkConfigFile = shared.mkConfigFileGo;
      defaultPackage = reticulum-go-pkg;
      execStart = "${cfg.package}/bin/reticulum-go";
    };
    rnsd = {
      mkConfigFile = shared.mkConfigFilePy;
      defaultPackage = pkgs.python3Packages.rns;
      execStart = "${cfg.package}/bin/rnsd --service --config ${stateDir}/${configDir}";
    };
  };

  impl = impls.${cfg.implementation};
  configFile = impl.mkConfigFile { inherit pkgs cfg; };
in
{
  options.services.rns = shared.mkOptions;

  config = lib.mkIf cfg.enable {
    services.rns.package = lib.mkDefault impl.defaultPackage;

    environment.systemPackages = [ cfg.package ];

    systemd.services.${serviceName} = {
      description = "Reticulum Network Stack daemon (${cfg.implementation})";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      preStart = ''
        install -d -m 0700 ${stateDir}/${configDir}
        cp --no-preserve=mode ${configFile} ${stateDir}/${configDir}/config
      '';

      serviceConfig = {
        ExecStart = impl.execStart;
        Restart = "on-failure";
        RestartSec = 5;

        StateDirectory = serviceName;
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
