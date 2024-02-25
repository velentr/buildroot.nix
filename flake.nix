{
  description = "Flake for building Buildroot using nix";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";

  inputs.treefmt-nix.url = "github:numtide/treefmt-nix";
  inputs.treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";

  outputs = {
    self,
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
  in {
    lib.mkBuildroot = args: import ./default.nix args;

    formatter = forAllSystems (
      system:
        treefmtEval.${system}.config.build.wrapper
    );
    checks = forAllSystems (system: {
      formatting = treefmtEval.${system}.config.build.check self;
    });
  };
}
