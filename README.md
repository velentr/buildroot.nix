<!--
SPDX-FileCopyrightText: 2024 Brian Kubisiak <brian@kubisiak.com>
SPDX-FileContributor: 2024 Litchi Pi <litchi.pi@proton.me>

SPDX-License-Identifier: CC0-1.0
-->

# buildroot.nix

Build [buildroot](https://buildroot.org/) with [nix](https://nixos.org/).

> Why?

Building embedded linux rootfs images using buildroot is (usually)
deterministic, but requires some host system setup to get working. While it
seems simple to tell people "just `sudo apt install` these packages, that ties
you to a specific distribution/version and there's no way to keep that package
list up-to-date.

Nix is able to provide a hermetic and bit-for-bit reproducible build environment
with which to build buildroot. This gives everyone on your team (and CI!) the
same build environment regardless of which distro they are running and what
software they have installed: no more "works on my machine" as your team
grows. Additionally, nix gives you the ability to create a shared remote cache
so developers can automatically reuse builds without having to build a custom
caching layer.

> Why not use nixos?

Buildroot is more familiar to embedded teams and requires less ramp up for
developers. Also, it is easier to integrate third-party or vendor code with
buildroot than it is to integrate with nixos.

> How do I set this up?

Add the following `flake.nix` to the root of your buildroot repo:

```nix
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
        defconfig = "qemu_aarch64_virt_defconfig";
        lockfile = ./buildroot.lock;
        src = self;
      };
    in {
      lockfile = buildrootPackages.packageLockFile;
      default = buildrootPackages.buildroot;
    });
  };
}
```

Make sure to set the appropriate `defconfig` for you hardware. Then, generate
the lockfile to ensure that future builds are deterministic:

```bash
nix build .#lockfile
cp -L result buildroot.lock
```

This step needs to be repeated as packages are added or updated to keep the
lockfile up-to-date.

Once the lockfile is set up, you can build your buildroot images:

```bash
nix build
```
