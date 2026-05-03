    nix run nixpkgs#nixos-rebuild -- switch --flake .#app
    nix-collect-garbage -d
    cd /nix/store && du -sh * | sort -k1,1rh | head -n100
    nix shell github:NixOS/nixpkgs/nixos-25.11#nushell


    nix run github:nix-community/nixos-anywhere -- \
      --flake github:tcurdt/nix-server#app \
      --build-on remote
