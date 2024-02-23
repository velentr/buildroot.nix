{
  pkgs ? import <nixpkgs> {},
  defconfig,
}: let
  inherit (pkgs) stdenv;
in {
  packageInfo = {src}:
    stdenv.mkDerivation {
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
}
