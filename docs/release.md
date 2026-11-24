# Making a bunix release

A release is a GitHub release of `bunasys/bunix`, tagged `v<version>`.
Installed systems fetch it with systemd-sysupdate from
`releases/latest/download/`.  It is built by Nix, for both architectures
(`docs/nix-usr-system.md`), and holds, for each (`<arch>`: `arm64`,
`x86-64`)

| File | What it is |
| --- | --- |
| `bunix_<version>.usr-<arch>*.raw` | the three partitions of a `/usr` slot: its image, the hashes of its blocks, the signed root hash (`nix/images/update.nix`) |
| `bunix_<version>.<arch>.efi` | the kernel image that starts it |
| `devtools_<version>.<arch>.raw` | the devtools extension (`nix/images/devtools.nix`) |
| `llvm_<version>.<arch>.raw` | the llvm extension (`nix/images/llvm.nix`) |
| `desktop_<version>.<arch>.raw` | the desktop extension (`nix/images/desktop.nix`) |

and once, for all of them, `SHA256SUMS` and `SHA256SUMS.gpg`: the list of
the files and its OpenPGP signature by the release key.

Not in a release yet, which BuildStream's had (up to 0.4.0): the live
image to install from, and the gcc, rust, swift and desktop extensions.
A machine installed from 0.4.0 or before should find no update in these
releases: it asks for a kernel image named `bunix_<version>.efi`, and so
reads the architecture in these names as part of the version, which no
`/usr` then has; and a version is taken only if all of it is there
(`tools/update-test.sh`, step 2, shows that for a kernel image that is
missing).  Not tried on such a machine.

## What you need

- The builder for aarch64 (`tools/nix-builder/lima.yaml`), running, on
  this Mac or on one reachable over SSH (`BUNIX_AARCH64_BUILDER`); and
  an x86_64 machine with Nix, reachable over SSH
  (`tools/nix-builder/home-store/nix.conf`; `BUNIX_X86_BUILDER`).  The
  Mac `tools/publish.sh` is run on is the one you sit at: 1Password
  asks on its own screen.
- The image key, the Secure Boot key and the release key, as the
  1Password documents "bunix verity key", "bunix secure boot key" and
  "bunix release key".  No file has them, and no build reads them
  (`docs/nix-usr-system.md`, "Who signs").
- `keys/secureboot.crt`, the Secure Boot key's certificate, in the
  checkout: what the x86-64 kernel image's signature is checked against.
- Sequoia's `sq`, for the list's signature (`brew install sequoia-sq`),
  and `osslsigncode`, for the kernel image's (`brew install
  osslsigncode`).
- `gh`, logged in with write access to `bunasys/bunix`.
- QEMU, for the tests.

## Steps

**1. Set the version** in `include/release.yml` (`release-version`), and
commit.  It goes into os-release and into every file name.  Versions
must increase: sysupdate installs only a version newer than the running
one.

**2. Test**, with nothing uncommitted in the working tree, which is
what the tests build: `tools/install-test.sh`, `tools/update-test.sh`,
and `tools/secure-boot-test.sh` (x86-64).

**3. Build and sign:**

```
tools/publish.sh out/updates        # -> out/updates/<version>/
```

It sends the last commit to both builders, builds, and has each
architecture's system and extensions signed with the image key
(`tools/sign.sh`), and the x86-64 kernel image with the Secure Boot key
(`tools/sign-kernel-image.sh`), then writes `SHA256SUMS` (good for 30
days, `BUNIX_MANIFEST_DAYS`) and has it signed with the release key
(`tools/sign-list.sh`).  1Password asks for the image key once an image
(the system and each extension of `extensions` in `tools/publish.sh`,
for each architecture), once
for the Secure Boot key, and once for the release key.  It says what in
the working tree is not in the commit, and so not in the release, and
ends with the line that tags the commit it built.

**4. Test the release** as it will be downloaded: a virtual machine
takes it, restarts into it, and marks it good.

```
tools/release-test.sh out/updates/<version> <the version before>
BUNIX_ARCHITECTURE=x86_64 tools/release-test.sh out/updates/<version> <the version before>
```

Once for each architecture: the first machine is the Mac's, the second
runs on the x86_64 builder (`tools/test-machine.sh`).  Each runs this
working tree's system under the older version's number, not the files
that version was published with.

**5. Publish:**

```
v=<version>
git tag v$v <the commit publish.sh built> && git push origin v$v
gh release create v$v -R bunasys/bunix --title "bunix $v" \
  --notes "What changed, in a sentence or two." out/updates/$v/*
```

Pass the files on the same line as the command: without them `gh` creates
an empty release, and installed systems would find no update.  The release
becomes "latest" on creation, so machines see it at once.

Then delete the release before the previous one, so only the current and
the previous release are kept (an installed system needs only the latest;
the previous is there to go back to):

```
gh release delete v<older> -R bunasys/bunix --yes --cleanup-tag
```

**6. On a real machine:** `/usr/lib/systemd/systemd-sysupdate update`,
then `reboot`; `grep IMAGE_VERSION /etc/os-release` shows the new version.

## The list expires

Each `SHA256SUMS` carries a `BEST-BEFORE` date 30 days out, and sysupdate
refuses a list past it, so a mirror cannot freeze machines on an old
release.  That also means a release older than 30 days stops working as an
update source.  Publish a new release before then, or sign the current
one's list again: run `tools/publish.sh` at the release's commit, into
another directory, and replace `SHA256SUMS` and `SHA256SUMS.gpg` on the
release (`gh release upload --clobber`).  Only if the other files came
out the same to the byte, as they do while the builders still have what
they built: the new list must differ from the published one in the
`BEST-BEFORE` line alone (`diff`), or machines would refuse every file.
The x86-64 files are the same only from the builder's store: its kernel
signs its modules with a key each build makes anew
(`nix/boot/linux/x86_64.config`), so a kernel built again is another.
