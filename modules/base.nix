# Base configuration applied to every node.
# SSH access, flakes, locale, timezone.
{
  # Nix
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Locale & time
  time.timeZone = "Europe/Moscow";
  i18n.defaultLocale = "en_US.UTF-8";

  # OpenSSH
  services.openssh.enable = true;
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP6Gm4DbPs1Ar7/g9IU90YS873SoMYMQhc0xjQFHtJEk mytecor@macbook.local"
  ];
}
