set quiet

check:
    nix flake check --all-systems path:.

update:
    nix flake update

build machine:
    nix build --eval-store daemon --store ssh-ng://{{ machine }} --no-link .#nixosConfigurations.{{ machine }}.config.system.build.toplevel

diff machine:
    ssh {{ machine }} nvd diff /run/current-system $(nix eval --raw .#nixosConfigurations.{{ machine }}.config.system.build.toplevel.outPath)

test machine:
    nix run --inputs-from . nixpkgs#nixos-rebuild -- test --no-reexec --flake .#{{ machine }} --build-host {{ machine }} --target-host {{ machine }}

switch machine:
    nix run --inputs-from . nixpkgs#nixos-rebuild -- switch --no-reexec --flake .#{{ machine }} --build-host {{ machine }} --target-host {{ machine }}
