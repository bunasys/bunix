# bunix (Buna Linux)

An FHS Linux system built from source by [Nix](https://nixos.org/nix), for
arm64 (Apple Silicon Macs) and x86-64.  Its file system follows the UAPI
group's [Linux File System Hierarchy](https://uapi-group.org/specifications/specs/linux_file_system_hierarchy/),
including the multiarch library directory (`/usr/lib/aarch64-linux-gnu`,
`/usr/lib/x86_64-linux-gnu`).

A bunix system does not run from a Nix store: it has no `/nix`, its
programs are in `/usr`, and they find their loader and libraries at the
usual paths.  Nix is what builds it.  Each package is built in a sandbox
that has only the packages it declares, from sources pinned by checksum
(`nix/sources.json`), with a toolchain bootstrapped here.

## Using a release

Releases are on this repository's [releases page](https://github.com/bunasys/bunix/releases).

What can be installed today:

- **On an Apple Silicon Mac**, bunix is installed from a system started
  over USB from another Mac (`tools/boot-mac.sh`, then `bunix-install`:
  `docs/nix-usr-system.md`, "On a Mac").  Since 0.4.1 a release has the
  files of an update, for both architectures, and no image to install
  from yet.
- **On an x86-64 PC**, the last image to install from is 0.4.0's live
  image, which BuildStream built, with the desktop.  A system installed
  from it stays on 0.4.0: it does not find the later releases
  (`docs/release.md`).

A system that Nix built updates itself from the latest release:

```
bunix update
systemctl reboot
```

The new version goes beside the running one, and the system goes back by
itself from a version that does not start.  Every file is checked against
a signed list, and `/usr` against its signed hash (`docs/updates.md`).

What a machine does not need to run is in system extensions, each
downloaded and laid over `/usr` when it is turned on:

```
bunix ext                    # the extensions, and which are on
bunix ext enable devtools    # git, gdb, strace, file, bsdtar and unzip, Node.js, Nix
bunix ext enable llvm        # clang and lld, make, cmake, meson, ninja
```

Other programs are built on the machine, by the llvm extension, from
recipes it brings, and installed in `/usr/local`, which is on the root
partition:

```
bunix install                # the packages there are recipes for
bunix install htop
```

`bunix`, the llvm extension and `/usr/local` are in systems after 0.4.1.
A 0.4.1 updates by `systemd-sysupdate update`, and has the devtools
extension by a file in `/etc` (`docs/nix-usr-system.md`).

## Building

Builds run on Linux: for arm64 in a virtual machine on an Apple Silicon
Mac (`tools/nix-builder/lima.yaml` sets it up, with the repository at
`/bunix`), for x86-64 on a PC with Nix in a home directory
(`tools/nix-builder/home-store/nix.conf`).  In the Mac's builder (on the
PC, with the checkout's path in place of `/bunix`):

```
nix-build /bunix/nix/base.nix -A util-linux      # one package
nix-build /bunix/nix/images/system.nix           # the system, as an image for memory and for a /usr slot
nix-build /bunix/nix/images/disk.nix             # a disk with bunix installed
```

```
nix/
  bootstrap/       the store's own start: a seed, and two stages built with it
  toolchain.nix    glibc, binutils, gcc
  tools.nix        what a build runs
  base.nix         the system's packages
  boot.nix         the kernel; for Apple Silicon Macs their boot loader and U-Boot
  packages.nix     what a person installs on their machine: recipes
  images/          what is made of packages: the system, the initrd, the kernel
                   image, a disk, an update's files, the extensions
```

## Testing

In virtual machines, started from an Apple Silicon Mac; with
`BUNIX_ARCHITECTURE=x86_64` in front, the same for x86-64, built and
started on the x86-64 builder (`tools/test-machine.sh`):

```
tools/boot-vm.sh [disk] [check]     boot the system, from memory or from a disk
tools/install-test.sh               install it on two disks, and start them
tools/update-test.sh                update it, refuse what is not signed, go back from a bad update
tools/release-test.sh <directory> <version before>
                                    update to a release before it is uploaded
tools/secure-boot-test.sh           x86-64 with Secure Boot on: start, and refuse a changed kernel image
```

## Documents

- `docs/nix-usr-system.md`: the design, what works, and what does not yet.
- `docs/release.md`: making a release.
- `docs/updates.md`: how a running system is updated and extended.
- `docs/dependencies.md`: the daily check of every source for new
  releases and known vulnerabilities.

## Keys

Three keys, one per job, so that a leak of one does not give away the
others.  None is in the repository, and no build reads one: a hash is
signed outside the build, which is given the signature
(`docs/release.md`).

| Key | Signs | Trusted by |
| --- | --- | --- |
| image key (`keys/verity.crt`) | the hash of `/usr`, and of each extension (`tools/sign.sh`) | the kernel, which has the certificate built in |
| release key (OpenPGP) | the list of a release's files (`tools/sign-list.sh`) | sysupdate: `import-pubring.pgp` in the system |
| Secure Boot key (`keys/secureboot.crt`) | the x86-64 kernel image (`tools/sign-kernel-image.sh`) | PCs that enrolled it with shim, for 0.4.0 and before; none that takes a Nix-built release yet |

## Not ported from BuildStream yet

bunix was built by [BuildStream](https://buildstream.build) up to 0.4.0,
for x86-64 alone.  An element is removed from `elements/` once Nix builds
what it built, and BuildStream's tooling is gone; what is left there is
kept to port from, and no longer builds:

- the desktop (niri, the DMS shell and its login screen, GTK 4, Ghostty,
  PipeWire, Mesa, fonts) and its extension;
- the gcc, rust and swift extensions; Rust built from source, Go and Zig;
- Hudhud, the browser (`docs/browser.md`; its Mac build,
  `tools/build-macos.sh`, reads the pinned versions from these elements);
- programs of the x86-64 system that the Nix one does not have: BusyBox
  and uutils' commands, bind, nftables, WireGuard's tools, neovim, less,
  htop, ripgrep, rsync, the time zones, and tools for a PC's hardware;
- the live image, and of Secure Boot what a new install needs (shim,
  and systemd-boot signed);
- the tests of these (`elements/tests/`, and `tools/boot-test.py` with
  its checks).

Four elements stay though Nix builds their part, for what they still
have beyond it: the kernel's (BTF, its types for BPF tools), the
initrd's (graphics drivers, Plymouth's boot splash), the ESP's (shim)
and the root file system's (what the x86-64 system is made of).  Three that are gone have no package of the same extent: the full
Python of a running system, and the tool that signed a release's list
with the SQLite it needed.  Like every removed element they are in git:
`git show v0.4.0:elements/base/python.bst`.
