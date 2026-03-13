# Server role: UEFI boot with systemd-boot, DHCP networking.
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
}
