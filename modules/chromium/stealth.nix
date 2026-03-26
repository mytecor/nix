# Stealth preset for chromium.
#
# Returns an attribute set suitable for merging into
# services.chromium.  Pass overrides to customise individual
# values; anything not specified gets sensible stealth defaults.
#
# Usage (in a node config):
#
#   services.chromium = {
#     enable = true;
#   } // import ../../modules/chromium/stealth.nix {
#     lang = "ru-RU";
#     acceptLang = "ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7";
#     timezone = "Europe/Moscow";
#     blockLocalPorts = [ 22 3389 ];
#   };
#
{
  userAgent           ? null,
  webrtcPolicy        ? "default",
  disableBatteryStatus ? true,
  disableHeadlessFlags ? true,
  disableMdnsIce      ? true,
  lang                ? null,
  acceptLang          ? null,
  timezone            ? null,
  blockLocalPorts     ? [],
  taskbarHeight       ? 40,   # simulate a taskbar to defeat noTaskbar / hasVvpScreenRes
}:
{
  inherit
    userAgent
    webrtcPolicy
    disableBatteryStatus
    disableHeadlessFlags
    disableMdnsIce
    lang
    acceptLang
    timezone
    blockLocalPorts
    taskbarHeight;
}
