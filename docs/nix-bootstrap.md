# A Nix store from bunix 0.4.0

Status: proposal, 2026-11-14.  Nothing here is built yet.

(Since then it is built: `docs/nix-usr-system.md` has what is there.
BuildStream's tools and elements that this names are gone, and in git's
history.)

The first steps towards building bunix with Nix instead of BuildStream: a
Nix store whose toolchain is built from source, starting from bunix 0.4.0
and nothing else.  No nixpkgs, no binary cache, no Nix binaries we did not
build.  This document covers the seed, gcc and glibc in the store, and Nix
itself; packages, images and the move away from BuildStream come later, in
their own documents.

## The principles

- **Everything from source, ours.**  The only binaries that enter the store
  are bunix 0.4.0's, once, as the seed; everything after is built from
  source by derivations in this repository.
- **The seed leaves.**  Stage 3's toolchain must have no path to the seed
  in its closure (`nix path-info -r`).  From there on, 0.4.0 is history,
  as the Arch image is for BuildStream's bootstrap today.
- **Pinned and fixed-output.**  Every download is a fixed-output derivation
  with its sha256, as every BuildStream source has its `ref`.  No
  substituters: the store fills only from our own builds.
- **glibc in the store.**  Programs built in Nix load glibc from
  `/nix/store/<hash>-glibc-2.44`, not from `/usr`.  This is for building;
  how the finished system is laid out (UAPI.9's `/usr`) is a later
  decision.

## The shape

```
bunix 0.4.0 (BuildStream)
  ├── nix sysext ................ Phase 1: a nix-daemon to build with
  └── bunix-seed-0.4.0.tar.xz ... Phase 2: the seed
        │
Nix, on a bunix 0.4.0 machine
  stage 0  seed, unpacked and relocated into the store ...... Phase 3
  stage 1  glibc, binutils, gcc built by the seed ........... Phase 4
  stage 2  bash, coreutils, make, ... built by stage 1 ...... Phase 5
  stage 3  glibc, binutils, gcc again: the seed is gone ..... Phase 5
  nix      Nix built in the store, the daemon moves to it ... Phase 6
```

## Phase 1: Nix on bunix 0.4.0

Building a store needs a Nix daemon.  Taking upstream's binary would break
the first principle, so the first Nix is built by BuildStream, as one more
system extension, and is used only until Nix can build itself (Phase 6).

**Nix 2.35.6** (the newest release, 2026-11) needs, from its Meson files:

| | Already in bunix | New elements |
|---|---|---|
| Build | Meson, Ninja, pkgconf, bison, flex, Python | — |
| Libraries | OpenSSL (libcrypto), libarchive, zstd, curl, readline, SQLite (`tools/sqlite.bst`, moved to `base/`) | Boost, BLAKE3, libsodium, Brotli, nlohmann_json, libseccomp, toml11, libgit2, Boehm GC |

Left out: the S3 store (aws-crt-cpp), libcpuid, mimalloc, editline
(readline instead: `-Dlibcmd:readline-flavor=readline`) and the manual
(lowdown).

**Steps**

1. Elements for the nine new libraries, in `base/`, each with an
   `upstreams.yml` entry (the daily check covers them from the start).
2. `base/nix.bst`: Nix with the seccomp sandbox on and documentation off.
3. `sysext/nix.bst`, built as the other extensions are, with:
   - `/nix` on the root file system (a `tmpfiles.d` line: `/usr` is
     read-only, `/` is not);
   - `nix-daemon.socket` and `nix-daemon.service`;
   - the build users: a `nixbld` group, and `auto-allocate-uids = true`
     instead of 32 `nixbld<n>` users;
   - `/etc/nix/nix.conf`:

     ```
     build-users-group = nixbld
     auto-allocate-uids = true
     sandbox = true
     sandbox-fallback = false
     substituters =
     require-sigs = true
     trusted-users = root
     experimental-features = nix-command auto-allocate-uids
     ```

4. `tests/nix.bst`: the daemon starts in a test VM, and
   `nix-build -E 'derivation { name = "t"; system = "x86_64-linux"; builder = "builtin:fetchurl"; ... }'`
   succeeds.  A fixed-output fetch needs no tools, so it tests the daemon
   alone.

**Where:** a bunix 0.4.0 machine with the gcc and nix extensions: the
testbed first.  Its kernel already has user namespaces and seccomp; the
build VM (tools/build-vm) is Ubuntu and not a fair test.

## Phase 2: the seed

**Contents:** `bootstrap/build-env.bst` exactly as 0.4.0 built it (the same
cache keys): the environment every bunix package is built in today, so it
is known to build everything.

- the stage-3 root: GNU bash, coreutils, make, sed, gawk, grep, tar, xz,
  gzip, patch, findutils, diffutils, file, m4, ncurses;
- the final toolchain: gcc 16.2, binutils 2.47, glibc 2.44 (runtime,
  headers, static libraries), the Linux headers;
- bison and Python.

**Two more programs, static,** because inside a Nix build nothing exists
but `/nix/store`: no `/lib64/ld-linux-x86-64.so.2`, so none of the seed's
dynamically linked programs can start until they are rewritten.

- `busybox` (static, linked against 0.4.0's `libc.a`): the shell and `tar`
  that unpack the seed;
- `patchelf` (static): rewrites each program's interpreter and library path
  to the seed's own store path, which is known only once it is unpacked.

**Steps**

1. `bootstrap/nix-seed.bst` (BuildStream): build-env, plus BusyBox and
   patchelf built static, packed as `bunix-seed-0.4.0-x86_64.tar.xz` with
   `busybox` and `patchelf` beside it; file times and owners fixed, so
   the tarball is the same on every build host.
2. Publish the three files as assets of a `seed-0.4.0` GitHub release, and
   pin their sha256 in `nix/seed.nix`.
3. Check: the tarball's sha256 is the same when built on pro13 and in the
   build VM.

## Phase 3: stage 0, the seed in the store

No nixpkgs means no `stdenv` and no `fetchurl` wrapper: these are written
here, in `nix/`, on the `derivation` builtin.

- `nix/fetch.nix`: a fixed-output derivation, `builder = "builtin:fetchurl"`,
  `outputHash` the sha256.  It needs no tools.
- `nix/seed.nix`: fetches `busybox`, `patchelf` and the tarball, and unpacks
  them with `builder = busybox`:
  1. untar into `$out`;
  2. for every ELF file: `patchelf --set-interpreter $out/usr/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 --set-rpath $out/usr/lib/x86_64-linux-gnu`;
  3. gcc's own paths: a wrapper (`$out/bin/cc`) that adds `-B` and
     `-isystem` for the seed's crt files and headers, and the same
     `-dynamic-linker` and `-rpath` as above, to everything it links.
- `nix/package.nix`: `mkPackage { name, version, src, inputs, script }`, the
  counterpart of a BuildStream `manual` element: a `derivation` whose
  builder is a shell from the current stage, whose `PATH` is made from
  `inputs`, and whose `script` holds the configure, build and install
  commands.

**Check:** a hello-world built in a derivation runs, and `readelf -l`
shows its interpreter in the store.

## Phase 4: stage 1, glibc and gcc in the store

1. **glibc 2.44**, `--prefix=$out`, built by the seed's gcc: the first
   package of our own in the store.
2. **binutils 2.47.**
3. **gcc 16.2**, with `--with-native-system-header-dir=${glibc}/include`
   and a **cc-wrapper**, our counterpart of nixpkgs': a small script in
   front of `gcc`/`g++` that adds
   - `-B${glibc}/lib` and `-idirafter ${glibc}/include`,
   - `-Wl,-dynamic-linker,${glibc}/lib/ld-linux-x86-64.so.2`,
   - `-Wl,-rpath,<lib>` for glibc and for every input with a `lib`.

   This is the part with no BuildStream counterpart, because BuildStream
   stages every build into an ordinary `/usr`.  It is where most of the
   work is.
4. **Check:** a C and a C++ program built by stage 1 run, with interpreter
   and `RUNPATH` only in the store, none in the seed.

## Phase 5: stages 2 and 3

The same order as `elements/bootstrap/`:

- **Stage 2:** bash, coreutils, make, sed, gawk, grep, tar, xz, gzip,
  patch, findutils, diffutils, file, m4, ncurses, built by stage 1's gcc
  against stage 1's glibc.
- **Stage 3:** glibc, binutils and gcc again, built with only stage 2's
  tools and stage 1's toolchain.

**Check:** `nix path-info -r` of stage 3's gcc does not contain the seed's
store path.  From here on, a change in the seed no longer reaches what is
built: the seed's own hash is in stage 1's and stage 2's derivations, but
not in what stage 3 links or runs.

## Phase 6: Nix built by Nix

The libraries of Phase 1 (Boost, BLAKE3, libsodium, Brotli, nlohmann_json,
libseccomp, toml11, libgit2, Boehm GC, and SQLite, curl, OpenSSL,
libarchive, zstd, readline), then Nix 2.35.6, all with `mkPackage` and the
stage-3 toolchain.

1. `nix-build nix/nix.nix`: Nix in the store.
2. The daemon moves to it: the nix extension's `nix-daemon.service` runs
   `/nix/var/nix/profiles/system-nix/bin/nix-daemon` (a profile pointing at
   the store's Nix), falling back to the extension's own while the profile
   does not exist.
3. **Check:** the store's Nix builds stage 0 to stage 3 again from scratch,
   on a second machine, and every output path has the same content
   (`nix-build --check`, then a comparison of `nix-store --query --hash`).

The nix extension (Phase 1) is then needed only to start a new machine.

## Reproducibility, compared with BuildStream today

- **Output paths are input hashes,** as BuildStream's strict keys are: a
  change in a dependency rebuilds what depends on it.
- **Bit-for-bit checks become routine:** `nix-build --check` builds again and
  compares, which BuildStream does not do.  Every stage should pass it
  before the next is built on it.
- **Job counts** (`$NIX_BUILD_CORES`) are not in the hash, where BuildStream
  puts `-j8` in every cache key (tools/bst-remote.sh).

## Open questions

- **Hosting the seed:** a GitHub release is simplest.  The seed is then
  fixed for good: re-making it would change every path in the store.
- **Where Nix builds:** the testbed for now.  pro13 does not run bunix; the
  Fly machine and the build VM run other distributions, which Phase 1
  would have to be redone for.
- **Ordinary programs and `/usr`:** Phases 1 to 6 build only the toolchain
  and Nix.  How bunix's packages, `/usr` image, extensions and signatures
  come out of the store is the next document.
- **aarch64:** the same steps, from an aarch64 bunix, when there is one.

## Order of work

| Step | Built with | Done when |
|---|---|---|
| 1. Nix's nine new libraries and `base/nix.bst` | BuildStream | `tests/nix.bst` passes |
| 2. `sysext/nix.bst` on the testbed | BuildStream | a fixed-output fetch builds |
| 3. `bootstrap/nix-seed.bst`, the seed published | BuildStream | the same sha256 on two hosts |
| 4. `nix/fetch.nix`, `seed.nix`, `package.nix`: stage 0 | Nix | hello runs from the store |
| 5. Stage 1: glibc, binutils, gcc, cc-wrapper | Nix | C and C++ programs run, store paths only |
| 6. Stages 2 and 3 | Nix | the seed is not in stage 3's closure |
| 7. Nix's libraries and Nix | Nix | the daemon runs the store's Nix |
| 8. Rebuild on a second machine | Nix | the same output paths, the same bytes |
