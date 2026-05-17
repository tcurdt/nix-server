{
  inputs = {

    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    # nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home.url = "github:tcurdt/nix-home";
    home.inputs.nixpkgs.follows = "nixpkgs";

    # comin.url = "github:nlewo/comin";
    # comin.inputs.nixpkgs.follows = "nixpkgs";

    formcha.url = "github:tcurdt/formcha";
    formcha.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

  };

  outputs =
    {
      nixpkgs,
      # comin,
      formcha,
      disko,
      ...
    }@inputs:
    {

      nixosConfigurations = {

        # utm-arm = nixpkgs.lib.nixosSystem {
        #   specialArgs = {
        #     inherit inputs;
        #   };
        #   modules = [
        #     inputs.home.nixosModules.default
        #     ./machines/utm-arm.nix
        #   ];
        # };

        # utm-x86 = nixpkgs.lib.nixosSystem {
        #   specialArgs = {
        #     inherit inputs formcha;
        #   };
        #   modules = [
        #     inputs.home.nixosModules.default
        #     ./machines/utm-x86.nix
        #   ];
        # };

        app = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            inputs.disko.nixosModules.disko
            inputs.home.nixosModules.default
            ./machines/app.nix
          ];
        };

        # k3s-server = nixpkgs.lib.nixosSystem {
        #   system = "x86_64-linux";
        #   specialArgs = { inherit inputs; };
        #   modules = [
        #     inputs.disko.nixosModules.disko
        #     inputs.home.nixosModules.default
        #     ./machines/k3s-server.nix
        #     # { networking.hostName = "blue-c-1"; }
        #     # openssl passwd -6
        #     # nix run nixpkgs#mkpasswd -- -m sha-512
        #     # {
        #     #   users.users.root = {
        #     #     hashedPassword = "$6$Fl99ylyQvTXrVC9E$TqHgmsLnH.h7BKWUhQ1rUy8glTaDgNcXJeqOdiezzD9vcRKMpuglgZRDTtKo752fw0.mAVqMz2tKGTrmnyfHx/";
        #     #   };
        #     # }
        #     # {
        #     #   # ssh ops@116.202.2.78
        #     #   # ssh ops@2a01:4f8:1c17:800f::1
        #     #   services.k3s-floating-ip = {
        #     #     enable = true;
        #     #     ipv4 = "116.202.2.78";
        #     #     ipv6 = "2a01:4f8:1c17:800f::1";
        #     #     ipv6Gateway = "fe80::1";
        #     #     interface = "enp1s0";
        #     #   };
        #     # }

        #   ];
        # };

        # k3s-runner = nixpkgs.lib.nixosSystem {
        #   system = "x86_64-linux";
        #   specialArgs = { inherit inputs; };
        #   modules = [
        #     inputs.disko.nixosModules.disko
        #     inputs.home.nixosModules.default
        #     ./machines/k3s-runner.nix
        #   ];
        # };

        rke-server = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            inputs.disko.nixosModules.disko
            inputs.home.nixosModules.default
            ./machines/rke-server.nix
          ];
        };

        rke-runner = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            inputs.disko.nixosModules.disko
            inputs.home.nixosModules.default
            ./machines/rke-runner.nix
          ];
        };

      };
    };
}
