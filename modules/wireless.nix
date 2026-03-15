# Wi-Fi via NetworkManager with credentials stored in sops.
#
# The importing node must provide:
#
#   sops.defaultSopsFile = ./secrets.yaml;   # must contain wifi_psk, wifi_ssid
#   sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
#
# Usage:
#
#   imports = [ ../../modules/wireless.nix ];
#
{ inputs, config, ... }:

{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  sops.secrets.wifi_ssid = { };
  sops.secrets.wifi_psk = { };

  sops.templates."wireless.env".content = ''
    WIFI_SSID=${config.sops.placeholder.wifi_ssid}
    WIFI_PSK=${config.sops.placeholder.wifi_psk}
  '';

  networking.networkmanager.enable = true;

  networking.networkmanager.ensureProfiles = {
    environmentFiles = [
      config.sops.templates."wireless.env".path
    ];

    profiles.wifi = {
      connection = {
        id = "wifi";
        type = "wifi";
      };
      wifi = {
        mode = "infrastructure";
        ssid = "$WIFI_SSID";
      };
      wifi-security = {
        auth-alg = "open";
        key-mgmt = "wpa-psk";
        psk = "$WIFI_PSK";
      };
      ipv4.method = "auto";
      ipv6 = {
        addr-gen-mode = "stable-privacy";
        method = "auto";
      };
    };
  };
}
