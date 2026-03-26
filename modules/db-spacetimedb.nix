{
  pkgs,
  lib,
  config,
  ...
}:
# https://github.com/clockworklabs/SpacetimeDB
# https://spacetimedb.com/docs/how-to/deploy/self-hosting
let
  cfg = config.services.my.spacetimedb;
  inheritOr = value: fallback: if value == null then fallback else value;

  normalizeInstance = name: instanceCfg: {
    enable = inheritOr instanceCfg.enable cfg.enable;
    listenAddress = inheritOr instanceCfg.listenAddress cfg.listenAddress;
    port = inheritOr instanceCfg.port cfg.port;
  };

  effectiveInstances =
    if cfg.instances != { } then
      lib.mapAttrs normalizeInstance cfg.instances
    else
      {
        main = normalizeInstance "main" cfg;
      };

  enabledInstances = lib.filterAttrs (_: instance: instance.enable) effectiveInstances;

  mkService = instance: instanceCfg: {
    description = "spacetimedb ${instance} server";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = ''
        ${pkgs.spacetimedb}/bin/spacetime \
          --root-dir=/var/lib/spacetimedb/${instance} \
          start \
          --listen-addr=${instanceCfg.listenAddress}:${toString instanceCfg.port}
      '';
      Type = "simple";
      DynamicUser = true;
      StateDirectory = "spacetimedb/${instance}";
      WorkingDirectory = "/var/lib/spacetimedb/${instance}";
      Restart = "always";
    };
  };
in
{
  options.services.my.spacetimedb = lib.mkOption {
    default = { };
    description = "spacetimedb service defaults and instances.";
    type = lib.types.submodule {
      options = {
        enable = lib.mkEnableOption "spacetimedb";

        listenAddress = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "Default address to bind spacetimedb instances to.";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 3000;
          description = "Default TCP port for spacetimedb instances.";
        };

        instances = lib.mkOption {
          default = { };
          description = "spacetimedb instances keyed by instance name.";
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                enable = lib.mkOption {
                  type = lib.types.nullOr lib.types.bool;
                  default = null;
                  description = "Whether this instance is enabled. Null inherits services.my.spacetimedb.enable.";
                };

                listenAddress = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Address to bind this spacetimedb instance to. Null inherits services.my.spacetimedb.listenAddress.";
                };

                port = lib.mkOption {
                  type = lib.types.nullOr lib.types.port;
                  default = null;
                  description = "TCP port for this spacetimedb instance. Null inherits services.my.spacetimedb.port.";
                };
              };
            }
          );
        };
      };
    };
  };

  config = lib.mkIf (enabledInstances != { }) {
    systemd.services = lib.mapAttrs' (
      instance: instanceCfg: lib.nameValuePair "spacetimedb-${instance}" (mkService instance instanceCfg)
    ) enabledInstances;
  };
}
