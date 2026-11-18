# The system out of Nix: /usr, and no store

Status: proposal, 2026-11-18.  Nothing here is built yet, except where it
says "probed".

`docs/nix-bootstrap.md` ends with an open question: how bunix's packages
and its `/usr` image come out of the store.  This is the answer proposed.

## The decision

- **Nix builds; it is not in what is built.**  A bunix system has no
  `/nix`.  Its programs are in `/usr`, find their loader and libraries at
  the usual paths, and are laid out as UAPI.9 says, as today.
- **The store is the builder's.**  It holds sources, the bootstrap, and
  every package's result, each result being a `/usr` tree.

What boots today (`tools/boot-vm.sh`) is the other thing: programs whose
loader and libraries are store paths.  It proved the toolchain, the
kernel and the boot; its layout is not kept.

## Two kinds of package

| | Bootstrap package | System package |
|---|---|---|
| Is | stage 1 and stage 2 | everything in a bunix image, and the tools that build it |
| Prefix | its own store path | `/usr` |
| Finds its libraries by | paths recorded in it | the loader's default: `/usr/lib/<triplet>` |
| Runs | anywhere the store is | only where its `/usr` is: an image, or a build that staged it |
| Result | the store path | `$out/usr/...` (and `$out/etc/...`) |

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

**Stage 3 goes.**  It is a complete toolchain in the store's layout, and
nothing would be built with it.  With it go gcc's separate libraries
output, its specs file, `libraries` in `mkPackage`, and the store-layout
`packages.nix`.

## How a system package is built

A build needs its dependencies at `/usr`, and each is somewhere else: a
store path of its own.  So a build starts by **staging**, as BuildStream
does:

1. it enters a user namespace of its own, in which it may mount;
2. it overlays the `usr/` of every dependency into one directory;
3. it makes a root with that directory as `/usr`, the store at `/nix`
   (for the source and the script), and `/tmp`, `/dev`, `/proc`;
4. it runs the package's script there: `./configure --prefix=/usr`,
   `make`, `make DESTDIR=$out install`.

Probed, in the builder VM, inside a sandboxed build: a namespace, an
overlay of two directories as one `/usr`, and that tree as the root.  Not
probed: the same on enas-asus, where Nix itself is in a user namespace.

Inside, a program is where it expects everything to be.  A configure
script that records `/usr/bin/sed` has recorded the right thing; a script
that starts with `#!/bin/bash` runs.  The fixes that store-layout
packages needed one by one (bash, Python, perl, util-linux) are not
needed.

## Dependencies are declared, not found

Nix learns what a store-layout package needs at run time by finding store
paths in it.  A system package has none in it, by design, so Nix finds
nothing.  What a package needs is written down, as in a `.bst` element:

- `depends`: needed to run, and so in any image that has the package;
- `buildDepends`: staged for the build only.

An image is the packages asked for and, transitively, their `depends`.

Two checks replace `mustNotDependOn`:

- a system package's result has no `/nix/store` in it anywhere;
- every shared library a program asks for is in the package itself or in
  one of its `depends` (today's check in `package.sh`, with `/usr/lib` for
  the directories).

## The image

The union of the chosen packages' trees, as files: no `/nix`.  The
initramfs is one such union, packed as now by the kernel's
`gen_init_cpio`; the `/usr` image, the extensions and their signatures
are others, in the formats bunix already has.  The kernel is built as it
is today; `tools/boot-vm.sh` does not change.

## What stays, what goes

| Stays | Goes |
|---|---|
| seed, `tools/seed.sh` | `nix/stage3.nix`, `nix/stage3/` |
| stage 1, stage 2 | gcc's `lib` output and specs file |
| `fetch.nix`, `sources.json` | `libraries`, `outputs` in `mkPackage` |
| the sandbox, pinned sources, fixed build time, the strip step | store-layout bash, coreutils, util-linux, perl... in `packages.nix` |
| the kernel package, `initramfs.sh`, `init.sh`, `tools/boot-vm.sh` | `nix/tests/stage3-hello`, `nix/tests/libraries` |
| both builders, both architectures | |

## Open questions

- **Rootless builders.**  Does staging work where Nix runs without root
  (enas-asus)?  If overlays are refused there, the fallback is to copy or
  hard-link the dependencies into the staging directory, which is slower.
- **Two packages, one file.**  An overlay lets the later one win, silently.
  BuildStream reports overlaps; this should too.
- **Multiarch.**  `/usr/lib/<triplet>` as in `project.conf`, which the
  bootstrap stages do not use.  The toolchain is where it starts.
- **`/etc` and `/var`.**  Which of a package's files outside `/usr` belong
  to its result, and which to the image.
- **How many recipes port unchanged.**  The claim is "nearly all"; it is
  a claim until twenty have been ported.

## Order of work

| Step | Done when |
|---|---|
| 1. Staging: a build with a `/usr` made of its dependencies | a hello package builds against a library package, on both builders |
| 2. glibc for `/usr`, built by stage 1's gcc | a program linked against it runs in a staged build, loader `/usr/lib/...` |
| 3. binutils and gcc for `/usr` | gcc builds C and C++, threads, shared libraries and LTO with no flags, and its result has no store path |
| 4. base: bash, coreutils, make and the rest, built by that gcc | the toolchain rebuilds itself using only system packages |
| 5. The initramfs as a union of `/usr` trees | `tools/boot-vm.sh` boots it; `ldd` shows `/usr/lib` paths; there is no `/nix` |
| 6. Remove stage 3 and the store-layout packages | the tests that remain pass on both builders |
