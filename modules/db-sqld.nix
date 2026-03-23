{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.services.my.sqld;

  enabledInstances = lib.filterAttrs (_: instance: instance.enable) cfg;

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
    message = "services.my.sqld.${instance}: replica instances require both primaryHttpUrl and primaryGrpcUrl.";
  }) enabledInstances;
in
{
  options.services.my.sqld = lib.mkOption {
    default = { };
    description = "sqld instances keyed by instance name.";
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          enable = lib.mkEnableOption "sqld instance";

          primary = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether this sqld instance acts as primary.";
          };

          listenAddress = lib.mkOption {
            type = lib.types.str;
            default = "127.0.0.1";
            description = "Address to bind HTTP and gRPC listeners to.";
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
            description = "HTTP URL of the primary node when this instance is a replica.";
          };

          primaryGrpcUrl = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "gRPC URL of the primary node when this instance is a replica.";
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
        };
      }
    );
  };

  config = lib.mkIf (enabledInstances != { }) {
    assertions =
      replicaAssertions
      ++ lib.mapAttrsToList (instance: instanceCfg: {
        assertion =
          (!instanceCfg.primary)
          || (instanceCfg.server.cert != "" && instanceCfg.server.key != "" && instanceCfg.ca.cert != null);
        message = "services.my.sqld.${instance}: primary instances require server.cert, server.key and ca.cert.";
      }) enabledInstances;

    systemd.services = lib.mapAttrs' (
      instance: instanceCfg: lib.nameValuePair "sqld-${instance}" (mkService instance instanceCfg)
    ) enabledInstances;
  };
}
