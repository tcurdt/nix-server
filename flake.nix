{
  inputs = {

    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";
    # nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    home.url = "github:tcurdt/nix-home";
    home.inputs.nixpkgs.follows = "nixpkgs-stable";

    comin.url = "github:nlewo/comin";
    comin.inputs.nixpkgs.follows = "nixpkgs-stable";

    # release-go.url = "github:tcurdt/release-go";
    # release-go.inputs.nixpkgs.follows = "nixpkgs-stable";
    # sshhook.url = "git+file:///Users/tcurdt/Desktop/nix/flake-sshhook/";

  };

  outputs =
    {
      nixpkgs-stable,
      comin,
      ...
    }@inputs:
    let
      systems = [
        # "x86_64-darwin"
        "aarch64-darwin"
        "x86_64-linux"
        # "i686-linux"
        # "aarch64-linux"
      ];
      forAllSystems = nixpkgs-stable.lib.genAttrs systems;
    in
    {

      packages = forAllSystems (
        system: import ./packages { pkgs = nixpkgs-stable.legacyPackages.${system}; }
      );
      # formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra)

      # overlays = import ./overlays { inherit inputs; };

      nixosConfigurations = {

        utm-arm = nixpkgs-stable.lib.nixosSystem {
          specialArgs = {
            inherit inputs;
          };
          modules = [
            inputs.home.nixosModules.default
            ./machines/utm-arm.nix
          ];
        };

        utm-x86 = nixpkgs-stable.lib.nixosSystem {
          specialArgs = {
            inherit inputs;
          };
          modules = [
            inputs.home.nixosModules.default
            ./machines/utm-x86.nix
          ];
        };

        app = nixpkgs-stable.lib.nixosSystem {
          specialArgs = {
            inherit inputs;
          };
          modules = [
            inputs.home.nixosModules.default
            ./machines/app.nix
            comin.nixosModules.comin
            (import ./modules/comin.nix)
          ];
        };

        # home-goe = nixpkgs-stable.lib.nixosSystem {
        #   specialArgs = {
        #     inherit inputs;
        #   };
        #   modules = [
        #     ./machines/home-goe.nix
        #     comin.nixosModules.comin
        #     (import ./modules/comin.nix)
        #   ];
        # };

        # home-ber = nixpkgs-stable.lib.nixosSystem {
        #   specialArgs = {
        #     inherit inputs;
        #   };
        #   modules = [
        #     ./machines/home-ber.nix
        #     comin.nixosModules.comin
        #     (import ./modules/comin.nix)
        #   ];
        # };

      };
    };
}
