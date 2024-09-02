# SPDX-FileCopyrightText: 2024 Brian Kubisiak <brian@kubisiak.com>
#
# SPDX-License-Identifier: MIT
{
  inputs.buildroot-nix.url = "github:velentr/buildroot.nix/master";

  outputs = {
    self,
    nixpkgs,
    buildroot-nix,
  }: let
    supportedSystems = ["x86_64-linux"];
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
  in {
    packages = forAllSystems (system: let
      buildrootPackages = buildroot-nix.lib.mkBuildroot {
        name = "my-buildroot";
        pkgs = nixpkgs.legacyPackages.${system};
        # Replace this with your defconfig, or call mkBuildroot
        # multiple times if you have several.
        defconfig = "qemu_aarch64_virt_defconfig";
        # Note that the lockfile is evaluated lazily so it can be
        # added as an argument here before it exists.
        lockfile = ./buildroot.lock;
        # If the flake is not in the root of the repo, change this to
        # point at the sources instead. This could also be changed to
        # a tarball or git repository to download the sources as part
        # of the build.
        src = self;
      };
    in {
      # The lockfile allows nix to download sources ahead of time and
      # ensures that their hashes don't change (which would break the
      # reproducibility of the buildroot build).
      #
      # To generate this lockfile, you can run:
      # $ nix build .#lockfile && cp result buildroot.lock
      #
      # The lockfile must be generated before attempting to build the
      # full buildroot and must be kept up-to-date as packages are
      # added.
      lockfile = buildrootPackages.packageLockFile;
      default = buildrootPackages.buildroot;
    });
  };
}
