{
  # pkgs,
  ...
}:
{

  networking.hostName = "utm-x86";
  networking.domain = "utm";
  system.stateVersion = "25.11";

  imports = [

    ../hardware/utm-x86.nix
    ../modules/server.nix

    ../users/root.nix
    ../users/ops.nix
    { ops.keyFiles = [ ../keys/tcurdt.pub ]; }

    { users.users.root.password = "secret"; }

  ];

  # services.my.sqld = {
  #   enable = true;
  #   primary = true; # false for replica
  #   listenAddress = "0.0.0.0";
  #   ports = {
  #     http = 8081;
  #     grpc = 5001;
  #   };
  #   ca = {
  #     cert = "/secrets/sqld_ca_cert.pem";
  #     # key = "/secrets/sqld_ca_key.pem";
  #   };
  #   server = {
  #     cert = "/secrets/sqld_server_cert.pem";
  #     key = "/secrets/sqld_server_key.pem";
  #   };
  #   client = {
  #     key = "/secrets/sqld_client_key.pem";
  #   };
  # };

  # services.my.litestream = {
  #   enable = true;
  #   settings = {
  #     addr = "0.0.0.0:9090";
  #     accessKeyId = "S3_ACCESS_KEY_ID";
  #     secretAccessKey = "S3_SECRET_ACCESS_KEY";
  #     forcePathStyle = true;
  #     endpoint = "S3_ENDPOINT";
  #     logging = {
  #       level = "info";
  #     };
  #     levels = [
  #       { interval = "15m"; }
  #     ];
  #     l0Retention = "30m";
  #     l0RetentionCheckInterval = "5m";
  #     snapshot = {
  #       interval = "24h";
  #       retention = "168h";
  #     };
  #     dbs = [
  #       {
  #         path = "/data/account.sqlite";
  #         monitorInterval = "5s";
  #         checkpointInterval = "5m";
  #         minCheckpointPageCount = 10000;
  #         truncatePageN = 0;
  #         replica = {
  #           url = "s3://BUCKET/litestream/account.sqlite";
  #           syncInterval = "5s";
  #         };
  #       }
  #     ];
  #   };
  # };

}
