{pkgs, ...}: {
  projectRootFile = ".git/config";

  # formatting nix code
  programs.alejandra.enable = true;
  # formatting python code
  programs.black.enable = true;
}
