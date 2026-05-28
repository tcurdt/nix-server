{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.my.laravel;

  mkLaravelSite =
    name: siteCfg:
    let
      username = "laravel-${name}";
      phpPackage = siteCfg.phpPackage;
    in
    {
      services.nginx.enable = true;
      security.acme.acceptTerms = lib.mkIf siteCfg.ssl true;

      # This doesn't override the array, only merges 80 and potentially 443 into it.
      networking.firewall.allowedTCPPorts = [ 80 ] ++ lib.optionals siteCfg.ssl [ 443 ];

      environment.etc."laravel-${name}-bashrc".text = ''
        export PATH="$HOME/.config/composer/vendor/bin/:$PATH"

        # Laravel site welcome message
        echo "Welcome to ${name} Laravel site!"
        echo "Domains: ${lib.concatStringsSep ", " siteCfg.domains}"
        echo "User home: /home/${username}"
        echo "Site: /srv/${name}"
        echo "Restart php-fpm: sudo systemctl reload phpfpm-${name}"
        ${lib.optionalString siteCfg.queue ''echo "Restart queue: php artisan queue:restart"''}
        ${lib.optionalString siteCfg.queue ''echo "Queue status: sudo systemctl status laravel-queue-${name}"''}
        ${lib.optionalString siteCfg.generateSshKey ''echo "SSH public key: cat ~/.ssh/id_ed25519.pub"''}
        echo "---"
      '';

      systemd.tmpfiles.rules = [
        "d /srv 0751 root root - -"
        "d /home 0751 root root - -"
        "d /srv/${name} 0750 ${username} ${username} - -"
        "C /home/${username}/.bashrc 0640 ${username} ${username} - /etc/laravel-${name}-bashrc"
      ];

      services.cron.systemCronJobs = [
        "* * * * * ${username} cd /srv/${name} && ${phpPackage}/bin/php artisan schedule:run > /dev/null 2>&1"
      ];

      systemd.services."laravel-queue-${name}" = lib.mkIf siteCfg.queue {
        description = "Laravel Queue Worker for ${name}";
        after = [
          "network.target"
          "phpfpm-${name}.service"
        ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "simple";
          User = username;
          Group = username;
          WorkingDirectory = "/srv/${name}";
          ExecStart = "${phpPackage}/bin/php artisan queue:work ${siteCfg.queueArgs}";
          Restart = "always";
          RestartSec = 10;
          KillMode = "mixed";
          KillSignal = "SIGTERM";
          TimeoutStopSec = 60;
        };
      };

      systemd.services."generate-ssh-key-${name}" = lib.mkIf siteCfg.generateSshKey {
        description = "Generate SSH key for ${username}";
        wantedBy = [ "multi-user.target" ];
        after = [ "users.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "root";
        };
        script = ''
          USER_HOME="/home/${username}"
          SSH_DIR="$USER_HOME/.ssh"
          KEY_FILE="$SSH_DIR/id_ed25519"

          if [[ ! -f "$KEY_FILE" ]]; then
            echo "Generating SSH key for ${username}"
            mkdir -p "$SSH_DIR"
            ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -f "$KEY_FILE" -N "" -C "${username}"
            chown -R ${username}:${username} "$SSH_DIR"
            chmod 700 "$SSH_DIR"
            chmod 600 "$KEY_FILE"
            chmod 640 "$KEY_FILE.pub"
            echo "SSH key generated: $KEY_FILE.pub"
            echo "Public key for deploy key:"
            cat "$KEY_FILE.pub"
          else
            echo "SSH key already exists for ${username}"
          fi
        '';
      };

      services.nginx.virtualHosts =
        lib.genAttrs siteCfg.domains (domain: {
          enableACME = siteCfg.ssl;
          forceSSL = siteCfg.ssl;
          root = "/srv/${name}/public";

          extraConfig = ''
            add_header X-Frame-Options "SAMEORIGIN";
            add_header X-Content-Type-Options "nosniff";
            charset utf-8;
            index index.php;
            error_page 404 /index.php;
            ${lib.optionalString siteCfg.cloudflareOnly ''
              ssl_verify_client on;
              ssl_client_certificate ${
                pkgs.fetchurl {
                  url = "https://developers.cloudflare.com/ssl/static/authenticated_origin_pull_ca.pem";
                  sha256 = "0hxqszqfzsbmgksfm6k0gp0hsx9k1gqx24gakxqv0391wl6fsky1";
                }
              };
            ''}
            ${siteCfg.extraNginxConfig}
          '';

          locations = {
            "/" = {
              tryFiles = "$uri $uri/ /index.php?$query_string";
            };

            "= /favicon.ico".extraConfig = ''
              access_log off;
              log_not_found off;
            '';

            "= /robots.txt".extraConfig = ''
              access_log off;
              log_not_found off;
            '';

            "~ ^/index\\.php(/|$)".extraConfig = ''
              fastcgi_pass unix:${config.services.phpfpm.pools.${name}.socket};
              fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
              include ${pkgs.nginx}/conf/fastcgi_params;
              fastcgi_hide_header X-Powered-By;
            '';

            "~ /\\.(?!well-known).*".extraConfig = ''
              deny all;
            '';
          };
        })
        // lib.optionalAttrs (siteCfg.wwwRedirect != null) (
          lib.genAttrs (map (domain: "www.${domain}") siteCfg.domains) (wwwDomain: {
            enableACME = siteCfg.ssl;
            forceSSL = siteCfg.ssl;

            locations."/" = {
              return = "${toString siteCfg.wwwRedirect} ${
                if siteCfg.ssl then "https" else "http"
              }://${lib.removePrefix "www." wwwDomain}$request_uri";
            };
          })
        );

      services.phpfpm.pools.${name} = {
        user = username;
        inherit phpPackage;
        settings =
          siteCfg.poolSettings
          // siteCfg.extraPoolSettings
          // {
            "listen.owner" = config.services.nginx.user;
          };
      };

      users.users.${username} = {
        group = username;
        isSystemUser = true;
        createHome = true;
        home = "/home/${username}";
        homeMode = "750";
        shell = pkgs.bashInteractive;
        packages = [
          phpPackage
          pkgs.git
          pkgs.unzip
          phpPackage.packages.composer
        ]
        ++ siteCfg.extraPackages;
      }
      // lib.optionalAttrs (siteCfg.sshKeys != null) {
        openssh.authorizedKeys.keys = siteCfg.sshKeys;
      };

      users.groups.${username} = { };

      systemd.services.nginx.serviceConfig.SupplementaryGroups = [ username ];

      security.sudo.extraRules = [
        {
          users = [ username ];
          commands = [
            {
              command = "/run/current-system/sw/bin/systemctl reload phpfpm-${name}";
              options = [ "NOPASSWD" ];
            }
            {
              command = "/run/current-system/sw/bin/systemctl reload phpfpm-${name}.service";
              options = [ "NOPASSWD" ];
            }
          ]
          ++ lib.optionals siteCfg.queue [
            {
              command = "/run/current-system/sw/bin/systemctl status laravel-queue-${name}";
              options = [ "NOPASSWD" ];
            }
            {
              command = "/run/current-system/sw/bin/systemctl status laravel-queue-${name}.service";
              options = [ "NOPASSWD" ];
            }
          ];
        }
      ];
    };
in
{
  options.services.my.laravel = {
    sites = lib.mkOption {
      default = { };
      description = "Laravel sites keyed by site name.";
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            options = {
              phpPackage = lib.mkOption {
                type = lib.types.package;
                example = lib.literalExpression "pkgs.php84";
                description = "PHP package used by this Laravel site.";
              };

              domains = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                example = [ "example.com" ];
                description = "Domains served by this Laravel site.";
              };

              ssl = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Whether to enable ACME and force SSL for this site.";
              };

              wwwRedirect = lib.mkOption {
                type = lib.types.nullOr lib.types.int;
                default = null;
                example = 301;
                description = "Status code for www-to-apex redirects. Null disables redirects.";
              };

              cloudflareOnly = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Whether to require Cloudflare Authenticated Origin Pulls.";
              };

              extraNginxConfig = lib.mkOption {
                type = lib.types.lines;
                default = "";
                description = "Extra nginx config appended to each primary virtual host.";
              };

              sshKeys = lib.mkOption {
                type = lib.types.nullOr (lib.types.listOf lib.types.str);
                default = null;
                description = "SSH public keys allowed to log in as the site's deployment user.";
              };

              extraPackages = lib.mkOption {
                type = lib.types.listOf lib.types.package;
                default = [ ];
                description = "Extra packages added to the site's deployment user's PATH.";
              };

              queue = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Whether to create a Laravel queue worker systemd service.";
              };

              queueArgs = lib.mkOption {
                type = lib.types.str;
                default = "";
                example = "--tries=2";
                description = "Additional arguments passed to php artisan queue:work.";
              };

              generateSshKey = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Whether to generate an ed25519 SSH key for the site's deployment user.";
              };

              poolSettings = lib.mkOption {
                type = lib.types.attrsOf lib.types.anything;
                default = {
                  "pm" = "dynamic";
                  "pm.max_children" = 8;
                  "pm.start_servers" = 2;
                  "pm.min_spare_servers" = 1;
                  "pm.max_spare_servers" = 3;
                  "pm.max_requests" = 200;

                  "php_admin_flag[opcache.enable]" = true;
                  "php_admin_value[opcache.memory_consumption]" = "256";
                  "php_admin_value[opcache.max_accelerated_files]" = "10000";
                  "php_admin_value[opcache.revalidate_freq]" = "0";
                  "php_admin_flag[opcache.validate_timestamps]" = false;
                  "php_admin_flag[opcache.save_comments]" = true;
                };
                description = "PHP-FPM pool settings. Setting this option replaces the defaults.";
              };

              extraPoolSettings = lib.mkOption {
                type = lib.types.attrsOf lib.types.anything;
                default = { };
                description = "Additional PHP-FPM pool settings merged over poolSettings.";
              };

              username = lib.mkOption {
                type = lib.types.str;
                readOnly = true;
                default = "laravel-${name}";
                description = "Derived system user for this Laravel site.";
              };
            };
          }
        )
      );
    };
  };

  config =
    let
      siteConfigs = lib.mapAttrsToList mkLaravelSite cfg.sites;
      siteValues = builtins.attrValues cfg.sites;
      anySites = cfg.sites != { };
      anySsl = lib.any (siteCfg: siteCfg.ssl) siteValues;
      fromSites = getter: map getter siteConfigs;
    in
    {
      services.nginx = {
        enable = lib.mkIf anySites true;
        virtualHosts = lib.mkMerge (fromSites (siteConfig: siteConfig.services.nginx.virtualHosts));
      };

      security.acme.acceptTerms = lib.mkIf anySsl true;

      networking.firewall.allowedTCPPorts = lib.mkIf anySites ([ 80 ] ++ lib.optionals anySsl [ 443 ]);

      environment.etc = lib.mkMerge (fromSites (siteConfig: siteConfig.environment.etc));

      systemd.tmpfiles.rules = lib.concatLists (
        fromSites (siteConfig: siteConfig.systemd.tmpfiles.rules)
      );

      services.cron.systemCronJobs = lib.concatLists (
        fromSites (siteConfig: siteConfig.services.cron.systemCronJobs)
      );

      systemd.services = lib.mkMerge (fromSites (siteConfig: siteConfig.systemd.services));

      services.phpfpm.pools = lib.mkMerge (fromSites (siteConfig: siteConfig.services.phpfpm.pools));

      users.users = lib.mkMerge (fromSites (siteConfig: siteConfig.users.users));

      users.groups = lib.mkMerge (fromSites (siteConfig: siteConfig.users.groups));

      security.sudo.extraRules = lib.concatLists (
        fromSites (siteConfig: siteConfig.security.sudo.extraRules)
      );
    };
}
