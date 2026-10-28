{
  inputs = {

    # nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    user.url = "github:tcurdt/nix-user";

    # comin.url = "github:nlewo/comin";
    # comin.inputs.nixpkgs.follows = "nixpkgs";

    # formcha.url = "github:tcurdt/formcha";
    # formcha.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

  };

  outputs =
    {
      nixpkgs,
      # comin,
      # formcha,
      disko,
      ...
    }@inputs:
    {

      nixosConfigurations = {

        app = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            inputs.disko.nixosModules.disko
            ./machines/app.nix
          ];
        };

        # michael = nixpkgs.lib.nixosSystem {
        #   system = "x86_64-linux";
        #   specialArgs = { inherit inputs; };
        #   modules = [
        #     inputs.disko.nixosModules.disko
        #     ./machines/michael.nix
        #   ];
        # };

        k3s-server = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            inputs.disko.nixosModules.disko
            ./machines/k3s-server.nix
            # { networking.hostName = "blue-c-1"; }
          ];
        };

        k3s-runner = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            inputs.disko.nixosModules.disko
            ./machines/k3s-runner.nix
          ];
        };

      };
    };
}
