{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.services.my.mmdb;
in
{
  # mhttps://ip66.dev/

  options.services.my.mmdb = {
    enable = lib.mkEnableOption "mmdb refresh";

    daysBetweenUpdates = lib.mkOption {
      type = lib.types.int;
      default = 3;
      description = "Refresh mmdb when the local file is older than this many days.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.mmdbinspect
    ];

    systemd.services.mmdb-fetch = {

      description = "download mmdb if missing or older than ${toString cfg.daysBetweenUpdates} days";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      serviceConfig.Type = "oneshot";

      path = with pkgs; [
        bash
        coreutils
        curl
        findutils
      ];

      script = ''
        set -eu

        file="/var/lib/mmdb/ip66.mmdb"
        url="https://downloads.ip66.dev/db/ip66.mmdb"
        dir="$(dirname "$file")"

        download() {
          tmp="$(mktemp "$dir/.ip66.mmdb.XXXXXX")"
          trap 'rm -f "$tmp"' EXIT
          curl -fL -o "$tmp" "$url"
          mv -f "$tmp" "$file"
          trap - EXIT
        }

        mkdir -p "$dir"

        if [ ! -e "$file" ]; then
          download
          exit 0
        fi

        if find "$file" -mtime +${toString cfg.daysBetweenUpdates} | grep -q .; then
          download
        fi
      '';
    };

    systemd.timers.mmdb-fetch = {
      description = "check if mmdb should be refreshed";
      wantedBy = [ "timers.target" ];
      partOf = [ "mmdb-fetch.service" ];

      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = "1h";
        Unit = "mmdb-fetch.service";
      };
    };
  };
}
