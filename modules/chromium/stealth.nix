# Anti-detect preset for chromium.
#
# Returns an attribute set suitable for merging into
# services.chromium.  Pass overrides to customise individual
# values; anything not specified gets sensible anti-detect defaults.
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
  lang                ? null,
  acceptLang          ? null,
  timezone            ? null,
  blockLocalPorts     ? [],
}:
{
  inherit
    userAgent
    webrtcPolicy
    disableBatteryStatus
    disableHeadlessFlags
    lang
    acceptLang
    timezone
    blockLocalPorts;
}
