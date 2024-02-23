{pkgs, ...}: {
  projectRootFile = ".git/config";

  # formatting nix code
  programs.alejandra.enable = true;
}
