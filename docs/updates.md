# Delivering software and updates to a running bunix

Status: steps 1 and 2 built and tested (2026-11-03); step 3 is design.
Written 2026-11-02.

## The problem

Two needs, one mechanism:

1. **Now:** a booted bunix should be able to download the toolchain (gcc,
   binutils, headers, make, pkgconf, later Rust) and compile software, without
   the toolchain living in the base image for everyone.
2. **Later:** an installed bunix should update itself: the whole system,
   safely, with a way back when an update does not boot.

Whatever delivers the toolchain is the update mechanism's first user, so it
should be the same mechanism.

## What "safe" means here

* **Authentic.** Only bytes built and signed by bunix run.  A compromised
  mirror, a man-in-the-middle, or a tampered disk must not be able to change
  what executes.
* **Atomic.** A machine is on the old version or the new one, never on a mix.
  A power cut halfway through an update leaves the old version working.
* **Recoverable.** A new version that does not boot is rolled back
  automatically.
* **Fresh and monotonic.** A mirror cannot hold a machine on an old,
  vulnerable version forever (freeze attack), or serve it an older signed
  version (rollback attack).
* **Tested as shipped.** What a machine runs is exactly what CI built and
  tested -- not a combination of package versions nobody tested together.

## Options considered

| Approach | Examples | Fit for bunix |
| --- | --- | --- |
| Per-package binary package manager | apk, pacman, dpkg/apt, rpm/dnf | Changes /usr file by file, runs maintainer scripts; every machine becomes a unique combination of versions.  Not atomic without extra layers (snapper, etc.).  Would need a second packaging of everything BuildStream already composes. |
| File-level content-addressed trees | OSTree, composefs, bootc (OCI images + composefs) | Atomic, deduplicated deltas.  More machinery (a repository format, its own tooling, or a container registry); bootc assumes the OCI/podman stack. |
| Image-based, partition A/B | systemd-sysupdate, RAUC, Mender, SWUpdate, ChromeOS | Atomic and simple: a whole verified /usr image is the unit.  Full-image downloads (no deltas yet in sysupdate). |
| Image-based extensions | systemd-sysext / confext | Optional bundles (like the toolchain) as signed images overlaid on /usr; nothing is unpacked into the base. |
| BuildStream's own artifact cache (CAS) | `bst artifact pull` | Content-addressed and deduplicated, but needs BuildStream on the target, and a cache key is an identity, not a signature.  Right for builders, wrong for clients. |

## Recommendation: images, the systemd way

Ship bunix the way GNOME OS (also built with BuildStream) is moving to:
**signed, verity-protected disk images, fetched by systemd-sysupdate**, with
optional parts as **system extensions**.  Everything is already in systemd 261,
which bunix builds; it follows the UAPI group's specifications the file system
already follows (Discoverable Partitions, Discoverable Disk Images, Boot
Loader Specification, Unified Kernel Images).

### The units of delivery

```
bunix_<v>.usr.raw          the whole /usr: erofs, with a dm-verity hash
bunix_<v>.usr-verity.raw     tree and a signature over its root hash
bunix_<v>.usr-verity-sig.raw
bunix_<v>.efi              Unified Kernel Image: kernel + initrd + command line
                           (which carries the /usr root hash), Secure Boot signed
gcc_<v>.raw              extension: the toolchain (sysext DDI, signed verity)
rust_<v>.raw               extension: Rust, separate because it is large
SHA256SUMS                 hashes of all of the above, with BEST-BEFORE-<date>
SHA256SUMS.gpg             OpenPGP signature over SHA256SUMS (Ed25519,
                           made with Sequoia's sq, not GnuPG)
```

All of it is static files on HTTPS: any web server, bucket or CDN.  No
server-side logic.

### The trust chain

```
UEFI db (Microsoft) -> shim -> MOK (bunix key) -> systemd-boot -> UKI
UKI command line: usrhash=<root hash>   -> kernel verifies every /usr block
kernel keyring (bunix verity key)       -> verifies each sysext's root hash
                                           signature before mounting it
OpenPGP certificate in /usr (bunix release key), checked by Sequoia
                                        -> verifies SHA256SUMS
SHA256SUMS                              -> verifies each download
```

* dm-verity checks every block as it is read, so a tampered disk or image is
  caught at read time, not just at download time.
* The root-hash signature is checked by the kernel against a certificate
  built into the kernel (`CONFIG_SYSTEM_TRUSTED_KEYS`), which works for BIOS
  boots too -- not only under Secure Boot.
* Freeze attacks: `BEST-BEFORE-YYYY-MM-DD` in SHA256SUMS; CI re-signs the
  manifest regularly even without a new release.  Rollback attacks:
  sysupdate only moves to a *newer* version, and `MinVersion=` can mark
  known-bad versions obsolete.
* Separate keys for separate jobs, so one leak does not give everything
  away: **Secure Boot** (MOK, signs boot loader and UKIs), **verity** (signs
  image root hashes), **release** (signs SHA256SUMS).  Kept offline, used by
  CI through a signing step only; the private keys never become BuildStream
  sources (today `keys/` is one, which copies it to the build host).

### Step 1: the toolchain as a system extension (built)

A sysext is a disk image with a `usr/` tree and
`usr/lib/extension-release.d/extension-release.gcc`.  `systemd-sysext merge`
overlays it on /usr read-only; `unmerge` removes it without a trace.  On the
RAM-only live ISO the image goes to `/var/lib/extensions` and lasts until
reboot; on an installed system it persists.

On a running bunix:

```
mkdir -p /etc/sysupdate.d/gcc.feature.d
printf '[Feature]\nEnabled=true\n' > /etc/sysupdate.d/gcc.feature.d/enable.conf
/usr/lib/systemd/systemd-sysupdate update     # fetch, verify, install
systemd-sysext refresh                         # merge: cc, make, ... appear
```

(`updatectl enable gcc` would write the same drop-in, but systemd 261's
update service sees no update target while all of a system's transfers
belong to disabled features, as on the live ISO.)

Build side:

* `sysext/gcc-content.bst`: what goes in -- the bootstrap toolchain, kernel
  headers, make, pkgconf, m4/autoconf/automake/libtool, cmake, meson, ninja,
  and `base.bst` for the libraries' headers, pkg-config files and static
  libraries.
* `sysext/gcc-tree.bst`: that, minus every path the root file system has,
  minus documentation, what the rootfs prunes on purpose and the largest
  unused pieces; stripped.  624 MB.  `tests/gcc.bst` builds C, C++, a
  pkg-config (OpenSSL) program and a meson project with the rootfs plus this
  tree.
* `sysext/gcc.bst`: `systemd-repart --offline` packs it as a DDI
  (`files/sysext/repart.d`): erofs with LZMA (mkfs.erofs still calls zstd
  experimental), dm-verity hash tree, root hash signed with
  `keys/verity.key`.  234 MB.
* The image is `gcc_<release>.raw` -- sysext takes the extension's name from
  the file name up to the first `_` -- and its extension-release has
  `ID=bunix`, `SYSEXT_LEVEL=<release>`.  The rootfs's os-release has the same
  `SYSEXT_LEVEL` and `IMAGE_VERSION`, from `include/release.yml`, so an
  extension merges only into the release it was built with.
* `tools/publish.sh <dir>`: `<dir>/<release>/` with the image, SHA256SUMS
  (with `BEST-BEFORE-<date>`, 30 days by default) and SHA256SUMS.gpg, signed
  with `keys/release.key` by `sqop` in `bst shell tools/sqop.bst`.

System side:

* `/usr/lib/sysupdate.d/gcc.feature` (disabled) and `50-gcc.transfer`:
  `url-file` from `<base URL>/%A/` (one directory per release) into
  `/var/lib/extensions/gcc.raw.v/`, of which sysext merges the newest.
* `/usr/lib/systemd/import-pubring.pgp`: the release certificate (v6,
  Ed25519).  `/usr/bin/gpg` hands systemd-pull's check to `sqv`.
* `/usr/lib/systemd/sysext.conf.d/bunix.conf`:
  `ImagePolicy=root=signed+absent:usr=signed+absent` -- systemd's default
  also accepts unsigned images.
* Kernel: overlayfs, erofs (LZMA), dm-verity with root hash signatures, the
  image signing certificate built into the system keyring, and
  `dm_verity.require_signatures=1` on the command line.
* systemd: sysupdate(d), importd (systemd-pull), sysext, repart, with
  libcryptsetup, libcurl, xz, zlib, fdisk.  New packages: xz, json-c, popt,
  device-mapper (LVM2), cryptsetup (library only), erofs-utils, autotools,
  make, kernel headers, sqv; Botan (static, for Sequoia) and, for the
  publishing machine only, sqop and SQLite.

Tested (`tools/boot-test.py` with `BOOT_CHECKS=tools/boot-checks/gcc-update.txt`,
QEMU/KVM, 1 GB RAM): a manifest changed after signing is refused before
anything is downloaded; the signed one installs, merges through a dm-verity
device, `cc` builds and runs a program, and `unmerge` removes it all.

### Language extensions: rust and swift (built)

Two more extensions, each its own sysupdate feature, so a machine downloads
only the languages it uses. Both build through the gcc extension's
compiler and linker, so they are enabled together with it.

| Extension | Contents | Source |
| --- | --- | --- |
| `gcc` | gcc, binutils, headers, make, cmake, meson, ninja, autotools | built here |
| `rust` | rustc, cargo, the standard library (Rust 1.99.1) | built here (`bootstrap/rust.bst`) |
| `swift` | swiftc, the package manager, Foundation, lldb, sourcekit-lsp, docc (Swift 6.4.2) | swift.org's Ubuntu 24.04 toolchain, a binary seed |

The Swift toolchain (`sysext/swift-tree.bst`) needs some libraries in
Debian's form where bunix's differ: ncurses split into libncurses and
libtinfo with versioned symbols, libedit under Debian's name, libxml2 2.13
(`.so.2`), SQLite, and libcurl with versioned symbols. They are built from
source (`sysext/swift-deps/`) into the toolchain's private
`/usr/lib/swift-toolchain/deps/lib`, and patchelf adds that directory to the
search path of the programs that need them, so the system's own libraries
stay untouched. The toolchain keeps its own layout
(`/usr/lib/swift-toolchain/usr/bin`): Swift's build engine finds the
toolchain as the directory above `usr/bin`. The commands in `/usr/bin` are
scripts that put that directory first in `PATH` and start the real
program, as swiftly does. Embedded Swift and WebAssembly support are left
out (about 760 MB).

`tests/rust-extension.bst` and `tests/swift.bst` stage the root file system
with the extensions over it and build programs: rustc and cargo; swiftc,
Foundation, and a Swift package with `swift build` and `swift run`.

### Step 2: an installed, updatable system (built)

`system/disk.bst` makes `bunix-x86_64.raw`, written to a whole disk (UEFI
only).  GPT, by the Discoverable Partitions Specification:

```
ESP           shim, fallback, MokManager; systemd-boot (EFI/systemd/);
              UKIs in EFI/Linux/ (bunix_<v>.efi, bunix_<v>+3-0.efi while untried)
usr A         erofs (LZ4HC), its dm-verity hash tree, the signed root hash
usr B         three partitions labelled _empty, for the next release
root          created on first boot by systemd-repart in the initrd
              (/usr/lib/repart.d/50-root.conf): ext4, grown to the end of
              the disk, with the merged-/usr links
```

Boot: firmware -> shim -> on first boot fallback, which creates a "bunix"
firmware entry from `EFI/bunix/BOOTX64.CSV` and reboots -> shim -> systemd-boot
-> the newest UKI (`system/uki.bst`: kernel, `system/initrd.bst`, os-release,
`usrhash=<root hash> rw`, signed) -> the initrd finds /usr's partitions by the
UUIDs systemd-repart derived from the root hash, sets up dm-verity, mounts
/usr, creates the root partition if there is none, mounts it, and switches
to it.  shim and systemd-boot are both signed with the bunix Secure Boot key.

/usr is hermetic: `/etc` starts empty and is filled by systemd-tmpfiles from
`/usr/share/factory/etc` (configuration copied, so local edits survive
updates; the CA bundle linked, so updates bring new certificates); users
come from sysusers at boot; services are enabled by links in /usr (and a
preset that enables nothing else), so what runs is part of the image.

Updates: `/usr/lib/sysupdate.d/10-usr`, `11-usr-verity`, `12-usr-verity-sig`
(partitions; source names carry the partition UUIDs, `@u`) and `90-uki`
(the UKI, written last, with `TriesLeft=3`), from
`https://github.com/bunasys/bunix/releases/latest/download/`.  The gcc
extension (`50-gcc`) is in the same target, so it moves in lock-step.
`tools/publish.sh` publishes all of it per release.  The live ISO has no
slots: `system/iso.bst` drops the OS transfers and points gcc at its own
release.

Tested in QEMU/KVM (UEFI, Secure Boot off; `tools/boot-test.py` boots a
disk image from a kept copy, so runs are reboots):

* first boot: fallback creates the boot entry; the root partition is created
  and grown; HTTPS, nawa; 4.4 s to multi-user (2.4 s of it the initrd,
  including the partitioning).
* update 0.1.0 -> 0.1.1 (`tools/boot-checks/os-update.txt`): slot B written,
  UKI installed as `+3-0`; after reboot the system runs 0.1.1 from slot B,
  systemd-boot counted the try (`+2-1`), `systemd-bless-boot` marked it good
  (`bunix_0.1.1.efi`).
* rollback: a signed 0.1.2 whose UKI names a /usr that does not exist; the
  machine installed it, systemd-boot used up its three tries, marked it bad
  and went back to booting 0.1.1.

Learned on the way: the UKI must not be read-only on the ESP (systemd-boot
skips boot counting for read-only entries, so no `Mode=0444`); a usr
partition's files go at its top level (`CopyFiles=/usr/:/`); the signature
partition's UUID comes from repart's seed, so the seed differs per release;
the initrd needs device-mapper's udev rules and dmsetup for /dev/mapper/usr
to become ready, and `veritysetup.target` wired into `sysinit.target`.

### Step 3: release pipeline

```
change merged -> CI: bst build -> tests/rootfs + boot tests (UEFI, BIOS,
Secure Boot, update from previous version, rollback) -> sign -> publish
```

* Channels as separate directories (`stable/`, `testing/`), each with its own
  SHA256SUMS.
* Versions are monotonic, e.g. `2026.11.2`; the version is written into
  os-release `IMAGE_VERSION` and into every artifact name.
* Reproducible builds (the step we deferred) let anyone check that a
  published image matches the sources -- the last link in "only bunix-built
  bytes run".

## Signing the manifest without GnuPG

systemd 261's sysupdate knows one manifest signature format: OpenPGP.
`src/import/pull-common.c` looks only for `SHA256SUMS.gpg` / `.asc` and runs
`gpg2`, then `gpg`, as `gpg --batch --no-default-keyring --trust-model=always
--keyring=<file> --verify <sig> -` against
`/etc/systemd/import-pubring.pgp` or `/usr/lib/systemd/import-pubring.pgp`.
Nothing else (minisign, signify, SSH signatures, PKCS#7, Sigstore) is
accepted.  So the format stays OpenPGP, but the implementation does not have
to be GnuPG:

* **Signing (CI):** Sequoia's `sq` (Rust) with an Ed25519 key, offline.
* **Verifying (on bunix):** Sequoia's verify-only `sqv` behind a small `gpg`
  wrapper (`files/rootfs/usr/bin/gpg`) that accepts exactly systemd-pull's
  command line.  (Sequoia's GnuPG-compatible front end, sequoia-chameleon-
  gnupg, has had no release since March 2025.)
* **Cryptography:** Botan.  Sequoia's other production-ready backends,
  OpenSSL and Nettle, reach C through bindgen, which needs libclang; its pure
  Rust backend is marked not production-ready and not constant-time.

The manifest signature is the second line of defence anyway.  The first is
the kernel: every image's dm-verity root hash carries a PKCS#7 signature
(X.509, the same family as the Secure Boot keys), checked before the image is
mounted, whatever the download path.  What only the manifest signature adds
is freshness (`BEST-BEFORE`) and catching a bad download before it is
written.  Dropping it (`Verify=no`) would still never run unsigned code, but
would allow freeze attacks; not recommended.

Rejected: patching sysupdate to call minisign or `ssh-keygen -Y verify` --
a patch carried forever against every systemd release.

## Efficiency

* Full images, compressed: erofs with zstd keeps /usr small (the current
  initramfs is 61 MB for the whole system).  At that size, full downloads
  are fine.
* Optional parts stay optional: the toolchain and Rust are downloaded only
  where enabled.
* If image size grows: chunk-based deltas (casync/desync-style content-defined
  chunking, served as static files) can be added behind the same signed
  manifest.  sysupdate does not do deltas today.

## Open points

* Settled: the files are GitHub releases of `bunasys/bunix`
  (`releases/latest/download/`; the live ISO's extensions at
  `releases/download/v%A/`).  Secure Boot (shim + MOK, systemd-boot
  verifying UKIs through shim) and updates work on real hardware
  (2026-11-03, releases 0.1.0 to 0.1.2).
* Signing still happens on the build host: `keys/verity.key` and
  `keys/secureboot.key` are BuildStream sources (so also in its source
  cache there), `keys/release.key` is copied there for each signature.
  Moving signing to an offline machine is part of step 3.
* No negative test yet for the kernel side (an image signed with another key,
  or a modified image).
* Whether to add a TPM-sealed LUKS root in step 2 or later.
* Where to host the files (a bucket behind a CDN is enough).

## References

* systemd-sysupdate transfer files: https://www.freedesktop.org/software/systemd/man/latest/sysupdate.d.html
* systemd-sysext: https://www.freedesktop.org/software/systemd/man/latest/systemd-sysext.html
* UAPI Discoverable Partitions / Disk Images, Boot Loader Specification,
  Unified Kernel Images: https://uapi-group.org/specifications/
* GNOME OS and sysupdate: https://cfp.all-systems-go.io/all-systems-go-2024/talk/MGDHYQ/
* GNOME OS development tree as a sysext: https://discourse.gnome.org/t/towards-a-better-way-to-hack-and-test-your-system-components/21075
* sysext tooling with BuildStream: https://www.codethink.co.uk/articles/2024/A-new-way-to-develop-on-Linux/
* The Update Framework (threat model for freeze and rollback attacks): https://theupdateframework.io/
