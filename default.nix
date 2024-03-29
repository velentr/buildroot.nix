{
  pkgs ? import <nixpkgs> {},
  src,
  defconfig,
}: let
  inherit (pkgs) stdenv;
  buildrootBase = {
    src = src;

    nativeBuildInputs = with pkgs; [
      bc
      cpio
      file
      perl
      rsync
      unzip
      util-linux
      wget # Not actually used, but still needs to be installed
      which
    ];

    patchPhase = ''
      patchShebangs support/scripts support/download
    '';

    configurePhase = ''
      make ${defconfig}
    '';
  };
in rec {
  packageInfo = stdenv.mkDerivation (buildrootBase
    // {
      name = "${defconfig}-packageinfo.json";

      buildPhase = ''
        make show-info > packageinfo.json
      '';

      installPhase = ''
        cp packageinfo.json $out
      '';
    });

  packageLockFile = stdenv.mkDerivation {
    name = "${defconfig}-packages.lock";
    src = src;

    buildInputs = with pkgs; [python3];

    dontConfigure = true;
    buildPhase = ''
      python3 ${./make-package-lock.py} --input ${packageInfo} --output $out
    '';
    dontInstall = true;
  };

  packageInputs = {lockfile}: let
    lockedInputs = builtins.fromJSON (builtins.readFile lockfile);
    symlinkCommands = builtins.map (
      file: let
        lockedAttrs = lockedInputs.${file};
        input = pkgs.fetchurl {
          name = file;
          urls = lockedInputs.${file}.uris;
          hash = "${lockedAttrs.algo}:${lockedAttrs.checksum}";
        };
      in "ln -s ${input} $out/${file}"
    ) (builtins.attrNames lockedInputs);
  in
    stdenv.mkDerivation {
      name = "${defconfig}-sources";
      dontUnpack = true;
      dontConfigure = true;
      buildPhase = "mkdir $out";
      installPhase = pkgs.lib.strings.concatStringsSep "\n" symlinkCommands;
    };
}
