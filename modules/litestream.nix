{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.services.my.litestream;
  inheritOr = value: fallback: if value == null then fallback else value;
  fmt = pkgs.formats.yaml { };

  camelToKebab =
    s:
    builtins.concatStringsSep "" (
      map (
        c:
        let
          l = lib.toLower c;
        in
        if c != l then "-${l}" else c
      ) (lib.stringToCharacters s)
    );

  mapKeys = f: attrs: lib.mapAttrs' (k: v: lib.nameValuePair (f k) v) attrs;

  toKebabAttrs =
    attrs:
    mapKeys camelToKebab (
      lib.mapAttrs (
        _: v:
        if lib.isAttrs v then
          toKebabAttrs v
        else if lib.isList v then
          map (e: if lib.isAttrs e then toKebabAttrs e else e) v
        else
          v
      ) attrs
    );

  normalizeInstance = _name: instanceCfg: {
    enable = inheritOr instanceCfg.enable cfg.enable;
    user = inheritOr instanceCfg.user cfg.user;
    settings = inheritOr instanceCfg.settings cfg.settings;
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

  mkConfigFile =
    instance: instanceCfg:
    fmt.generate "litestream-${instance}.yml" (toKebabAttrs instanceCfg.settings);

  mkService = instance: instanceCfg: {
    description = "litestream ${instance} server";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.litestream}/bin/litestream replicate -config ${mkConfigFile instance instanceCfg}";
      Type = "simple";
      User = instanceCfg.user;
      Group = instanceCfg.user;
      StateDirectory = "litestream/${instance}";
      StateDirectoryMode = "0750";
      WorkingDirectory = "/var/lib/litestream/${instance}";
      Restart = "always";
    };
  };
in
{
  options.services.my.litestream = lib.mkOption {
    default = { };
    description = "litestream service defaults and instances.";
    type = lib.types.submodule {
      options = {
        enable = lib.mkEnableOption "litestream";

        user = lib.mkOption {
          type = lib.types.str;
          default = "litestream";
          description = "Default system user/group for litestream instances.";
        };

        settings = lib.mkOption {
          type = fmt.type;
          default = { };
          description = "Default litestream configuration. Serialized 1:1 to YAML. See https://litestream.io/reference/config/";
        };

        instances = lib.mkOption {
          default = { };
          description = "litestream instances keyed by instance name.";
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                enable = lib.mkOption {
                  type = lib.types.nullOr lib.types.bool;
                  default = null;
                  description = "Whether this instance is enabled. Null inherits services.my.litestream.enable.";
                };

                user = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "System user/group for this instance. Null inherits services.my.litestream.user.";
                };

                settings = lib.mkOption {
                  type = lib.types.nullOr fmt.type;
                  default = null;
                  description = "litestream configuration for this instance. Null inherits services.my.litestream.settings.";
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
      assertion = instanceCfg.settings != { };
      message = "services.my.litestream.instances.${instance}: settings must not be empty.";
    }) enabledInstances;

    users.groups = lib.listToAttrs (map (user: lib.nameValuePair user { }) enabledUsers);

    users.users = lib.listToAttrs (
      map (
        user:
        lib.nameValuePair user {
          isSystemUser = true;
          group = user;
          home = "/var/lib/litestream";
        }
      ) enabledUsers
    );

    systemd.services = lib.mapAttrs' (
      instance: instanceCfg: lib.nameValuePair "litestream-${instance}" (mkService instance instanceCfg)
    ) enabledInstances;
  };
}
