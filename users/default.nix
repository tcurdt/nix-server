{ pkgs, ... }:
{
  shell = pkgs.bash;

  # hashedPassword = "*"; # no password allowed, possible problem for root
}
