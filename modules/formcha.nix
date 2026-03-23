{
  pkgs,
  lib,
  config,
  formcha,
  ...
}:

let
  cfg = config.services.my.formcha;
  package = formcha.packages.${pkgs.stdenv.hostPlatform.system}.default;

  enabledInstances = lib.filterAttrs (_: instance: instance.enable) cfg;

  mkSocketPath = instance: "/run/formcha/${instance}.sock";

  mkSocket = instance: _instanceCfg: {
    description = "formcha ${instance} server socket";
    partOf = [ "formcha-${instance}.service" ];
    wantedBy = [ "sockets.target" ];
    socketConfig = {
      ListenStream = mkSocketPath instance;
      Backlog = 128;
      DirectoryMode = "0770";
      SocketMode = "0660";
      SocketGroup = "nginx";
    };
  };

  mkService = instance: instanceCfg: {
    description = "formcha ${instance} server";
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${package}/bin/formcha";
      Type = "simple";
      Environment = [ "FORMCHA_IDLE_TIMEOUT=30s" ];
      EnvironmentFile = instanceCfg.envFile;
      DynamicUser = true;
    };
  };
in
{
  options.services.my.formcha = lib.mkOption {
    default = { };
    description = "formcha instances keyed by instance name.";
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, ... }:
        {
          options = {
            enable = lib.mkEnableOption "formcha instance";

            envFile = lib.mkOption {
              type = lib.types.str;
              description = "Path to a systemd EnvironmentFile containing ALTCHA_HMAC_KEY=<secret>.";
            };

            url = lib.mkOption {
              type = lib.types.str;
              internal = true;
              readOnly = true;
              default = "http://unix:${mkSocketPath name}:";
              description = "Derived URL for proxying to this formcha instance (Unix socket).";
            };
          };
        }
      )
    );
  };

  config = lib.mkIf (enabledInstances != { }) {
    systemd.sockets = lib.mapAttrs' (
      instance: instanceCfg: lib.nameValuePair "formcha-${instance}" (mkSocket instance instanceCfg)
    ) enabledInstances;

    systemd.services = lib.mapAttrs' (
      instance: instanceCfg: lib.nameValuePair "formcha-${instance}" (mkService instance instanceCfg)
    ) enabledInstances;
  };
}
