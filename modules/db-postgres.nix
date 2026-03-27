{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.services.my.postgres;
  inheritOr = value: fallback: if value == null then fallback else value;

  normalizeInstance = name: instanceCfg: {
    enable = inheritOr instanceCfg.enable cfg.enable;
    user = inheritOr instanceCfg.user cfg.user;
    package = inheritOr instanceCfg.package cfg.package;
    listenAddress = inheritOr instanceCfg.listenAddress cfg.listenAddress;
    port = inheritOr instanceCfg.port cfg.port;
    dataDir = inheritOr instanceCfg.dataDir (
      inheritOr cfg.dataDir "/var/lib/postgres/${name}/${lib.versions.major instanceCfg.package.version}"
    );
    unixSocketDir = inheritOr instanceCfg.unixSocketDir cfg.unixSocketDir;
    initdbArgs = inheritOr instanceCfg.initdbArgs cfg.initdbArgs;
    settings = inheritOr instanceCfg.settings cfg.settings;
    extraHba = inheritOr instanceCfg.extraHba cfg.extraHba;
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

  mkConf =
    instanceCfg:
    let
      boolToPg = v: if v then "on" else "off";
      renderValue =
        v:
        if builtins.isBool v then
          boolToPg v
        else if builtins.isInt v then
          toString v
        else
          "'${lib.replaceStrings [ "'" ] [ "''" ] v}'";
      baseSettings = {
        port = instanceCfg.port;
      }
      // {
        listen_addresses = if instanceCfg.listenAddress != null then instanceCfg.listenAddress else "";
      }
      // lib.optionalAttrs (instanceCfg.unixSocketDir != null) {
        unix_socket_directories = instanceCfg.unixSocketDir;
      };
      mergedSettings = baseSettings // instanceCfg.settings;
    in
    lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "${k} = ${renderValue v}") mergedSettings);

  mkHba = instanceCfg: ''
    ${lib.optionalString (
      instanceCfg.unixSocketDir != null
    ) ''local   all             all                                     trust''}
    ${lib.optionalString (instanceCfg.listenAddress != null) ''
      host    all             all             127.0.0.1/32            scram-sha-256
      host    all             all             ::1/128                 scram-sha-256''}
    ${instanceCfg.extraHba}
  '';

  mkCreateDbScript =
    instance: instanceCfg:
    let
      hostArgs =
        if instanceCfg.unixSocketDir != null then
          ''-h "${instanceCfg.unixSocketDir}" -p "${toString instanceCfg.port}"''
        else
          ''-h "${instanceCfg.listenAddress}" -p "${toString instanceCfg.port}"'';
      mkDbClause = db: ''
        if ! "${instanceCfg.package}/bin/psql" ${hostArgs} -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = '${db}'" | grep -q 1; then
          "${instanceCfg.package}/bin/createdb" ${hostArgs} "${db}"
        fi
      '';
    in
    pkgs.writeShellScript "postgres-${instance}-create-databases" ''
      set -euo pipefail
      ${instanceCfg.package}/bin/pg_isready ${hostArgs} >/dev/null
      ${lib.concatMapStringsSep "\n" mkDbClause instanceCfg.databases}
    '';

  mkService = instance: instanceCfg: {
    description = "postgres ${instance} server";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    restartTriggers = [
      (pkgs.writeText "postgres-${instance}.conf" (mkConf instanceCfg))
      (pkgs.writeText "postgres-${instance}.hba" (mkHba instanceCfg))
    ];
    path = [ pkgs.gnugrep ];
    serviceConfig = {
      Type = "notify";
      User = instanceCfg.user;
      Group = instanceCfg.user;
      RuntimeDirectory = "postgres/${instance}";
      RuntimeDirectoryMode = "0750";
      StateDirectory = "postgres/${instance}";
      StateDirectoryMode = "0700";
      Environment = [ "PGDATA=${instanceCfg.dataDir}" ];
      ExecStartPre = [
        "+${pkgs.coreutils}/bin/install -d -m 0700 -o ${instanceCfg.user} -g ${instanceCfg.user} ${instanceCfg.dataDir}"
        "${pkgs.bash}/bin/sh -c 'if [ ! -f \"${instanceCfg.dataDir}/PG_VERSION\" ]; then ${instanceCfg.package}/bin/initdb --pgdata=\"${instanceCfg.dataDir}\" ${lib.escapeShellArgs instanceCfg.initdbArgs}; fi'"
      ];
      ExecStart = ''
        ${instanceCfg.package}/bin/postgres \
          -D "${instanceCfg.dataDir}" \
          -c "config_file=${pkgs.writeText "postgres-${instance}.conf" (mkConf instanceCfg)}" \
          -c "hba_file=${pkgs.writeText "postgres-${instance}.hba" (mkHba instanceCfg)}"
      '';
      ExecReload = "${instanceCfg.package}/bin/pg_ctl reload -D ${instanceCfg.dataDir}";
      KillMode = "mixed";
      KillSignal = "SIGINT";
      TimeoutSec = "120s";
      Restart = "on-failure";
    };
    postStart = lib.mkIf (instanceCfg.databases != [ ]) ''
      ${mkCreateDbScript instance instanceCfg}
    '';
  };
in
{
  options.services.my.postgres = lib.mkOption {
    default = { };
    description = "PostgreSQL service defaults and instances.";
    type = lib.types.submodule {
      options = {
        enable = lib.mkEnableOption "postgres";

        user = lib.mkOption {
          type = lib.types.str;
          default = "postgres";
          description = "Default system user/group for PostgreSQL instances.";
        };

        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.postgresql;
          defaultText = lib.literalExpression "pkgs.postgresql";
          description = "Default PostgreSQL package for instances.";
        };

        listenAddress = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Default address to bind PostgreSQL instances to. Null disables TCP.";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 5432;
          description = "Default TCP port for PostgreSQL instances.";
        };

        dataDir = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Default data directory for instances. Null uses /var/lib/postgres/<instance>.";
        };

        unixSocketDir = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Default unix socket directory for instances. Null disables Unix socket.";
        };

        initdbArgs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "--encoding=UTF8"
            "--locale=C"
            "--auth-local=trust"
            "--auth-host=scram-sha-256"
          ];
          description = "Default arguments passed to initdb during initialization.";
        };

        settings = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.oneOf [
              lib.types.bool
              lib.types.int
              lib.types.str
            ]
          );
          default = { };
          description = "Default additional postgresql.conf settings for instances.";
        };

        extraHba = lib.mkOption {
          type = lib.types.lines;
          default = "";
          description = "Default extra lines appended to pg_hba.conf.";
        };

        databases = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Default databases ensured after startup.";
        };

        instances = lib.mkOption {
          default = { };
          description = "PostgreSQL instances keyed by instance name.";
          type = lib.types.lazyAttrsOf (
            lib.types.submodule {
              options = {
                enable = lib.mkOption {
                  type = lib.types.nullOr lib.types.bool;
                  default = null;
                  description = "Whether this instance is enabled. Null inherits services.my.postgres.enable.";
                };

                user = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "System user/group for this instance. Null inherits services.my.postgres.user.";
                };

                package = lib.mkOption {
                  type = lib.types.nullOr lib.types.package;
                  default = null;
                  description = "PostgreSQL package for this instance. Null inherits services.my.postgres.package.";
                };

                listenAddress = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Address to bind this PostgreSQL instance to. Null inherits services.my.postgres.listenAddress.";
                };

                port = lib.mkOption {
                  type = lib.types.nullOr lib.types.port;
                  default = null;
                  description = "TCP port for this PostgreSQL instance. Null inherits services.my.postgres.port.";
                };

                dataDir = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Data directory for this PostgreSQL instance. Null inherits services.my.postgres.dataDir, else /var/lib/postgres/<instance>.";
                };

                unixSocketDir = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Unix socket directory for this instance. Null inherits services.my.postgres.unixSocketDir, disabling Unix socket if that is also null.";
                };

                initdbArgs = lib.mkOption {
                  type = lib.types.nullOr (lib.types.listOf lib.types.str);
                  default = null;
                  description = "Arguments passed to initdb for this instance. Null inherits services.my.postgres.initdbArgs.";
                };

                settings = lib.mkOption {
                  type = lib.types.nullOr (
                    lib.types.attrsOf (
                      lib.types.oneOf [
                        lib.types.bool
                        lib.types.int
                        lib.types.str
                      ]
                    )
                  );
                  default = null;
                  description = "Additional postgresql.conf settings for this instance. Null inherits services.my.postgres.settings.";
                };

                extraHba = lib.mkOption {
                  type = lib.types.nullOr lib.types.lines;
                  default = null;
                  description = "Extra lines appended to pg_hba.conf for this instance. Null inherits services.my.postgres.extraHba.";
                };

                databases = lib.mkOption {
                  type = lib.types.nullOr (lib.types.listOf lib.types.str);
                  default = null;
                  description = "Databases ensured after startup for this instance. Null inherits services.my.postgres.databases.";
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
      message = "postgres instance '${instance}': at least one of listenAddress or unixSocketDir must be set.";
    }) enabledInstances;

    users.groups = lib.listToAttrs (map (user: lib.nameValuePair user { }) enabledUsers);

    users.users = lib.listToAttrs (
      map (
        user:
        lib.nameValuePair user {
          isSystemUser = true;
          group = user;
          home = "/var/lib/postgres";
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
      instance: instanceCfg: lib.nameValuePair "postgres-${instance}" (mkService instance instanceCfg)
    ) enabledInstances;
  };
}
