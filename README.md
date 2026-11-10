# bunix (Buna Linux)

An FHS Linux system built from source, declaratively, with
[BuildStream](https://buildstream.build). Its file system follows the UAPI
group's [Linux File System Hierarchy](https://uapi-group.org/specifications/specs/linux_file_system_hierarchy/),
including the multiarch library directory (`/usr/lib/x86_64-linux-gnu`).

Every package is one `.bst` file under `elements/`: where its source comes
from (pinned by checksum), what it builds on, and the commands that build it.
BuildStream builds each element in a sandbox that contains *only* its declared
dependencies, and caches the result under a key derived from the element and
everything it depends on — so a change rebuilds exactly what it affects, and
nothing from the build machine can leak in.

## Using a release

Releases are on this repository's [releases page](https://github.com/bunasys/bunix/releases):
`bunix-x86_64-live.img` is the live system and installer (UEFI, Secure
Boot); the other files are the updates installed systems fetch.  Write it
to a USB stick (`dd`, Fedora Media Writer, Rufus in DD mode), boot it, and
run `bunix-install` (docs/install.md).

With `dd` on Linux, where `/dev/sdX` is the stick (`lsblk` shows which;
everything on it is erased):

```
dd if=bunix-x86_64-live.img of=/dev/sdX bs=4M oflag=direct conv=fsync status=progress
```

`oflag=direct` makes the progress show the stick's real speed, instead of
reaching the end at once and then waiting minutes for the kernel's cache.

On macOS, write to the raw device (`/dev/rdiskN`, after
`diskutil unmountDisk /dev/diskN`), with `bs=4m`.

Updating an installed system (A/B, with automatic rollback; every file is
checked against the signed manifest and its dm-verity signature):

```
/usr/lib/systemd/systemd-sysupdate update
reboot
```

The toolchain, languages and developer tools are system extensions,
enabled one by one: `gcc` (compilers and build tools), `rust` and `swift`
(each on top of gcc), and `devtools` (git, gdb, strace, file, unzip; on its
own):

```
for f in gcc rust swift devtools
  mkdir -p /etc/sysupdate.d/$f.feature.d
  printf '[Feature]\nEnabled=true\n' > /etc/sysupdate.d/$f.feature.d/enable.conf
end
/usr/lib/systemd/systemd-sysupdate update
systemd-sysext refresh
```

Making a release: docs/release.md.

## Building

```
tools/bst-container.sh                                  # shell in the build container
tools/bst-container.sh bst build tests/toolchain.bst    # or run one command
```

BuildStream runs on Linux, so on a Mac it runs in an x86_64 Arch container
under Rosetta; `tools/bst-container.sh` creates it and explains the two
host-specific settings it needs.

On a native x86_64 Linux machine there is nothing to work around:

```
tools/bst-remote.sh build tests/toolchain.bst           # on pro13.home.arpa
BUNIX_BUILD_HOST=box tools/bst-remote.sh build ...      # or another host
```

copies the project over SSH, installs the pinned BuildStream in a virtualenv
there on first use, and runs `bst`. Cache keys depend only on the element
definitions, so they are identical on every machine.

## The toolchain bootstrap

The toolchain is built here, from a binary seed, in three stages — the
sequence Linux From Scratch uses, with BuildStream's sandboxes doing the
isolating:

```
bootstrap/seed.bst       Arch Linux base-devel, pinned by image digest.  The
                         only binaries not built here; nothing from it reaches
                         the final system.

stage 1 (inside the seed)   a cross toolchain for x86_64-bunix-linux-gnu
  python                 build tool for glibc (the seed lacks it), in /tools
  binutils, gcc          cross binutils and gcc pass 1, in /tools
  linux-headers, glibc   the target's kernel headers and C library, in /sysroot
  libstdcxx              libstdc++ for the target

stage 2 (inside the seed)   temporary tools, cross-compiled into /sysroot
  m4 ncurses bash coreutils diffutils file findutils gawk grep gzip make
  patch sed tar xz, binutils pass 2, gcc pass 2

stage 3 (no seed)        /sysroot becomes / (stage3/root.bst); then natively:
  bison, python          temporary build tools
  glibc, binutils, gcc   the final toolchain  ->  bootstrap/toolchain.bst

tests/toolchain.bst      compiles and runs C and C++ programs with the final
                         toolchain, and checks no bootstrap path leaked in
```

The cross triplet's vendor field (`bunix`) differs from the seed's
(`x86_64-pc-linux-gnu`), so stages 1 and 2 genuinely cross-compile: the
compilers cannot find, or link against, anything of the seed's.

## Rust

Rust compilers are written in Rust, and each release builds only with the one
before it. So the bootstrap gets a second binary seed:

```
bootstrap/rust-seed.bst  rustc, cargo and the standard library 1.98.0 from
                         rust-lang.org, pinned by checksum, in /tools/rust.
                         Never reaches the final system.
bootstrap/rust.bst       Rust 1.99.1 from source, with the LLVM it bundles.
                         rustc compiles itself twice (stage 1 with the seed,
                         stage 2 with stage 1), so nothing of the seed is
                         left.  Installed in /usr.
tests/rust.bst           builds and runs a program with rustc and with cargo,
                         and checks nothing refers to /tools
```

Building Rust from source all the way down (mrustc, a C++ implementation of
an old rustc, then every release since) is possible -- Guix does it -- but
takes about twenty sequential compiler builds; the binary seed is the same
trade-off seed.bst makes for gcc.

## The base system

`elements/base/` holds the system's packages, plus the tools needed to
build them (perl, pkgconf, cmake, meson, ninja, gperf, Jinja2). `base.bst`
lists the packages; `tests/base.bst` runs each of their programs once.

`elements/desktop/` holds packages only the desktop has: the DMS shell and
its login screen, niri, Quickshell and Qt, AccountsService, and what builds
them.  They reach a system only through the desktop extension
(`sysext/desktop-content.bst`), never `base.bst`.  Older desktop packages
(Hyprland, GTK 4, Ghostty, Buna Browser) are still in `elements/base/`; a
console install does not get them either, since it is the lists, not the
folders, that decide.

Every system element builds in `bootstrap/build-env.bst` (the stage-3 root
and the final toolchain), listed first in its build-depends, and declares the
libraries and tools it uses beyond that. Nothing else is in its sandbox, so
there is no host library to pick up by accident and optional features are
decided by what an element declares, not by what happens to be installed.

Settings shared by all system elements -- the UAPI.9 directories and the
compiler flags -- are in `include/system.yml`. `project.conf` applies them to
the autotools, make, meson, cmake and cargo element kinds; `manual` elements
include the file themselves.

Sources that build tools would normally download are sources of the element
instead: cargo crates through the `cargo2` source (generated from
`Cargo.lock` by `bst source track`), neovim's bundled dependencies as
`remote` sources at the path its download step checks.

## The system image

```
system/linux.bst     Linux 6.18 LTS: x86_64_defconfig + files/linux/x86_64.fragment,
                     boot drivers built in, the rest signed modules
system/firmware.bst  linux-firmware's files for GPUs, Wi-Fi, Bluetooth, touch
system/rootfs.bst    base.bst + files/rootfs (bunix's /etc and vendor config) +
                     glibc and gcc's runtime libraries, made into a system:
                     build-only files removed, merged /usr, uutils and BusyBox
                     command names, units enabled, users created, stripped
tests/rootfs.bst     stages the root file system alone at / and checks it with
                     its own shell and loader: libraries, UAPI.9 layout, programs
system/esp.bst       the ESP's boot files: shim, signed systemd-boot, bunix.cer
system/shim.bst      Debian's Microsoft-signed shim and MokManager
system/live.bst      bunix-x86_64-live.img (UEFI only): a signed live UKI whose
                     initrd mounts /usr from the medium (files/live)
system/initrd.bst    the installed system's initrd, from the rootfs's own files
system/usr.bst       the rootfs's /usr as a /usr slot: erofs, dm-verity, signature
system/uki.bst       kernel + initrd + usrhash= command line, signed (ukify)
system/disk.bst      bunix-x86_64.raw: an installable disk with two /usr slots
```

**Installed systems.** Two ways onto a disk, both UEFI only; either way the
system updates itself with systemd-sysupdate, A/B, with automatic rollback
(docs/updates.md, step 2):

- `bunix-install` on the live system installs into free space, into a partition
  it replaces, or onto a whole disk, next to Windows if it is there
  (docs/install.md).
- `bunix-x86_64.raw` is written to a whole disk; it creates its root
  partition on first boot.

The live image boots on UEFI machines, with Secure Boot on (no BIOS boot),
written raw to a USB stick (no CD boot). It boots the same signed /usr image
that `bunix-install` writes to disk, read from the medium, with the root
file system in memory.
Build it and fetch it:

```
tools/bst-remote.sh build system/live.bst
ssh pro13.home.arpa 'cd src/bunix && ~/.local/share/bunix-bst/bin/bst artifact checkout system/live.bst --directory ~/bunix-live'
scp pro13.home.arpa:bunix-live/bunix-x86_64-live.img .
```

`tools/boot-test.py <live.img> <uefi|bios> <outdir>` boots it in QEMU (with KVM
when available), types a set of checks on the console (network up, DNS,
HTTPS, the tools start) and saves their output and screenshots.

**Keys.** `keys/` stays out of version control and holds three keys, one
per job, so a leak of one does not give away the others:

| Key | Signs | Trusted by |
| --- | --- | --- |
| `secureboot.key/.crt` ("bunix Secure Boot signing key") | systemd-boot and the kernel images (`system/esp.bst`, `system/uki.bst`, `system/live.bst`) | shim, once enrolled with MokManager |
| `verity.key/.crt` | extension images' dm-verity root hashes (`sysext/gcc.bst`, `rust.bst`, `swift.bst`, `devtools.bst`, `desktop.bst`) | the kernel: `files/linux/verity.crt` is built in |
| `release.key` (OpenPGP) | update manifests (`tools/publish.sh`) | sysupdate: `files/rootfs/usr/lib/systemd/import-pubring.pgp` |

**Secure Boot.** shim, signed by Microsoft, trusts the keys enrolled with
MokManager. On a machine's first boot, MokManager comes up once: choose
"Enroll key from disk" and pick `bunix.cer` on the EFI partition. To make a
new Secure Boot key:

```
openssl req -new -x509 -newkey rsa:2048 -sha256 -nodes -days 3650 \
  -subj "/CN=bunix Secure Boot signing key/" \
  -keyout keys/secureboot.key -out keys/secureboot.crt
```

**Software on a running system.** The toolchain is not in the image; it is
the `gcc` system extension, fetched and verified by systemd-sysupdate and
merged over /usr (`sysext/`, `tools/publish.sh`); git, gdb and strace are
the `devtools` extension.  The image has what administering a machine
takes: iproute2, nftables, OpenSSH (sshd off until enabled), rsync, GNU
tar and grep, cryptsetup, pciutils, usbutils, nvme-cli, smartctl, mokutil,
the time zone database, hostnamectl and timedatectl. How, and how it becomes
the update mechanism for the whole system: `docs/updates.md`.

**Drivers and firmware.** What every machine needs to boot is built into
the kernel; GPU, Wi-Fi, Bluetooth and touch drivers are modules, signed at
build time with a key the build throws away, and loaded by udev for the
hardware a machine has. Their firmware, cut down from linux-firmware to
what PCs and laptops use, is in `/usr/lib/firmware` (`system/firmware.bst`).

## Things the bootstrap had to learn

* **Project variables are part of every cache key.** Adding one to
  `project.conf` rebuilds everything, bootstrap included. System-wide
  settings therefore live in `include/system.yml`, applied per element kind.

* **Artifacts keep no file modes but the executable bit.** BuildStream's
  content-addressed store records whether a file is executable and nothing
  else, so `/tmp`'s 1777 or `/etc/shadow`'s 0640 cannot live in an artifact;
  `system/live.bst` sets them when it packs the image. A file of mode 0000
  (systemd-sysusers writes the shadow files that way) cannot even be stored.

* **Rosetta and new system calls.** The build container is x86_64 under
  Rosetta, which does not translate a few recent syscalls. bubblewrap 0.12+
  needs the new mount API (so it is pinned to 0.11, see
  `tools/bst-container.sh`), and glibc built for kernel ≥ 5.8 drops its
  `faccessat2` fallback — after which `test -x /` is false and every configure
  script rejects the shell. glibc is therefore built with
  `--enable-kernel=%{glibc-min-kernel}` (5.4), which keeps the fallbacks; on
  real hardware it still uses the new calls.
* **libstdc++ and multiarch.** libstdc++ appends the compiler's multilib OS
  directory (`../lib/x86_64-linux-gnu`) to `--libdir`, so it is configured
  with plain `/usr/lib` and still lands in the multiarch `$libdir`.
* **gawk 5.4.1 without MPFR** turns an uninitialised array element into
  `"0"` once it has been compared, which garbles gcc's generated `options.cc`.
  The bootstrap's temporary awk is gawk 5.3.2; the final system's gawk is
  built with MPFR.
* **UAPI.9 and install directories.** glibc takes `sbindir`/`libexecdir`
  from `configparms`, not configure; gcc needs `--libexecdir=/usr/lib`.
  Otherwise their installs create `/usr/sbin` (a symlink on bunix) or
  `/usr/libexec` (absent on bunix).
