# Generic MCP proxy (stdio → HTTP bridge).
#
# Wraps any stdio-based MCP server with mcp-proxy, exposing it as
# a Streamable-HTTP / SSE endpoint over the network.  Each instance
# is declared under services.mcp-proxy.<name>.
#
# Usage:
#
#   imports = [ ../../modules/mcp-proxy ];
#
#   services.mcp-proxy.my-server = {
#     enable = true;
#     command = "${pkgs.some-mcp-server}/bin/mcp-server";
#     args = [ "--flag" "value" ];
#     port = 3100;
#     listenAddress = "0.0.0.0";
#     openFirewall = true;
#   };
#
# Endpoints:
#   http://<host>:<port>/mcp   (Streamable HTTP)
#   http://<host>:<port>/sse   (legacy SSE)
#
{ config, lib, pkgs, ... }:

let
  eachProxy = config.services.mcp-proxy;

  mkService = name: cfg:
    let
      execStart = lib.concatStringsSep " " ([
        "${cfg.proxyPackage}/bin/mcp-proxy"
        "--host=${cfg.listenAddress}"
        "--port=${toString cfg.port}"
        "--"
        cfg.command
      ] ++ cfg.args);
    in
    lib.nameValuePair "mcp-proxy-${name}" {
      description = "MCP Proxy: ${name}";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ] ++ cfg.after;
      requires = cfg.requires;

      serviceConfig = {
        ExecStart = execStart;
        Restart = "on-failure";
        RestartSec = 10;

        DynamicUser = true;
        StateDirectory = "mcp-proxy-${name}";
        WorkingDirectory = "/var/lib/mcp-proxy-${name}";
        Environment = [
          "HOME=/var/lib/mcp-proxy-${name}"
        ] ++ cfg.environment;

        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
        ReadWritePaths = [ "/var/lib/mcp-proxy-${name}" ];
      };
    };

  proxyOpts = { name, ... }: {
    options = {
      enable = lib.mkEnableOption "MCP proxy instance '${name}'";

      proxyPackage = lib.mkOption {
        type = lib.types.package;
        default = pkgs.mcp-proxy;
        defaultText = lib.literalExpression "pkgs.mcp-proxy";
        description = "The mcp-proxy package (stdio → HTTP bridge).";
      };

      command = lib.mkOption {
        type = lib.types.str;
        description = "Full path to the stdio MCP server binary.";
        example = lib.literalExpression "\${pkgs.some-mcp-server}/bin/mcp-server";
      };

      args = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Arguments passed to the MCP server command.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 3100;
        description = "HTTP port for the MCP endpoint.";
      };

      listenAddress = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "Address to bind the MCP HTTP server on.";
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Open the MCP HTTP port in the firewall.";
      };

      after = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Extra systemd units to order after.";
      };

      requires = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Extra systemd units to require.";
      };

      environment = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Extra Environment= entries for the systemd service.";
      };
    };
  };

  enabledProxies = lib.filterAttrs (_: cfg: cfg.enable) eachProxy;
in
{
  options.services.mcp-proxy = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule proxyOpts);
    default = { };
    description = "Declarative MCP proxy instances (stdio → HTTP).";
  };

  config = lib.mkIf (enabledProxies != { }) {
    systemd.services = lib.mapAttrs' mkService enabledProxies;

    networking.firewall.allowedTCPPorts =
      lib.concatMap
        (cfg: lib.optional cfg.openFirewall cfg.port)
        (lib.attrValues enabledProxies);
  };
}
