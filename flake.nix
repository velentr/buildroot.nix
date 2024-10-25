# SPDX-FileCopyrightText: 2024 Brian Kubisiak <brian@kubisiak.com>
#
# SPDX-License-Identifier: MIT
{
  description = "Flake for building Buildroot using nix";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

  inputs.treefmt-nix.url = "github:numtide/treefmt-nix";
  inputs.treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";

  inputs.buildroot.url = "gitlab:buildroot.org/buildroot/2024.08";
  inputs.buildroot.flake = false;

  outputs = {
    self,
    buildroot,
    nixpkgs,
    treefmt-nix,
  }: let
    supportedSystems = ["x86_64-linux"];
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    pkgs = forAllSystems (system: nixpkgs.legacyPackages.${system});
    treefmtEval = forAllSystems (
      system:
        treefmt-nix.lib.evalModule pkgs.${system} ./treefmt.nix
    );
    x86_64SdkPackages = forAllSystems (system:
      import ./default.nix {
        name = "buildroot-x86_64-sdk";
        pkgs = nixpkgs.legacyPackages.${system};
        src = buildroot;
        defconfig = ./tests/configs/x86_64_defconfig;
        lockfile = ./tests/buildroot-x86_64-sdk.lock;
      });
    buildrootPackages = forAllSystems (system:
      import ./default.nix {
        name = "buildroot-checks";
        pkgs = nixpkgs.legacyPackages.${system};
        src = buildroot;
        defconfig = "qemu_x86_64_defconfig";
        lockfile = ./tests/buildroot.lock;
      });
  in {
    lib.mkBuildroot = args: import ./default.nix args;

    formatter = forAllSystems (
      system:
        treefmtEval.${system}.config.build.wrapper
    );

    checks = forAllSystems (system: {
      formatting = treefmtEval.${system}.config.build.check self;
      test-buildroot = buildrootPackages.${system}.buildroot;
      test-buildroot-x86_64-sdk = x86_64SdkPackages.${system}.buildroot;
    });

    packages = forAllSystems (system: {
      test-buildroot-lock = buildrootPackages.${system}.packageLockFile;
      test-buildroot-x86_64-sdk-lock = x86_64SdkPackages.${system}.packageLockFile;
    });
  };
}
