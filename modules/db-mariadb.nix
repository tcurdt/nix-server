{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.services.my.mariadb;
  inheritOr = value: fallback: if value == null then fallback else value;
  format = pkgs.formats.ini { listsAsDuplicateKeys = true; };

  normalizeInstance =
    name: instanceCfg:
    let
      package = inheritOr instanceCfg.package cfg.package;
    in
    {
      enable = inheritOr instanceCfg.enable cfg.enable;
      user = inheritOr instanceCfg.user cfg.user;
      inherit package;
      listenAddress = inheritOr instanceCfg.listenAddress cfg.listenAddress;
      port = inheritOr instanceCfg.port cfg.port;
      dataDir = inheritOr instanceCfg.dataDir (
        inheritOr cfg.dataDir "/var/lib/mariadb/${name}/${lib.versions.major package.version}"
      );
      unixSocketDir = inheritOr instanceCfg.unixSocketDir cfg.unixSocketDir;
      settings = inheritOr instanceCfg.settings cfg.settings;
      databases = inheritOr instanceCfg.databases cfg.databases;
    };

  effectiveInstances =
    if cfg.instances != { } then
      lib.mapAttrs normalizeInstance cfg.instances
    else
      {
        main = normalizeInstance "main" cfg;
      };

  enabledInstances = lib.filterAttrs (_: instance: instance.enable) effectiveInstances;
  enabledUsers = lib.unique (
    map (instanceCfg: instanceCfg.user) (builtins.attrValues enabledInstances)
  );

  mkSocketPath = instanceCfg: "${instanceCfg.unixSocketDir}/mysqld.sock";

  mkConf =
    instanceCfg:
    format.generate "mariadb.cnf" (
      lib.recursiveUpdate {
        mysqld = {
          datadir = instanceCfg.dataDir;
          port = instanceCfg.port;
        }
        // lib.optionalAttrs (instanceCfg.listenAddress != null) {
          "bind-address" = instanceCfg.listenAddress;
        }
        // lib.optionalAttrs (instanceCfg.listenAddress == null) {
          "skip-networking" = true;
        }
        // lib.optionalAttrs (instanceCfg.unixSocketDir != null) {
          socket = mkSocketPath instanceCfg;
        };
      } instanceCfg.settings
    );

  mkClientArgs =
    instanceCfg:
    if instanceCfg.unixSocketDir != null then
      ''--socket=${lib.escapeShellArg (mkSocketPath instanceCfg)}''
    else
      ''--host=${lib.escapeShellArg instanceCfg.listenAddress} --port=${toString instanceCfg.port} --protocol=TCP'';

  mkEnsureDatabasesScript =
    instance: instanceCfg:
    let
      mkCreateDatabaseSql = database: ''
        CREATE DATABASE IF NOT EXISTS `${lib.replaceStrings [ "`" ] [ "``" ] database}`;
      '';
      createDatabasesSql = lib.concatMapStringsSep " " mkCreateDatabaseSql instanceCfg.databases;
    in
    pkgs.writeShellScript "mariadb-${instance}-ensure-databases" ''
      set -euo pipefail
      ${instanceCfg.package}/bin/mysqladmin ${mkClientArgs instanceCfg} --user=${lib.escapeShellArg instanceCfg.user} ping >/dev/null
      ${lib.optionalString (instanceCfg.databases != [ ]) ''
        ${instanceCfg.package}/bin/mysql ${mkClientArgs instanceCfg} --user=${lib.escapeShellArg instanceCfg.user} --batch --skip-column-names --execute=${lib.escapeShellArg createDatabasesSql}
      ''}
    '';

  mkService =
    instance: instanceCfg:
    let
      configFile = mkConf instanceCfg;
    in
    {
      description = "mariadb ${instance} server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      restartTriggers = [ configFile ];
      path = [ pkgs.nettools ];
      serviceConfig = {
        Type = "notify";
        User = instanceCfg.user;
        Group = instanceCfg.user;
        RuntimeDirectory = "mariadb/${instance}";
        RuntimeDirectoryMode = "0750";
        StateDirectory = "mariadb/${instance}";
        StateDirectoryMode = "0700";
        ExecStartPre = [
          "+${pkgs.coreutils}/bin/install -d -m 0700 -o ${instanceCfg.user} -g ${instanceCfg.user} ${instanceCfg.dataDir}"
          "${pkgs.bash}/bin/sh -c 'if [ ! -d \"${instanceCfg.dataDir}/mysql\" ]; then ${instanceCfg.package}/bin/mysql_install_db --defaults-file=${configFile} --user=${instanceCfg.user} --datadir=\"${instanceCfg.dataDir}\" --basedir=${instanceCfg.package}; fi'"
        ];
        ExecStart = ''
          ${instanceCfg.package}/bin/mysqld \
            --defaults-file=${configFile} \
            --user=${instanceCfg.user} \
            --datadir="${instanceCfg.dataDir}" \
            --basedir=${instanceCfg.package}
        '';
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
        KillMode = "mixed";
        TimeoutSec = "120s";
        Restart = "on-failure";
      };
      postStart = ''
        ${mkEnsureDatabasesScript instance instanceCfg}
      '';
    };
in
{
  options.services.my.mariadb = lib.mkOption {
    default = { };
    description = "MariaDB service defaults and instances.";
    type = lib.types.submodule {
      options = {
        enable = lib.mkEnableOption "mariadb";

        user = lib.mkOption {
          type = lib.types.str;
          default = "mariadb";
          description = "Default system user/group for MariaDB instances.";
        };

        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.mariadb;
          defaultText = lib.literalExpression "pkgs.mariadb";
          description = "Default MariaDB package for instances.";
        };

        listenAddress = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Default address to bind MariaDB instances to. Null disables TCP.";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 3306;
          description = "Default TCP port for MariaDB instances.";
        };

        dataDir = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Default data directory for instances. Null uses /var/lib/mariadb/<instance>.";
        };

        unixSocketDir = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Default Unix socket directory for instances. Null disables Unix socket.";
        };

        settings = lib.mkOption {
          type = format.type;
          default = { };
          description = "Default MariaDB option-file settings for instances.";
        };

        databases = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Default databases ensured after startup.";
        };

        instances = lib.mkOption {
          default = { };
          description = "MariaDB instances keyed by instance name.";
          type = lib.types.lazyAttrsOf (
            lib.types.submodule {
              options = {
                enable = lib.mkOption {
                  type = lib.types.nullOr lib.types.bool;
                  default = null;
                  description = "Whether this instance is enabled. Null inherits services.my.mariadb.enable.";
                };

                user = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "System user/group for this instance. Null inherits services.my.mariadb.user.";
                };

                package = lib.mkOption {
                  type = lib.types.nullOr lib.types.package;
                  default = null;
                  description = "MariaDB package for this instance. Null inherits services.my.mariadb.package.";
                };

                listenAddress = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Address to bind this MariaDB instance to. Null inherits services.my.mariadb.listenAddress.";
                };

                port = lib.mkOption {
                  type = lib.types.nullOr lib.types.port;
                  default = null;
                  description = "TCP port for this MariaDB instance. Null inherits services.my.mariadb.port.";
                };

                dataDir = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Data directory for this MariaDB instance. Null inherits services.my.mariadb.dataDir, else /var/lib/mariadb/<instance>.";
                };

                unixSocketDir = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Unix socket directory for this instance. Null inherits services.my.mariadb.unixSocketDir, disabling Unix socket if that is also null.";
                };

                settings = lib.mkOption {
                  type = lib.types.nullOr format.type;
                  default = null;
                  description = "MariaDB option-file settings for this instance. Null inherits services.my.mariadb.settings.";
                };

                databases = lib.mkOption {
                  type = lib.types.nullOr (lib.types.listOf lib.types.str);
                  default = null;
                  description = "Databases ensured after startup for this instance. Null inherits services.my.mariadb.databases.";
                };
              };
            }
          );
        };
      };
    };
  };

  config = lib.mkIf (enabledInstances != { }) {
    assertions = lib.mapAttrsToList (instance: instanceCfg: {
      assertion = instanceCfg.listenAddress != null || instanceCfg.unixSocketDir != null;
      message = "mariadb instance '${instance}': at least one of listenAddress or unixSocketDir must be set.";
    }) enabledInstances;

    users.groups = lib.listToAttrs (map (user: lib.nameValuePair user { }) enabledUsers);

    users.users = lib.listToAttrs (
      map (
        user:
        lib.nameValuePair user {
          isSystemUser = true;
          group = user;
          home = "/var/lib/mariadb";
        }
      ) enabledUsers
    );

    systemd.tmpfiles.rules = lib.concatLists (
      lib.mapAttrsToList (
        _: instanceCfg:
        lib.optional (
          instanceCfg.unixSocketDir != null
        ) "d ${instanceCfg.unixSocketDir} 0750 ${instanceCfg.user} ${instanceCfg.user} -"
      ) enabledInstances
    );

    systemd.services = lib.mapAttrs' (
      instance: instanceCfg: lib.nameValuePair "mariadb-${instance}" (mkService instance instanceCfg)
    ) enabledInstances;
  };
}
