{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.services.nginx-selfsigned;
in
{
  options.services.nginx-selfsigned = {
    domains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Domains to generate self-signed certificates for.";
    };
  };

  config = lib.mkIf (cfg.domains != [ ]) {
    systemd.services = lib.listToAttrs (
      map (domain: {
        name = "nginx-selfsigned-${lib.replaceStrings [ "." ] [ "-" ] domain}";
        value = {
          description = "Generate self-signed certificate for nginx (${domain})";
          before = [ "nginx.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            if [ ! -f /var/lib/nginx/${domain}.crt ]; then
              ${pkgs.openssl}/bin/openssl req -x509 -newkey ec \
                -pkeyopt ec_paramgen_curve:prime256v1 \
                -days 365 -nodes \
                -keyout /var/lib/nginx/${domain}.key \
                -out /var/lib/nginx/${domain}.crt \
                -subj "/CN=${domain}"
              chown nginx:nginx /var/lib/nginx/${domain}.{crt,key}
              chmod 600 /var/lib/nginx/${domain}.key
            fi
          '';
        };
      }) cfg.domains
    );
  };
}
