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
  socketPath = "/run/formcha/formcha.sock";
in
{
  options.services.my.formcha = {

    enable = lib.mkEnableOption "formcha";

    envFile = lib.mkOption {
      type = lib.types.str;
      description = "Path to a systemd EnvironmentFile containing ALTCHA_HMAC_KEY=<secret>.";
    };

    url = lib.mkOption {
      type = lib.types.str;
      internal = true;
      description = "Derived URL for proxying to formcha (Unix socket).";
    };

  };

  config = lib.mkIf cfg.enable {

    services.my.formcha.url = "http://unix:${socketPath}:";

    systemd.sockets.formcha = {
      description = "formcha server socket";
      partOf = [ "formcha.service" ];
      wantedBy = [ "sockets.target" ];
      socketConfig = {
        ListenStream = socketPath;
        Backlog = 128;
        # NoDelay = true;
        DirectoryMode = "0770";
        SocketMode = "0660";
        SocketGroup = "nginx";
      };
    };

    systemd.services.formcha = {
      description = "formcha server";
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = "${package}/bin/formcha";
        Type = "simple";
        TimeoutStartSec = "15s";
        ExecStop = "${pkgs.systemd}/bin/systemctl stop formcha.service";
        EnvironmentFile = cfg.envFile;
        DynamicUser = true;
      };
    };

  };
}
