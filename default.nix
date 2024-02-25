{
  pkgs ? import <nixpkgs> {},
  src,
  defconfig,
}: let
  inherit (pkgs) stdenv;
in rec {
  packageInfo = stdenv.mkDerivation {
    name = "${defconfig}-packageinfo.json";
    src = src;

    buildInputs = with pkgs; [
      perl
      unzip
      which
    ];

    patchPhase = ''
      sed -i "s%/usr/bin/env%$(which env)%" support/scripts/br2-external
    '';

    configurePhase = ''
      make ${defconfig}
    '';

    buildPhase = ''
      make show-info > packageinfo.json
    '';

    installPhase = ''
      cp packageinfo.json $out
    '';
  };

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
}
