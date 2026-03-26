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
  inheritOr = value: fallback: if value == null then fallback else value;

  normalizeInstance = name: instanceCfg: {
    enable = inheritOr instanceCfg.enable cfg.enable;
    envFile = inheritOr instanceCfg.envFile cfg.envFile;
    user = inheritOr instanceCfg.user cfg.user;
    url = "http://unix:${mkSocketPath name}:";
  };

  effectiveInstances =
    if cfg.instances != { } then
      lib.mapAttrs normalizeInstance cfg.instances
    else
      {
        main = normalizeInstance "main" cfg;
      };

  enabledInstances = lib.filterAttrs (_: instance: instance.enable) effectiveInstances;

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
      DynamicUser = instanceCfg.user == null;
    }
    // lib.optionalAttrs (instanceCfg.user != null) {
      User = instanceCfg.user;
      Group = instanceCfg.user;
    };
  };
in
{
  options.services.my.formcha = lib.mkOption {
    default = { };
    description = "formcha service defaults and instances.";
    type = lib.types.submodule (
      { ... }:
      {
        options = {
          enable = lib.mkEnableOption "formcha";

          envFile = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Default path to a systemd EnvironmentFile containing ALTCHA_HMAC_KEY=<secret>.";
          };

          user = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Default system user/group used by formcha instances. Null uses DynamicUser.";
          };

          url = lib.mkOption {
            type = lib.types.str;
            internal = true;
            readOnly = true;
            default = "http://unix:${mkSocketPath "main"}:";
            description = "Derived URL alias for the main formcha instance.";
          };

          instances = lib.mkOption {
            default = { };
            description = "formcha instances keyed by instance name.";
            type = lib.types.attrsOf (
              lib.types.submodule (
                { name, ... }:
                {
                  options = {
                    enable = lib.mkOption {
                      type = lib.types.nullOr lib.types.bool;
                      default = null;
                      description = "Whether this instance is enabled. Null inherits services.my.formcha.enable.";
                    };

                    envFile = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                      description = "Path to a systemd EnvironmentFile containing ALTCHA_HMAC_KEY=<secret>. Null inherits services.my.formcha.envFile.";
                    };

                    user = lib.mkOption {
                      type = lib.types.nullOr lib.types.str;
                      default = null;
                      description = "System user/group for this instance. Null inherits services.my.formcha.user and otherwise uses DynamicUser.";
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
        };
      }
    );
  };

  config = lib.mkIf (enabledInstances != { }) {
    assertions = lib.mapAttrsToList (instance: instanceCfg: {
      assertion = instanceCfg.envFile != null;
      message = "services.my.formcha.instances.${instance}: envFile is required for enabled instances (or set services.my.formcha.envFile).";
    }) enabledInstances;

    systemd.sockets = lib.mapAttrs' (
      instance: instanceCfg: lib.nameValuePair "formcha-${instance}" (mkSocket instance instanceCfg)
    ) enabledInstances;

    systemd.services = lib.mapAttrs' (
      instance: instanceCfg: lib.nameValuePair "formcha-${instance}" (mkService instance instanceCfg)
    ) enabledInstances;
  };
}
