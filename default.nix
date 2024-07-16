{
  pkgs ? import <nixpkgs> {},
  src,
  defconfig,
}: let
  inherit (pkgs) stdenv;
  # There are too many places that hardcode /bin or /usr/bin to patch them all
  # (some of them are in unpacked tarballs and aren't revealed until individual
  # packages are enabled). Instead, just build everything in a FHS
  # environment. This has the added bonus of making it less likely for build
  # artifacts to hardcode a path to the nix store.
  makeFHSEnv = pkgs.buildFHSEnv {
    name = "make-with-fhs-env";
    targetPkgs = pkgs:
      with pkgs; [
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
    runScript = "make";
  };
  buildrootBase = {
    src = src;

    patchPhase = ''
      sed -i 's%--disable-makeinstall-chown%--disable-makeinstall-chown --disable-makeinstall-setuid%' \
          package/util-linux/util-linux.mk
    '';

    configurePhase = ''
      ${makeFHSEnv}/bin/make-with-fhs-env ${defconfig}
    '';

    hardeningDisable = ["format"];
  };
in rec {
  packageInfo = stdenv.mkDerivation (buildrootBase
    // {
      name = "${defconfig}-packageinfo.json";

      buildPhase = ''
        ${makeFHSEnv}/bin/make-with-fhs-env show-info > packageinfo.json
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
