# The system out of Nix: /usr, and no store

Status: 2026-11-19.  Steps 1 to 3 of the order of work are built and
tested on both builders; the rest is proposed.

`docs/nix-bootstrap.md` ends with an open question: how bunix's packages
and its `/usr` image come out of the store.  This is the answer.

## The decision

- **Nix builds; it is not in what is built.**  A bunix system has no
  `/nix`.  Its programs are in `/usr`, find their loader and libraries at
  the usual paths, and are laid out as UAPI.9 says, as today.
- **The store is the builder's.**  It holds sources, the bootstrap, and
  every package's result, each result being a `/usr` tree.

What `tools/boot-vm.sh` boots today is the other thing: programs whose
loader and libraries are store paths.  It proved the toolchain, the
kernel and the boot; its layout is not kept.

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
     ─ base (/usr: bash, coreutils, make, ...)  built by the toolchain, stage 2's tools
     ─ every other package (/usr)               built by the toolchain and base
```

glibc, binutils, gcc and about fifteen tools are built twice: once to
build with, once to ship.  `elements/bootstrap/` does the same today.

A group of packages built before the system has tools of its own says so
once, where the group is defined (`bootstrapTools`): stage 1's and stage
2's programs are then on PATH after `/usr/bin`.  The toolchain and base
have them; the packages after base do not, and their authors never meet
the idea.

**Stage 3 goes.**  It is a complete toolchain in the store's layout, and
nothing is built with it.  With it go gcc's separate libraries output,
its specs file, `libraries` in `mkPackage`, and the store-layout
`packages.nix`.

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
- the only store paths Nix finds in it are its `depends`;
- every shared library a program in it asks for is in the package or in
  its `depends`, not merely in a `buildDepends`;
- libraries are in `/usr/lib/<triplet>`, and there is no `/usr/lib64`,
  `/usr/libexec` or `/usr/sbin`.

Not checked, because nothing shows it at build time: a program the
package runs by name (`sh`, `sed`) that no `depends` provides.

## The image

The union of the chosen packages' `usr/` and `etc/` trees, with what they
`depends` on, as files: no `/nix`, no `depends` files.  The initramfs is
one such union, packed as now by the kernel's `gen_init_cpio`; the `/usr`
image, the extensions and their signatures are others, in the formats
bunix already has.  The kernel is built as it is today;
`tools/boot-vm.sh` does not change.

## What stays, what goes

| Stays | Goes |
|---|---|
| seed, `tools/seed.sh` | `nix/stage3.nix`, `nix/stage3/` |
| stage 1, stage 2 | gcc's `lib` output and specs file |
| `fetch.nix`, `sources.json` | `libraries`, `outputs` in `mkPackage` |
| the sandbox, pinned sources, fixed build time, the strip step | store-layout bash, coreutils, util-linux, perl... in `packages.nix` |
| the kernel package, `initramfs.sh`, `init.sh`, `tools/boot-vm.sh` | `nix/tests/stage3-hello`, `nix/tests/libraries` |
| both builders, both architectures | |

Where the files will be, once stage 3 is gone:

```
nix/
  fetch.nix  sources.json  architecture.nix
  bootstrap/   seed.nix sh.nix package.{nix,sh} stage1.nix stage1/ stage2.nix stage2/
  stage.{nix,sh}  system-package.{nix,sh}
  toolchain.nix  toolchain/*.sh
  base.nix       base/*.sh         one .nix and one directory for each group,
  desktop.nix    desktop/*.sh      as elements/ has them
  images/        initramfs.{nix,sh} init.sh ...
  tests/<name>/  run.sh
```

## Open questions

- **Owners and set-user-id.**  Where the list of them lives, and what
  applies it to an image.
- **`/etc` and `/var`.**  Which of a package's files outside `/usr` belong
  to its result, and which to the image.  Today a package's `etc/` is
  staged and its `var/` is not.
- **Default flags.**  `include/system.yml` gives every element `-O2 -pipe
  -fno-plt` and `-Wl,-O1,--as-needed`; nothing does that here yet.
- **Patches.**  No package has needed one yet; `.bst` elements have a
  `patch` source kind.
- **How many recipes port unchanged.**  The claim is "nearly all"; it is
  a claim until twenty have been ported.

## Order of work

| Step | Done when | |
|---|---|---|
| 1. Staging: a build with a `/usr` made of its dependencies | `nix/tests/usr-staging`, `usr-glibc` pass on both builders | done |
| 2. glibc for `/usr`, built by stage 1's gcc | a program linked against it runs in a staged build, loader `/lib/ld-linux-...` | done |
| 3. binutils and gcc for `/usr` | `nix/tests/usr-toolchain`: C and C++, threads, shared libraries and LTO with no flags, no store path in the results | done |
| 4. base: bash, coreutils, make and the rest, built by that gcc | the toolchain rebuilds itself using only system packages | |
| 5. The initramfs as a union of `/usr` trees | `tools/boot-vm.sh` boots it; `ldd` shows `/usr/lib` paths; there is no `/nix` | |
| 6. Remove stage 3 and the store-layout packages; move the bootstrap under `nix/bootstrap/` | the tests that remain pass on both builders | |
