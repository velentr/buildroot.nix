# SPDX-FileCopyrightText: 2024 Brian Kubisiak <brian@kubisiak.com>
#
# SPDX-License-Identifier: MIT
{pkgs, ...}: {
  projectRootFile = ".git/config";

  # formatting nix code
  programs.alejandra.enable = true;
  # formatting python code
  programs.black.enable = true;
}
