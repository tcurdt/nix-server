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
      wantedBy = [ "sockets.target" ];
      socketConfig = {
        ListenStream = socketPath;
        SocketMode = "0660";
        SocketGroup = "nginx";
        StopWhenUnneeded = true;
        # Backlog=4096;
        # Accept=no;
      };
    };

    systemd.services.formcha = {
      description = "formcha server";
      serviceConfig = {
        ExecStart = "${package}/bin/formcha";
        EnvironmentFile = cfg.envFile;
        DynamicUser = true;
        RuntimeDirectory = "formcha";
        RuntimeDirectoryMode = "0750";
        TimeoutIdleSec = 15;
        # KillSignal=SIGTERM;
        # Restart=on-failure;
      };
    };

  };
}
