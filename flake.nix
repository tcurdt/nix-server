{
  inputs = {

    # nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

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

        # home-ber = nixpkgs.lib.nixosSystem {
        #   system = "x86_64-linux";
        #   specialArgs = { inherit inputs; };
        #   modules = [
        #     inputs.disko.nixosModules.disko
        #     inputs.home.nixosModules.default
        #     ./machines/home-ber.nix
        #   ];
        # };

        # home-goe = nixpkgs.lib.nixosSystem {
        #   system = "x86_64-linux";
        #   specialArgs = { inherit inputs; };
        #   modules = [
        #     inputs.disko.nixosModules.disko
        #     inputs.home.nixosModules.default
        #     ./machines/home-goe.nix
        #   ];
        # };

        # app = nixpkgs.lib.nixosSystem {
        #   system = "x86_64-linux";
        #   specialArgs = { inherit inputs; };
        #   modules = [
        #     inputs.disko.nixosModules.disko
        #     inputs.home.nixosModules.default
        #     ./machines/app.nix
        #   ];
        # };

        control = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            inputs.disko.nixosModules.disko
            inputs.home.nixosModules.default
            ./machines/control.nix
          ];
        };

        # michael = nixpkgs.lib.nixosSystem {
        #   system = "x86_64-linux";
        #   specialArgs = { inherit inputs; };
        #   modules = [
        #     inputs.disko.nixosModules.disko
        #     inputs.home.nixosModules.default
        #     ./machines/michael.nix
        #   ];
        # };

        k3s-server = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            inputs.disko.nixosModules.disko
            inputs.home.nixosModules.default
            ./machines/k3s-server.nix
            # { networking.hostName = "blue-c-1"; }
          ];
        };

        k3s-runner = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            inputs.disko.nixosModules.disko
            inputs.home.nixosModules.default
            ./machines/k3s-runner.nix
          ];
        };

      };
    };
}
