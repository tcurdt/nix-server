set quiet

check:
    nix flake check --all-systems path:.

update:
    nix flake update

# local version
build machine:
    nix build --eval-store daemon --store ssh-ng://{{ machine }} --no-link .#nixosConfigurations.{{ machine }}.config.system.build.toplevel

# local version (better disable comin)
switch machine:
    nix run --inputs-from . nixpkgs#nixos-rebuild -- switch --no-reexec --flake .#{{ machine }} --build-host {{ machine }} --target-host {{ machine }}

# comin
release machine:
    ssh {{ machine }} \
      "nixos-rebuild switch --flake github:tcurdt/nix-server#{{ machine }}"
