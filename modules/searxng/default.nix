# SearXNG — privacy-respecting metasearch engine.
#
# Standalone module — does NOT depend on the upstream services.searx module.
# Manages the systemd service, config generation, and user directly.
#
{ config, lib, pkgs, ... }:

let
  cfg = config.services.searxng;

  # Build the settings.yml content
  settingsFile = let
    finalSettings = lib.recursiveUpdate {
      server = {
        bind_address = cfg.host;
        port = cfg.port;
        secret_key = if cfg.secretKeyFile != null
          then "@SEARXNG_SECRET@"
          else "searxng-default-secret-change-me";
      };
      search = {
        safe_search = 0;
        autocomplete = "duckduckgo";
        default_lang = "all";
      };
      ui = {
        default_theme = "simple";
        infinite_scroll = true;
      };
    } cfg.settings;
  in
    pkgs.writeText "searxng-settings.yml"
      (lib.generators.toYAML { } finalSettings);

  # Script that optionally substitutes secrets and starts SearXNG
  startScript = pkgs.writeShellScript "searxng-start" ''
    SETTINGS_DIR="/run/searxng"
    mkdir -p "$SETTINGS_DIR"

    ${if cfg.secretKeyFile != null then ''
      # Substitute @SEARXNG_SECRET@ with the actual secret
      SEARXNG_SECRET="$(cat ${cfg.secretKeyFile})"
      ${pkgs.gnused}/bin/sed "s|@SEARXNG_SECRET@|$SEARXNG_SECRET|g" \
        ${settingsFile} > "$SETTINGS_DIR/settings.yml"
    '' else ''
      cp ${settingsFile} "$SETTINGS_DIR/settings.yml"
    ''}

    chmod 600 "$SETTINGS_DIR/settings.yml"

    export SEARXNG_SETTINGS_PATH="$SETTINGS_DIR/settings.yml"
    exec ${cfg.package}/bin/searxng-run
  '';
in
{
  options.services.searxng = {
    enable = lib.mkEnableOption "SearXNG metasearch engine";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.searxng;
      description = "The SearXNG package to use.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address to bind the HTTP server to.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8888;
      description = "Port for the SearXNG HTTP server.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the SearXNG port in the firewall.";
    };

    secretKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to a file containing the raw secret key for SearXNG.
        The contents are substituted into settings.yml at runtime.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Extra SearXNG settings merged into the configuration.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.searxng = {
      description = "SearXNG metasearch engine";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        ExecStart = startScript;
        Restart = "on-failure";
        RestartSec = 10;

        DynamicUser = true;
        RuntimeDirectory = "searxng";
        RuntimeDirectoryMode = "0750";
        StateDirectory = "searxng";
        WorkingDirectory = "/var/lib/searxng";

        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
        ReadWritePaths = [ "/run/searxng" "/var/lib/searxng" ];
      };
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}
