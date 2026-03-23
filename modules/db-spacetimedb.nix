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

  enabledInstances = lib.filterAttrs (_: instance: instance.enable) cfg;

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
    description = "spacetimedb instances keyed by instance name.";
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          enable = lib.mkEnableOption "spacetimedb instance";

          listenAddress = lib.mkOption {
            type = lib.types.str;
            default = "127.0.0.1";
            description = "Address to bind this spacetimedb instance to.";
          };

          port = lib.mkOption {
            type = lib.types.port;
            default = 3000;
            description = "TCP port for this spacetimedb instance.";
          };
        };
      }
    );
  };

  config = lib.mkIf (enabledInstances != { }) {
    systemd.services = lib.mapAttrs' (
      instance: instanceCfg: lib.nameValuePair "spacetimedb-${instance}" (mkService instance instanceCfg)
    ) enabledInstances;
  };
}
