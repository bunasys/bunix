# The system out of Nix: /usr, and no store

Status: 2026-11-19.  All six steps of the order of work are done: a
system with no `/nix` boots, and the store-layout system is gone.  Since
then: a network, SSH and Rex in the image; clang and Rust as packages; and
one kernel, Aurora Silicon's, built with them.

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
  puts an image together writes `/etc/passwd` and `/etc/group` from the
  lines of the packages in it (`images/initramfs.sh`, until a system has
  systemd-sysusers), and refuses a name or an id asked for twice.

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

bindgen is 0.73.2 with the two patches of Aurora's source
(`tools/aurora-bindgen/`, here in `files/bindgen/`), for C layouts the
released one gets wrong.  The kernel's build also checks the layout of
everything bindgen generated.

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
`depends` on, as files: no `/nix`, no `depends` files.  The initramfs
(`nix/images/initramfs.nix`) is one such union, packed by the kernel's
`gen_init_cpio`; the `/usr` image, the extensions and their signatures
are others, in the formats bunix already has.  A build that makes an
image names its `contents`, and Nix gives it those packages and all they
need.

No package is yet in two parts for running and for building against, so
an image with glibc has its headers and static libraries too.

## Where things are

```
nix/
  fetch.nix  sources.json     a pinned download; every source, as data
                              (but bindgen's crates: base/bindgen-crates.json)
  architecture.nix            the library directory's name and the loader's path
  bootstrap/                  the store: seed.nix sh.nix package.{nix,sh}
                              stage1.nix stage1/ stage2.nix stage2/
  stage.{nix,sh}              a build with /usr made of system packages
  system-package.{nix,sh}     mkSystemPackage, and what is checked of a result
  autotools.sh                the recipe of an ordinary package
  toolchain.nix  toolchain/   glibc, binutils, gcc
  tools.nix      tools/       what a build runs
  base.nix       base/        after elements/base/; the porting rule is at its top
  boot.nix       boot/        the kernel and its device trees
  images/                     initramfs.{nix,sh}, init.sh
  tests/<name>/  run.sh
files/<package>/              patches, and files a package installs as they are
```

What a person runs, on a builder:

```
nix-build nix/base.nix -A util-linux     one package
bash nix/tests/run.sh                    every test
tools/boot-vm.sh                         on the Mac: build the image and boot it
```

## Open questions

- **Owners and set-user-id.**  Where the list of them lives, and what
  applies it to an image.
- **Account ids.**  Each is a number in its package's script, and two
  packages with the same one are only found out when an image has both.
  The reader of the declarations is in `initramfs.sh`; the `/usr` image
  will need it too.
- **`/etc` and `/var`.**  Which of a package's files outside `/usr` belong
  to its result, and which to the image.  Today a package's `etc/` is
  staged and its `var/` is not.
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
  `elements/base/`, six did; util-linux needed one argument.  The claim
  is "nearly all" until many more have been ported.

## What the image that boots lacks

It is a shell on a console and, given a key, over SSH, with an address
from DHCP: no init system, no kernel modules, no device manager, no
login, no CA certificates, no locales or time zones.  Nothing in it
reads `sysusers.d`: its accounts are made when the image is.

Its kernel has what a Mac mini needs to reach its disk, Ethernet, a USB-C
keyboard and a display on USB-C built in, and installs Apple's device
trees.  None of that has run on a Mac yet: it has booted a virtual
machine only.  The USB-A ports need firmware the image does not have.
There is no kernel configuration for x86_64 yet.

## Order of work

| Step | Done when | |
|---|---|---|
| 1. Staging: a build with a `/usr` made of its dependencies | `nix/tests/usr-staging`, `usr-glibc` pass on both builders | done |
| 2. glibc for `/usr`, built by stage 1's gcc | a program linked against it runs in a staged build, loader `/lib/ld-linux-...` | done |
| 3. binutils and gcc for `/usr` | `nix/tests/usr-toolchain`: C and C++, threads, shared libraries and LTO with no flags, no store path in the results | done |
| 4. tools: bash, coreutils, make and the rest, built by that gcc | `nix/tests/usr-build-environment`: glibc builds again with the system's compiler and tools alone, and comes out the same, file for file | done |
| 5. The initramfs as a union of `/usr` trees | `tools/boot-vm.sh` boots it; `ldd` shows `/usr/lib` paths; there is no `/nix` | done (aarch64) |
| 6. Remove stage 3 and the store-layout packages; move the bootstrap under `nix/bootstrap/` | the tests that remain pass on both builders | done |
