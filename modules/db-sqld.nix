{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.services.my.sqld;
  inheritOr = value: fallback: if value == null then fallback else value;

  normalizeInstance = _name: instanceCfg: {
    enable = inheritOr instanceCfg.enable cfg.enable;
    primary = inheritOr instanceCfg.primary cfg.primary;
    listenAddress = inheritOr instanceCfg.listenAddress cfg.listenAddress;
    ports = {
      http = inheritOr instanceCfg.ports.http cfg.ports.http;
      grpc = inheritOr instanceCfg.ports.grpc cfg.ports.grpc;
    };
    primaryHttpUrl = inheritOr instanceCfg.primaryHttpUrl cfg.primaryHttpUrl;
    primaryGrpcUrl = inheritOr instanceCfg.primaryGrpcUrl cfg.primaryGrpcUrl;
    ca = {
      cert = inheritOr instanceCfg.ca.cert cfg.ca.cert;
    };
    server = {
      cert = inheritOr instanceCfg.server.cert cfg.server.cert;
      key = inheritOr instanceCfg.server.key cfg.server.key;
    };
    client = {
      cert = inheritOr instanceCfg.client.cert cfg.client.cert;
      key = inheritOr instanceCfg.client.key cfg.client.key;
    };
  };

  effectiveInstances =
    if cfg.instances != { } then
      lib.mapAttrs normalizeInstance cfg.instances
    else
      {
        main = normalizeInstance "main" cfg;
      };

  enabledInstances = lib.filterAttrs (_: instance: instance.enable) effectiveInstances;

  mkExecStart =
    instanceCfg:
    let
      httpAddr = "${instanceCfg.listenAddress}:${toString instanceCfg.ports.http}";
      grpcAddr = "${instanceCfg.listenAddress}:${toString instanceCfg.ports.grpc}";
    in
    lib.concatStringsSep " " (
      [
        "${pkgs.sqld}/bin/sqld"
        "--http-listen-addr ${httpAddr}"
        "--grpc-listen-addr ${grpcAddr}"
      ]
      ++ lib.optionals instanceCfg.primary [
        "--grpc-tls"
        "--grpc-cert-file ${instanceCfg.server.cert}"
        "--grpc-key-file ${instanceCfg.server.key}"
        "--grpc-ca-cert-file ${instanceCfg.ca.cert}"
      ]
      ++ lib.optionals (!instanceCfg.primary) [
        "--http-primary-url ${instanceCfg.primaryHttpUrl}"
        "--primary-grpc-url ${instanceCfg.primaryGrpcUrl}"
      ]
      ++ lib.optionals (!instanceCfg.primary && instanceCfg.client.cert != null) [
        "--primary-grpc-tls"
        "--primary-grpc-cert-file ${instanceCfg.client.cert}"
      ]
      ++ lib.optionals (!instanceCfg.primary && instanceCfg.client.key != null) [
        "--primary-grpc-key-file ${instanceCfg.client.key}"
      ]
      ++ lib.optionals (!instanceCfg.primary && instanceCfg.ca.cert != null) [
        "--primary-grpc-ca-cert-file ${instanceCfg.ca.cert}"
      ]
    );

  mkService = instance: instanceCfg: {
    description = "sqld ${instance} server";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = mkExecStart instanceCfg;
      Type = "simple";
      DynamicUser = true;
      StateDirectory = "sqld/${instance}";
      WorkingDirectory = "/var/lib/sqld/${instance}";
      Restart = "always";
    };
  };

  replicaAssertions = lib.mapAttrsToList (instance: instanceCfg: {
    assertion =
      instanceCfg.primary || (instanceCfg.primaryHttpUrl != null && instanceCfg.primaryGrpcUrl != null);
    message = "services.my.sqld.instances.${instance}: replica instances require both primaryHttpUrl and primaryGrpcUrl.";
  }) enabledInstances;
in
{
  options.services.my.sqld = lib.mkOption {
    default = { };
    description = "sqld service defaults and instances.";
    type = lib.types.submodule {
      options = {
        enable = lib.mkEnableOption "sqld";

        primary = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether sqld instances act as primary by default.";
        };

        listenAddress = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "Default address to bind HTTP and gRPC listeners to.";
        };

        ports = {
          http = lib.mkOption {
            type = lib.types.port;
            default = 8080;
          };
          grpc = lib.mkOption {
            type = lib.types.port;
            default = 5001;
          };
        };

        primaryHttpUrl = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Default HTTP URL of the primary node when an instance is a replica.";
        };

        primaryGrpcUrl = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Default gRPC URL of the primary node when an instance is a replica.";
        };

        ca = {
          cert = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
          };
        };

        server = {
          cert = lib.mkOption {
            type = lib.types.str;
            default = "";
          };
          key = lib.mkOption {
            type = lib.types.str;
            default = "";
          };
        };

        client = {
          cert = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
          };
          key = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
          };
        };

        instances = lib.mkOption {
          default = { };
          description = "sqld instances keyed by instance name.";
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                enable = lib.mkOption {
                  type = lib.types.nullOr lib.types.bool;
                  default = null;
                  description = "Whether this instance is enabled. Null inherits services.my.sqld.enable.";
                };

                primary = lib.mkOption {
                  type = lib.types.nullOr lib.types.bool;
                  default = null;
                  description = "Whether this sqld instance acts as primary. Null inherits services.my.sqld.primary.";
                };

                listenAddress = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Address to bind HTTP and gRPC listeners to. Null inherits services.my.sqld.listenAddress.";
                };

                ports = {
                  http = lib.mkOption {
                    type = lib.types.nullOr lib.types.port;
                    default = null;
                  };
                  grpc = lib.mkOption {
                    type = lib.types.nullOr lib.types.port;
                    default = null;
                  };
                };

                primaryHttpUrl = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "HTTP URL of the primary node when this instance is a replica. Null inherits services.my.sqld.primaryHttpUrl.";
                };

                primaryGrpcUrl = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "gRPC URL of the primary node when this instance is a replica. Null inherits services.my.sqld.primaryGrpcUrl.";
                };

                ca = {
                  cert = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                  };
                };

                server = {
                  cert = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                  };
                  key = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                  };
                };

                client = {
                  cert = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                  };
                  key = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                  };
                };
              };
            }
          );
        };
      };
    };
  };

  config = lib.mkIf (enabledInstances != { }) {
    assertions =
      replicaAssertions
      ++ lib.mapAttrsToList (instance: instanceCfg: {
        assertion =
          (!instanceCfg.primary)
          || (instanceCfg.server.cert != "" && instanceCfg.server.key != "" && instanceCfg.ca.cert != null);
        message = "services.my.sqld.instances.${instance}: primary instances require server.cert, server.key and ca.cert.";
      }) enabledInstances;

    systemd.services = lib.mapAttrs' (
      instance: instanceCfg: lib.nameValuePair "sqld-${instance}" (mkService instance instanceCfg)
    ) enabledInstances;
  };
}
