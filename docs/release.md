# Making a bunix release

A release is a GitHub release of `bunasys/bunix`, tagged `v<version>`.
Installed systems fetch it with systemd-sysupdate from
`releases/latest/download/`; the live ISO fetches its extensions from
`releases/download/v<version>/`.  Every release holds

| File | What it is |
| --- | --- |
| `bunix-x86_64.iso` | the live system and installer (`system/iso.bst`) |
| `bunix_<version>.usr-x86-64*.raw` | the three partitions of a `/usr` slot: erofs, dm-verity hash tree, signed root hash (`system/usr.bst`) |
| `bunix_<version>.efi` | the signed kernel image that boots it (`system/uki.bst`) |
| `gcc_`, `rust_`, `swift_`, `devtools_<version>.raw` | the system extensions (`sysext/*.bst`) |
| `SHA256SUMS`, `SHA256SUMS.gpg` | the manifest and its OpenPGP signature by the release key |

## What you need

- An x86_64 Linux build host reachable over SSH, with KVM for the boot
  tests.  `tools/bst-remote.sh` copies the project there and installs the
  pinned BuildStream on first use; `BUNIX_BUILD_HOST` picks the host
  (default `pro13.home.arpa`).
- The three signing keys in `keys/` (README.md, "Keys").  They are not in
  this repository.  Keep a backup: installed systems trust only these keys,
  so new keys mean reinstalling every machine.
- `gh`, logged in with write access to `bunasys/bunix`.
- QEMU and OVMF on the build host for `tools/boot-test.py`.

## Steps

**1. Set the version** in `include/release.yml` (`release-version`).  It
goes into os-release and into every file name.  Versions must increase:
sysupdate installs only a version newer than the running one.

**2. Build** everything a release contains:

```
tools/bst-remote.sh build system/uki.bst system/usr.bst system/iso.bst \
  sysext/gcc.bst sysext/rust.bst sysext/swift.bst sysext/devtools.bst
```

A version change rebuilds only the images, not the packages (the version
is an include, not a project variable).

**3. Sign the update files:**

```
tools/publish.sh out/updates        # -> out/updates/<version>/
```

It checks the built files out on the build host, writes `SHA256SUMS`
(valid for 30 days, `BUNIX_MANIFEST_DAYS`) and signs it with
`keys/release.key`.

**4. Fetch the ISO** and put everything in one directory:

```
v=0.1.3
ssh pro13.home.arpa "cd src/bunix && rm -rf ~/bt-out/iso &&
  ~/.local/share/bunix-bst/bin/bst artifact checkout system/iso.bst --directory ~/bt-out/iso"
mkdir -p out/release-$v
scp pro13.home.arpa:bt-out/iso/bunix-x86_64.iso out/release-$v/
cp out/updates/$v/* out/release-$v/
```

**5. Test** in QEMU on the build host (`scp` `tools/boot-test.py`,
`tools/serve-updates.py` and `tools/boot-checks/*.txt` to `/tmp` there):

- The new ISO boots, with checks for the splash:
  `BOOT_CHECKS=/tmp/splash.txt python3 /tmp/boot-test.py bunix-x86_64.iso uefi ~/bt-iso`
- The update path that machines take: install the *previous* release's ISO
  next to a stand-in Windows, boot it, update it to the new release from a
  local server, boot again.

  ```
  mkdir -p ~/bt-upd && truncate -s 24G ~/bt-upd/disk.raw
  BOOT_DISK=~/bt-upd/disk.raw BOOT_CHECKS=/tmp/install-windows.txt \
    python3 /tmp/boot-test.py previous.iso uefi ~/bt-upd
  BOOT_CHECKS=/tmp/dual-boot.txt python3 /tmp/boot-test.py ~/bt-upd/disk.raw uefi ~/bt-upd

  mkdir -p ~/upd-serve && ln -s ~/bunix-publish/$v ~/upd-serve/latest
  python3 /tmp/serve-updates.py ~/upd-serve &      # stop it by its pid afterwards
  BOOT_CHECKS=/tmp/os-update.txt python3 /tmp/boot-test.py ~/bt-upd/disk.raw uefi ~/bt-upd
  BOOT_CHECKS=/tmp/after-update.txt python3 /tmp/boot-test.py ~/bt-upd/disk.raw uefi ~/bt-upd
  ```

  `serial.log` in the output directory must show `update exit 0`, then
  `IMAGE_VERSION=<new version>` and `systemd-bless-boot ... good` after the
  reboot.

**6. Publish:**

```
gh release create v$v -R bunasys/bunix --title "bunix $v" \
  --notes "What changed, in a sentence or two." out/release-$v/*
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

**7. On a real machine:** `/usr/lib/systemd/systemd-sysupdate update`,
then `reboot`; `grep IMAGE_VERSION /etc/os-release` shows the new version.

## The manifest expires

Each `SHA256SUMS` carries a `BEST-BEFORE` date 30 days out, and sysupdate
refuses a manifest past it, so a mirror cannot freeze machines on an old
release.  That also means a release older than 30 days stops working as an
update source.  Publish a new release before then, or re-sign the current
one: run `tools/publish.sh` again with the same version and replace
`SHA256SUMS` and `SHA256SUMS.gpg` on the release (`gh release upload
--clobber`).
