# install

    nix run github:nix-community/nixos-anywhere -- \
      --flake github:tcurdt/nix-server#app \
      --build-on remote

# maintain

    just update
    just build app
    just diff app
    just switch app
