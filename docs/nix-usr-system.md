# The system out of Nix: /usr, and no store

Status: 2026-11-19.  All six steps of the order of work are done: a
system with no `/nix` boots, and the store-layout system is gone.  Since
then: a network, SSH and Rex in the image; clang and Rust as packages;
one kernel, Aurora Silicon's, built with them; Wi-Fi (iwd, with the
system bus it needs); Aurora's boot loader for Apple Silicon Macs; and
systemd as the init system, in place of a script.
On 2026-11-19 it booted a real Mac, a 13-inch MacBook Pro M1, from
memory, and was logged into over Wi-Fi.  A machine with a partition
named bunix-root keeps `/var`, `/home` and `/root` on it; the system
itself is still booted into memory.

`docs/nix-bootstrap.md` ends with an open question: how bunix's packages
and its `/usr` image come out of the store.  This is the answer.

## The decision

- **Nix builds; it is not in what is built.**  A bunix system has no
  `/nix`.  Its programs are in `/usr`, find their loader and libraries at
  the usual paths, and are laid out as UAPI.9 says, as today.
- **The store is the builder's.**  It holds sources, the bootstrap, and
  every package's result, each result being a `/usr` tree.

The first system that booted was the other thing: programs whose loader
and libraries are store paths.  It proved the toolchain, the kernel and
the boot; its layout is not kept, and `tools/boot-vm.sh` now boots a
system made as below.

## Two kinds of package

| | Bootstrap package | System package |
|---|---|---|
| Is | stage 1 and stage 2 | everything in a bunix image, and the tools that build it |
| Made by | `mkPackage` (`nix/package.nix`) | `mkSystemPackage` (`nix/system-package.nix`) |
| Prefix | its own store path | `/usr` |
| Built in | Nix's sandbox | a staged root, inside Nix's sandbox |
| Finds its libraries by | paths recorded in it | the loader's default: `/usr/lib/<triplet>` |
| Runs | anywhere the store is | only where its `/usr` is: an image, or a build that staged it |
| Result | the store path | `$out/usr/...`, `$out/etc/...`, and the file `$out/depends` |
| What it needs to run is known by | Nix finding store paths in it | its `depends`, written down |

## The chain

```
seed ─ stage 1 (store: glibc, binutils, gcc)
     ─ stage 2 (store: bash, make, tar, ...)
     ─ toolchain (/usr: glibc, binutils, gcc)   built by stage 1's gcc, stage 2's tools
     ─ tools (/usr: bash, coreutils, make, ...) built by the toolchain, stage 2's tools
     ─ every other package (/usr)               built by the toolchain and the tools
```

glibc, binutils, gcc and about fifteen tools are built twice: once to
build with, once to ship.  `elements/bootstrap/` does the same today.

A group of packages built before the system has tools of its own says so
once, where the group is defined (`bootstrapTools`): stage 1's and stage
2's programs are then on PATH after `/usr/bin`.  The toolchain and the
tools have them; the packages after do not, and their authors never
meet the idea.  Those are built with `buildEnvironment`: the system's
compiler and tools, as BuildStream's elements are with
`bootstrap/build-env.bst`.

The compiler of those packages is gcc.  The kernel is the first thing
built with clang (below); the direction is clang for everything but
glibc, a group of packages at a time.

The tools are GNU's, and an image ships the same ones: GNU coreutils in
place of uutils', and no BusyBox.  What BusyBox supplied (grep, sed, awk,
tar, gzip, wget, ip, traceroute, which, strings, lsof) comes from GNU's
packages, already among the tools, and from iproute2, curl and a few
small packages, to be ported.

There was a stage 3: a complete toolchain in the store's layout, with
packages built by it.  Nothing of the system was built with it, and it
is removed.

## How a system package is built

A build needs its dependencies at `/usr`, and each is somewhere else: a
store path of its own.  So a build starts by **staging** (`nix/stage.sh`),
as BuildStream does:

1. it enters a user namespace of its own, in which it may mount;
2. it lays the `usr/` of every dependency over the others, as one
   read-only `/usr`, and copies their `etc/` into one `/etc`;
3. it makes a root with that `/usr`, the store read-only at `/nix` (for the
   source and the script), its result writable, and `/tmp`, `/dev`,
   `/proc`;
4. it runs the package's script there: `./configure --prefix=/usr`,
   `make`, `make DESTDIR=$out install`.

Inside, a program is where it expects everything to be.  A configure
script that records `/usr/bin/sed` has recorded the right thing; a script
that starts with `#!/bin/bash` runs.  The fixes that store-layout
packages needed one by one (bash, Python, perl, util-linux) are not
needed.

- **Two packages, one file.**  If two staged packages have the same path
  under `/usr`, the build fails and names it.  (Left to the overlay, the
  winner would be whichever package's store hash sorts first.)
- **The build is root, and nobody.**  Root inside its namespace, which is
  what lets it mount; no user at all outside.  A recipe that insists on
  not being run as root is told otherwise, as the `.bst` elements for
  coreutils and tar already do.
- **Owners, set-user-id and capabilities are not a package's.**  A build
  cannot give a file to another user or make it set-user-id, and the
  store would not keep either.  They are applied when an image is put
  together, as `elements/base/util-linux.bst` notes today; where that list
  lives is an open question below.
- **An account is a package's to ask for, and the image's to make.**  A
  package that needs one installs a line in `/usr/lib/sysusers.d/`,
  systemd's format, with the id written out:
  `u sshd 74 "sshd privilege separation" /usr/share/empty.sshd`.  What
  puts an image together makes the accounts of the packages in it, with
  systemd-sysusers (`images/system.sh`).

## One build, two packages

gcc's run-time libraries (`libstdc++.so.6`, `libgcc_s.so.1`, the
sanitizers') are what a C++ program needs to run; the compiler is not.
gcc is built once, as `gccWhole`, and shipped as two packages, each made
by copying its part of that result: `gccLibraries` (11 MB) and `gcc`,
which depends on it.  A package with a C++ program depends on
`gccLibraries`, and an image with it has no compiler
(`nix/tests/usr-cxx-package`).

A package made from another's result has a `version` where others have a
`source`.  BuildStream does this with a `filter` element.

## A program built elsewhere

Rex is published as a program, not as source.  Its package says
`builtElsewhere = true`: the file is shipped as published, not stripped,
and may name its builder's store as text.  It is still checked for what
makes it start here: this system's loader, and libraries among its
`depends`.

Rust is the other one: rustc, cargo, rustfmt, the standard library and
its source, as the Rust project publishes them, each archive pinned.  They are in
`/usr/lib/rust`, where rustc finds its libraries beside itself, with
links in `/usr/bin`.  `elements/bootstrap/rust.bst` builds Rust from
source with such a download as its seed; that is not ported.

## clang, and the kernel

LLVM, clang and lld are one package, `llvm`, built from source by gcc.
bindgen is built by cargo from its crates, each pinned
(`base/bindgen-crates.json`), with no network.

There is one kernel: Aurora Silicon's, which is Linux with the drivers
and device trees of Apple Silicon Macs.  It is built with clang and
LLVM's linker (`LLVM=1`), with its Rust drivers, on top of the source's
own `asahi.config`; `boot/linux/aarch64.config` has what bunix adds, each
line with its reason, and the build fails if one of them is not in the
final configuration.  The same image boots a virtual machine.

Aura, Aurora's boot loader (from m1n1), is a package too (`boot.nix`):
built by clang and LLVM's linker, its Rust part by cargo with no network,
from the crates of `boot/aura-crates.json` and one from a repository at a
pinned commit, against Rust's libraries for a machine with no operating
system (`rust-std-aarch64-none`).  It installs three images in
`/usr/lib/aura`: Stage 1 with no configuration, which waits for a
computer on USB; and beside them aura's tools for that computer, and a
piece they would otherwise need an assembler for.  Nothing installs it
on a Mac yet: it is loaded into memory (below).

bindgen is 0.73.2 with the two patches of Aurora's source
(`tools/aurora-bindgen/`, here in `files/bindgen/`), for C layouts the
released one gets wrong.  The kernel's build also checks the layout of
everything bindgen generated.

## On a Mac

`tools/boot-mac.sh t8103-j293` boots bunix on an Apple Silicon Mac from
another Mac, over a USB-C cable, into memory: the kernel, the device tree
of that model, and the image.  The system is not on the Mac's disk;
what it keeps from boot to boot may be ("A disk", below).

The Mac has to be waiting for it, which takes one change to its disk, by
its owner: a small container beside macOS that holds a boot loader in
proxy mode.  The Asahi Linux installer makes one and nothing else, in
expert mode (`curl https://alx.sh | EXPERT=1 sh`, "Tethered boot (m1n1,
for development)"): it shrinks macOS by 2.5 GB and finishes in the Mac's
recovery mode.  Holding the power button at start-up then chooses
between macOS and waiting on USB.  Deleting the container and growing
macOS back undoes it.

What waits is Asahi's m1n1.  `boot-mac.sh` has it start aura, the one
built here, and aura starts the kernel.

Firmware is the machine's (below): for Wi-Fi, the files are in the Mac's
own macOS (`/usr/share/firmware/wifi`), and `asahi_firmware.wifi`,
Asahi's tool that Aurora's installer carries, makes of them an archive
with `/vendorfw` in it.
`BUNIX_FIRMWARE` names that archive; it is put before the image, and the
kernel is told where to look.  It is not in this repository, nor in any
package.

Tried on the 13-inch MacBook Pro M1 (J293): the screen and the laptop's
keyboard are the console, the internal disk's bunix-root is checked and
mounted, and Wi-Fi joins a WPA3 network, by itself from the second time
on.  A network to another computer over the
USB cable does not work: in this kernel a Mac's port, as a USB device,
is seen by the other computer and never configured, as Aurora's own
notes say of it.  `/usr/lib/bunix/usb-link` sets such a link up
(`images/usb-link.sh`), for the day it does.

### A disk

A machine with a partition for it keeps `/var`, `/home` and `/root`
there: sshd's keys (`/var/lib/sshd`), so the machine is the same machine
to SSH at every boot, the networks iwd has joined, the journal.  `/usr`
and `/etc` are still the image's.

The image mounts nothing: it is for any machine.  Which partition is a
machine's is said when it is booted: `tools/boot-mac.sh` takes its name
(`BUNIX_ROOT=bunix-root`) and gives systemd the mounts on the kernel's
command line (`systemd.mount-extra=`), and with them an id for the
machine, made of the Mac's serial number: `/etc` is new at every boot,
and the journal on the disk is the machine's by that id.  By name and not by type, as
systemd would find it by itself: another Linux on the same disk has a
root partition of that type too.

Nothing here makes the partitions; on the first Mac they were made by
hand, from bunix itself, in the space its owner had taken from macOS
beside the 2.5 GB boot container:

```
sfdisk --append /dev/nvme0n1     two lines: 1 GiB, type EFI system,
                                 name bunix-esp; 28 GiB, type root
                                 (64-bit Arm), name bunix-root
mkfs.vfat -F 32 -n BUNIX-ESP /dev/nvme0n1p5
mkfs.ext4 -L bunix-root /dev/nvme0n1p6
```

and 5.5 GB were left free.  Deleting the two entries undoes it.

### Where this is going

What bunix is on x86 (`docs/updates.md`,
`files/rootfs/usr/lib/repart.d`, `sysupdate.d`): `/usr` read-only on a
partition of its own, in two slots of 2 GB, one running and one to go
back to, written by systemd-sysupdate; extensions as sysext; and a
writable root partition with `/etc`, `/var` and `/home`.

The first Mac's disk is laid out for that.  bunix-root has the type and
the directories of that root partition, and becomes it by gaining `/etc`.
bunix-esp is empty, and is for a kernel and a boot loader that need no
cable.  The free space is the two slots, with their integrity data and
signatures, for systemd-repart to make.  Not there yet: `/etc` on the
disk, anything on the ESP, and a `/usr` on disk.

## Dependencies are declared

Nix learns what a bootstrap package needs at run time by finding store
paths in it.  A system package has none in `usr/` or `etc/`, by design.
What it needs is written down, as in a `.bst` element:

- `depends`: needed to run, and so in any image that has the package;
- `buildDepends`: staged for the build only.

The build writes `depends` into the result as the file `$out/depends`:
the store paths of what the package needs to run.  It is the one file of
a system package that names the store.  Nix finds those paths as it does
in any package, and so can answer "this package and all it needs", for
staging and for images; the system never reads the file, and an image
leaves it out.

Checked of every system package when its build ends (`system-package.sh`,
`stage.nix`), each with a test that a package breaking it is refused
(`nix/tests/usr-rejects`):

- no file in it names the store, and no link points into it;
- every script in its `/usr/bin` is run by something the package has or
  declares (`#!/bin/sh` is bash's);
- the only store paths Nix finds in it are its `depends`;
- every shared library a program in it asks for is in the package or in
  its `depends`, not merely in a `buildDepends`;
- libraries are in `/usr/lib/<triplet>`, and there is no `/usr/lib64`,
  `/usr/libexec` or `/usr/sbin`.

Not checked, because nothing shows it at build time: a program the
package runs by name from inside another (`sed` in a script, `sh` through
`system()`) that no `depends` provides.

## The image

The union of the chosen packages' `usr/` and `etc/` trees, with what they
`depends` on, as files: no `/nix`, no `depends` files.  The system
(`nix/images/system.nix`) is one such union, with bunix's configuration
over it, packed by the kernel's `gen_init_cpio` as an initramfs; the
`/usr` image, the extensions and their signatures are others, in the
formats bunix already has.

systemd is its init system.  bunix's configuration is `files/rootfs`'s
where the system on x86 has the same (the network's files, the journal,
the console's unit), and `images/system/` where this one differs yet:
which units run (one preset file), sshd's unit without PAM and with
its keys in `/var`, a console that is root's shell with no login, root
without a password, a journal that is on disk only where there is one,
and an address asked for by the network card's own.  systemd's own tools make the
accounts, enable the preset's units and compile udev's hardware database
on the tree before it is packed.  The key that may log in over SSH comes
on the kernel's command line as a credential of systemd's, which sshd's
unit takes: it is for that boot, beside root's own keys.  A build that makes an
image names its `contents`, and Nix gives it those packages and all they
need.

No package is yet in two parts for running and for building against, so
an image with glibc has its headers and static libraries too.

## Where things are

```
nix/
  fetch.nix  sources.json     a pinned download; every source, as data
                              (but crates: base/bindgen-crates.json,
                              boot/aura-crates.json)
  architecture.nix            the library directory's name and the loader's path
  bootstrap/                  the store: seed.nix sh.nix package.{nix,sh}
                              stage1.nix stage1/ stage2.nix stage2/
  stage.{nix,sh}              a build with /usr made of system packages
  system-package.{nix,sh}     mkSystemPackage, and what is checked of a result
  autotools.sh  meson.sh      the recipe of an ordinary package
  toolchain.nix  toolchain/   glibc, binutils, gcc
  tools.nix      tools/       what a build runs
  base.nix       base/        after elements/base/; the porting rule is at its top
  boot.nix       boot/        the kernel and its device trees; the boot
                              loader of Apple Silicon Macs
  images/                     system.{nix,sh}, system/ (its own
                              configuration), usb-link.sh
  tests/<name>/  run.sh
files/<package>/              patches, and files a package installs as they are
```

What a person runs, on a builder:

```
nix-build nix/base.nix -A util-linux     one package
bash nix/tests/run.sh                    every test
tools/boot-vm.sh                         on the Mac: build the image and boot it
tools/boot-vm.sh check                   boot it, and ask systemd if all started
tools/boot-mac.sh t8103-j293             boot it on another Mac, over USB
```

## Open questions

- **Owners and set-user-id.**  Where the list of them lives, and what
  applies it to an image.
- **Account ids.**  Each is a number in its package's script, and two
  packages with the same one are only found out when an image has both.
  systemd's own accounts get the numbers sysusers gives them when the
  image is made, which move when a package with an account joins.  Files on a disk are owned by those numbers now, so
  one that changes between images is no longer harmless.
- **`/etc` and `/var`.**  Which of a package's files outside `/usr` belong
  to its result, and which to the image.  Today a package's `etc/` is
  staged and its `var/` is not; recipes remove the `var/` and `run/` they
  install, and systemd-tmpfiles makes what programs keep state in.  `/etc`
  is the image's and new at every boot, where the goal has it on the
  root partition: how a package's `etc/` reaches an `/etc` that outlasts
  an update is open (on x86, a copy in `/usr` and tmpfiles).  sshd's keys
  are in `/var/lib/sshd` only because `/etc` is not kept.
- **A package in two parts, for running and for building against.**  An
  image with glibc has its headers and static libraries; one with ncurses
  has its .pc files.  gcc is split by hand (above); the rest are not.
- **Scripts in glibc.**  ldd, sotruss, tzselect and xtrace are bash
  scripts, and glibc cannot depend on bash, which depends on glibc.  They
  are left out for now; they belong in a small package of their own.
- **libgcc_s.**  glibc loads it by name when a thread is cancelled or
  exits early, which no check can see, and glibc cannot depend on a
  package built from it.  Every image lists `gccLibraries` in its contents.
- **Locales and time zones.**  glibc has none compiled: only the C locale
  works, and no zone can be named.
- **How many recipes port unchanged.**  Of the first seven from
  `elements/base/`, six did; util-linux needed one argument.  systemd is
  ported with what needs a library not yet here turned off
  (`base/systemd.sh`).  The claim is "nearly all" until many more have
  been ported.
- **Python's modules.**  The Python that builds run has only the modules
  that need no library.  zlib's is a package of its own, compiled from
  Python's source and laid over it (`base/python-zlib.sh`); whether the
  next ones go the same way, or a system's Python is built whole, is
  open.

## What the image that boots lacks

It is systemd with a network (networkd, resolved, timesyncd), Wi-Fi
(iwd), sshd, and root's shell on the console.  It has no login (PAM is
not ported: the console asks nobody who they are, and SSH takes keys
only), no kernel modules, no CA certificates, no locales or time zones,
no firewall.  A Wi-Fi network is joined once by hand, with `iwctl`, and
again by itself where there is a disk to remember it on.  The machine's
id is new at every boot, `/etc` being in memory, unless the command line
gives it one.  A machine told of a partition that is not there comes up
in memory all the same.

Of systemd, not on yet, each for want of a library: PAM, polkit,
cryptsetup (dm-verity), curl and so sysupdate, the TPM, EFI, and seccomp,
without which systemd's own services are not confined to the system
calls they need (`base/systemd.sh`).

Suspend is systemd's and the kernel's.  On the 13-inch MacBook Pro M1 it
was asked for once (`systemctl suspend`), and opening the lid woke it,
with Wi-Fi and the disk as they were; logind suspends when the lid
closes.  How long a battery lasts asleep is not measured.

Its kernel has, built in because nothing loads modules, what an M1
laptop and a Mac mini need to reach the disk, Ethernet, Wi-Fi, a
keyboard (USB, and the M1 laptops' own), a display on USB-C, and a
network over a USB cable to another computer; and it installs Apple's
device trees.  What has run on a Mac is in "On a Mac"; the Mac mini's
parts (Ethernet, the display on USB-C) have not.  There is no kernel
configuration for x86_64 yet.

Firmware is the machine's, not a package: Apple's Wi-Fi firmware is in
each Mac's own macOS, and is added to the image when that Mac is booted
(`boot/linux/aarch64.config`); the USB-A ports of a Mac mini need
firmware too, and have none.  The regulatory database is a package.

## Order of work

| Step | Done when | |
|---|---|---|
| 1. Staging: a build with a `/usr` made of its dependencies | `nix/tests/usr-staging`, `usr-glibc` pass on both builders | done |
| 2. glibc for `/usr`, built by stage 1's gcc | a program linked against it runs in a staged build, loader `/lib/ld-linux-...` | done |
| 3. binutils and gcc for `/usr` | `nix/tests/usr-toolchain`: C and C++, threads, shared libraries and LTO with no flags, no store path in the results | done |
| 4. tools: bash, coreutils, make and the rest, built by that gcc | `nix/tests/usr-build-environment`: glibc builds again with the system's compiler and tools alone, and comes out the same, file for file | done |
| 5. The image as a union of `/usr` trees | `tools/boot-vm.sh` boots it; `ldd` shows `/usr/lib` paths; there is no `/nix` | done (aarch64) |
| 6. Remove stage 3 and the store-layout packages; move the bootstrap under `nix/bootstrap/` | the tests that remain pass on both builders | done |
