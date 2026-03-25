# System-wide font packages.
#
# Installs a realistic set of fonts so that headless/server systems
# don't stand out with a minimal font list (a common fingerprint).
#
# Usage:
#
#   imports = [ ../../modules/fonts ];
#
{ pkgs, ... }:

{
  fonts.packages = with pkgs; [
    corefonts           # Arial, Times New Roman, Verdana, Georgia, Comic Sans, Impact, Trebuchet, Courier New, etc.
    liberation_ttf      # Liberation family (metric-compatible with Arial, Times, Courier)
    noto-fonts          # Noto Sans/Serif (wide Unicode coverage)
    noto-fonts-cjk-sans # CJK fonts (very common on desktop Linux)
    noto-fonts-color-emoji # Emoji support
    dejavu_fonts        # DejaVu (standard Linux fallback)
    roboto              # Roboto (common on Linux/Android)
    ubuntu-classic      # Ubuntu font family
    freefont_ttf        # GNU FreeFont (FreeSerif, FreeSans, FreeMono)
    source-code-pro     # Adobe Source Code Pro (popular dev font)
    source-sans-pro     # Adobe Source Sans (common on web)
    source-serif-pro    # Adobe Source Serif
    inter               # Inter (modern UI font)
    fira                # Fira Sans/Mono (Mozilla)
    fira-code           # Fira Code (ligature monospace, tested by CreepJS)
    hack-font           # Hack (popular monospace)
    cantarell-fonts     # GNOME default UI font
    dina-font           # Dina programming font
    open-sans           # Open Sans (very popular)
    lato                # Lato (common Google Font)
    # Note: Calibri/Cambria/Consolas/Segoe UI (vistafonts) are not in nixpkgs.
    # corefonts covers the most commonly tested MS fonts.
  ];
}
