{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.services.my.postgres;
  enabledInstances = lib.filterAttrs (_: instance: instance.enable) cfg;

  mkUserName = instance: "postgres-${instance}";

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
        listen_addresses = instanceCfg.listenAddress;
        port = instanceCfg.port;
        unix_socket_directories = instanceCfg.unixSocketDir;
      };
      mergedSettings = baseSettings // instanceCfg.settings;
    in
    lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "${k} = ${renderValue v}") mergedSettings);

  mkHba = instanceCfg: ''
    local   all             all                                     trust
    host    all             all             127.0.0.1/32            scram-sha-256
    host    all             all             ::1/128                 scram-sha-256
    ${instanceCfg.extraHba}
  '';

  mkCreateDbScript =
    instance: instanceCfg:
    let
      mkDbClause = db: ''
        if ! "${instanceCfg.package}/bin/psql" -h "${instanceCfg.unixSocketDir}" -p "${toString instanceCfg.port}" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = '${db}'" | grep -q 1; then
          "${instanceCfg.package}/bin/createdb" -h "${instanceCfg.unixSocketDir}" -p "${toString instanceCfg.port}" "${db}"
        fi
      '';
    in
    pkgs.writeShellScript "postgres-${instance}-create-databases" ''
      set -euo pipefail
      ${instanceCfg.package}/bin/pg_isready -h "${instanceCfg.unixSocketDir}" -p "${toString instanceCfg.port}" >/dev/null
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
      User = mkUserName instance;
      Group = mkUserName instance;
      RuntimeDirectory = "postgres/${instance}";
      RuntimeDirectoryMode = "0750";
      StateDirectory = "postgres/${instance}";
      StateDirectoryMode = "0700";
      WorkingDirectory = instanceCfg.dataDir;
      Environment = [ "PGDATA=${instanceCfg.dataDir}" ];
      ExecStartPre = [
        "+/bin/sh -c 'if [ ! -f \"${instanceCfg.dataDir}/PG_VERSION\" ]; then ${instanceCfg.package}/bin/initdb --pgdata=\"${instanceCfg.dataDir}\" ${lib.escapeShellArgs instanceCfg.initdbArgs}; fi'"
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
    description = "PostgreSQL instances keyed by instance name.";
    type = lib.types.lazyAttrsOf (
      lib.types.submodule (
        { name, ... }:
        {
          options = {
            enable = lib.mkEnableOption "postgres instance";

            package = lib.mkOption {
              type = lib.types.package;
              default = pkgs.postgresql;
              defaultText = lib.literalExpression "pkgs.postgresql";
              description = "PostgreSQL package used for this instance.";
            };

            listenAddress = lib.mkOption {
              type = lib.types.str;
              default = "127.0.0.1";
              description = "Address to bind this PostgreSQL instance to.";
            };

            port = lib.mkOption {
              type = lib.types.port;
              default = 5432;
              description = "TCP port for this PostgreSQL instance.";
            };

            dataDir = lib.mkOption {
              type = lib.types.str;
              default = "/var/lib/postgres/${name}";
              description = "Data directory for this PostgreSQL instance.";
            };

            unixSocketDir = lib.mkOption {
              type = lib.types.str;
              default = "/run/postgres/${name}";
              description = "Directory for unix socket files for this instance.";
            };

            initdbArgs = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [
                "--encoding=UTF8"
                "--locale=C"
                "--auth-local=trust"
                "--auth-host=scram-sha-256"
              ];
              description = "Arguments passed to initdb during first initialization.";
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
              description = "Additional postgresql.conf settings for this instance.";
            };

            extraHba = lib.mkOption {
              type = lib.types.lines;
              default = "";
              description = "Extra lines appended to pg_hba.conf for this instance.";
            };

            databases = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Databases ensured after startup (created if missing).";
            };
          };
        }
      )
    );
  };

  config = lib.mkIf (enabledInstances != { }) {
    users.groups = lib.mapAttrs' (
      instance: _: lib.nameValuePair (mkUserName instance) { }
    ) enabledInstances;

    users.users = lib.mapAttrs' (
      instance: instanceCfg:
      lib.nameValuePair (mkUserName instance) {
        isSystemUser = true;
        group = mkUserName instance;
        home = instanceCfg.dataDir;
      }
    ) enabledInstances;

    systemd.tmpfiles.rules = lib.mapAttrsToList (
      instance: instanceCfg:
      let
        user = mkUserName instance;
      in
      "d ${instanceCfg.unixSocketDir} 0750 ${user} ${user} -"
    ) enabledInstances;

    systemd.services = lib.mapAttrs' (
      instance: instanceCfg: lib.nameValuePair "postgres-${instance}" (mkService instance instanceCfg)
    ) enabledInstances;
  };
}
