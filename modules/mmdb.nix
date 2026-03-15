{
  pkgs,
  ...
}:
{
  # mhttps://ip66.dev/

  environment.systemPackages = [
    pkgs.mmdbinspect
  ];

  systemd.services.mmdb-fetch = {
    description = "download mmdb if missing or older than 5 days";
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

      if find "$file" -mtime +5 | grep -q .; then
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
}
