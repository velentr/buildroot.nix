# SPDX-FileCopyrightText: 2024 Brian Kubisiak <brian@kubisiak.com>
# SPDX-FileContributor: Rasmus Söderhielm <rasmus.soderhielm@gmail.com>
#
# SPDX-License-Identifier: MIT
{
  name,
  pkgs ? import <nixpkgs> {},
  src,
  externalSrc ? null,
  patchSrc ? null,
  defconfig,
  lockfile,
  nativeBuildInputs ? [],
}: let
  inherit (pkgs) stdenv;
  externalDeclaration =
    if externalSrc == null
    then ""
    else "BR2_EXTERNAL=${externalSrc}";
  patchDeclaration =
    if patchSrc == null
    then ""
    else "BR2_GLOBAL_PATCH_DIR=${patchSrc}";
  envDeclarations = "${externalDeclaration} ${patchDeclaration}";
  # There are too many places that hardcode /bin or /usr/bin to patch them all
  # (some of them are in unpacked tarballs and aren't revealed until individual
  # packages are enabled). Instead, just build everything in a FHS
  # environment. This has the added bonus of making it less likely for build
  # artifacts to hardcode a path to the nix store.
  makeFHSEnv = pkgs.buildFHSEnv {
    name = "make-with-fhs-env";
    targetPkgs = pkgs:
      with pkgs;
        [
          bc
          cpio
          file
          libxcrypt
          perl
          rsync
          unzip
          util-linux
          wget # Not actually used, but still needs to be installed
          which
        ]
        ++ nativeBuildInputs;
    runScript = "make";
  };
  buildrootBase = {
    src = src;

    patchPhase = ''
      sed -i 's%--disable-makeinstall-chown%--disable-makeinstall-chown --disable-makeinstall-setuid%' \
          package/util-linux/util-linux.mk
    '';

    configurePhase = ''
      ${makeFHSEnv}/bin/make-with-fhs-env ${envDeclarations} ${
        if builtins.isPath defconfig
        then "defconfig BR2_DEFCONFIG=${defconfig}"
        else defconfig
      }
    '';

    hardeningDisable = ["format"];
  };
  lockedPackageInputs = let
    lockedInputs = builtins.fromJSON (builtins.readFile lockfile);
    symlinkCommands = builtins.map (
      file: let
        lockedAttrs = lockedInputs.${file};
        input = pkgs.fetchurl {
          name = file;
          urls = lockedInputs.${file}.uris;
          hash = "${lockedAttrs.algo}:${lockedAttrs.checksum}";
        };
      in "ln -s ${input} $out/'${file}'"
    ) (builtins.attrNames lockedInputs);
  in
    stdenv.mkDerivation {
      name = "${name}-sources";
      dontUnpack = true;
      dontConfigure = true;
      buildPhase = "mkdir $out";
      installPhase = pkgs.lib.strings.concatStringsSep "\n" symlinkCommands;
    };
in rec {
  packageInfo = stdenv.mkDerivation (buildrootBase
    // {
      name = "${name}-packageinfo.json";

      buildPhase = ''
        ${makeFHSEnv}/bin/make-with-fhs-env ${envDeclarations} show-info > packageinfo.json
      '';

      installPhase = ''
        cp packageinfo.json $out
      '';
    });

  packageLockFile = stdenv.mkDerivation {
    name = "${name}-packages.lock";
    src = src;

    buildInputs = with pkgs; [python3];

    dontConfigure = true;
    buildPhase = ''
      python3 ${./make-package-lock.py} \
        ${
        if patchSrc == null
        then ""
        else "--patch-dir ${patchSrc}"
      } \
        --input ${packageInfo} --output $out
    '';
    dontInstall = true;
  };

  packageInputs = lockedPackageInputs;

  buildroot = stdenv.mkDerivation (buildrootBase
    // {
      name = name;

      outputs = ["out" "sdk"];

      buildPhase = ''
        export BR2_DL_DIR=/build/source/downloads
        mkdir -p $BR2_DL_DIR
        for lockedInput in ${lockedPackageInputs}/*; do
            ln -s $lockedInput "$BR2_DL_DIR/$(basename $lockedInput)"
        done

        ${makeFHSEnv}/bin/make-with-fhs-env ${envDeclarations}
        ${makeFHSEnv}/bin/make-with-fhs-env ${envDeclarations} sdk
      '';

      installPhase = ''
        mkdir $out $sdk
        cp -r output/images $out/
        cp -r output/host/* $sdk
        sh $sdk/relocate-sdk.sh
      '';

      dontFixup = true;
    });
}
