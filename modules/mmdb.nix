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

    days = lib.mkOption {
      type = lib.types.int;
      default = 1;
      description = "Refresh mmdb when the local file is older than this many days.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.mmdbinspect
    ];

    systemd.services.mmdb-fetch = {

      description = "download mmdb if missing or older than ${toString cfg.days} days";
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

        mkdir -p "$(dirname "$file")"

        if [ ! -e "$file" ]; then
          exec curl -fL -o "$file" "$url"
        fi

        if find "$file" -mtime +${toString cfg.days} | grep -q .; then
          exec curl -fL -z "$file" -o "$file" "$url"
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
