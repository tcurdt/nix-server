{
  inputs = {

    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";
    # nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # darwin.url = "github:LnL7/nix-darwin/nix-darwin-25.05";
    # darwin.inputs.nixpkgs.follows = "nixpkgs-stable";

    # home-manager.url = "github:nix-community/home-manager/release-25.05";
    # home-manager.inputs.nixpkgs.follows = "nixpkgs-stable";

    # impermanence.url = "github:nix-community/impermanence";

    comin.url = "github:nlewo/comin";
    comin.inputs.nixpkgs.follows = "nixpkgs-stable";

    # deploy-rs.url = "github:serokell/deploy-rs";
    # deploy-rs.inputs.nixpkgs.follows = "nixpkgs-stable";

    # nixos-generators.url = "github:nix-community/nixos-generators";
    # nixos-generators.inputs.nixpkgs.follows = "nixpkgs-stable";

    # agenix.url = "github:ryantm/agenix";
    # agenix.inputs.nixpkgs.follows = "nixpkgs-stable";
    # agenix.inputs.darwin.follows = "";

    # release-go.url = "github:tcurdt/release-go";
    # release-go.inputs.nixpkgs.follows = "nixpkgs-stable";
    # sshhook.url = "git+file:///Users/tcurdt/Desktop/nix/flake-sshhook/";

  };

  outputs =
    {
      # self,
      nixpkgs-stable,
      # home-manager,
      # impermanence,
      darwin,
      comin,
      # deploy-rs,
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

      # darwinConfigurations = {
      #   shodan = darwin.lib.darwinSystem {
      #     specialArgs = {
      #       inherit inputs;
      #     };
      #     modules = [ ./machines/shodan.nix ];
      #   };
      # };

      packages = forAllSystems (system: import ./packages nixpkgs-stable.legacyPackages.${system});
      # formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra)

      # overlays = import ./overlays { inherit inputs; };

      nixosConfigurations = {

        utm-arm = nixpkgs-stable.lib.nixosSystem {
          specialArgs = {
            inherit inputs;
          };
          modules = [ ./machines/utm-arm.nix ];
        };

        utm-x86 = nixpkgs-stable.lib.nixosSystem {
          specialArgs = {
            inherit inputs;
          };
          modules = [ ./machines/utm-x86.nix ];
        };

        app = nixpkgs-stable.lib.nixosSystem {
          specialArgs = {
            inherit inputs;
          };
          modules = [
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
