set quiet

check:
    nix flake check --all-systems

update:
    nix flake update

activate machine:
    sudo nixos-rebuild switch --flake .#{{machine}} --option max-jobs 0 --option builders '' --option fallback false
