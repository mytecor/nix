# Shared option definitions for the unified Reticulum Network Stack module.
{ lib }:

let
  interfaceOpts = { ... }: {
    options = {
      type = lib.mkOption {
        type = lib.types.str;
        description = "Interface type (TCPClientInterface, UDPInterface, AutoInterface, WebSocketInterface).";
      };

      enabled = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether this interface is enabled.";
      };

      address = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Bind address.";
      };

      port = lib.mkOption {
        type = lib.types.nullOr lib.types.port;
        default = null;
        description = "Bind port.";
      };

      target_host = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Target host for client interfaces.";
      };

      target_port = lib.mkOption {
        type = lib.types.nullOr lib.types.port;
        default = null;
        description = "Target port for client interfaces.";
      };

      discovery_port = lib.mkOption {
        type = lib.types.nullOr lib.types.port;
        default = null;
        description = "Discovery port for AutoInterface.";
      };

      data_port = lib.mkOption {
        type = lib.types.nullOr lib.types.port;
        default = null;
        description = "Data port for AutoInterface.";
      };

      discovery_scope = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Discovery scope for AutoInterface (link, admin, site, organization, global).";
      };

      group_id = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Group ID for AutoInterface.";
      };
    };
  };

  mkOptions = {
    enable = lib.mkEnableOption "Reticulum Network Stack";

    implementation = lib.mkOption {
      type = lib.types.enum [ "rnsd" "reticulum-go" ];
      description = "Which implementation to use.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      description = "The RNS package to use.";
      # Default is set in default.nix where pkgs is available.
    };

    enableTransport = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable transport node (relay packets for other nodes).";
    };

    shareInstance = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Share the Reticulum instance with other programs.";
    };

    sharedInstancePort = lib.mkOption {
      type = lib.types.port;
      default = 37428;
      description = "Port for shared instance communication.";
    };

    instanceControlPort = lib.mkOption {
      type = lib.types.port;
      default = 37429;
      description = "Port for instance control.";
    };

    panicOnInterfaceError = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Panic if an interface fails to start.";
    };

    logLevel = lib.mkOption {
      type = lib.types.ints.between 0 7;
      default = 4;
      description = "Log verbosity (0 = critical only, 7 = all).";
    };

    interfaces = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule interfaceOpts);
      default = { };
      description = "Reticulum network interfaces.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open firewall ports for configured interfaces.";
    };
  };

  collectPorts = interfaces:
    lib.foldlAttrs (acc: _: iface:
      let
        ports = lib.filter (p: p != null) [
          iface.port
          iface.target_port
          iface.discovery_port
          iface.data_port
        ];
      in
        acc ++ ports
    ) [] interfaces;

  configGo   = import ./config-go.nix   { inherit lib; };
  configPy = import ./config-py.nix { inherit lib; };

in {
  inherit mkOptions collectPorts;
  mkConfigFileGo   = configGo.mkConfigFile;
  mkConfigFilePy = configPy.mkConfigFile;
}
