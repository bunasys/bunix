kind: meson
description: |
  systemd, configured down to an init system and its network stack: PID 1,
  journald, udevd, tmpfiles, sysusers, networkd, resolved, timesyncd and the
  client tools -- plus what delivers software to a running system
  (docs/updates.md): sysupdate and its downloader, sysext, and repart, which
  also builds the extension images; and for installed systems systemd-boot,
  the UKI stub and ukify, and the initrd's units; and logind, for seats and
  sessions (docs/desktop.md)

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/gperf.bst
- base/pkgconf.bst
- base/python-jinja2.bst
# systemd-boot's ELF to EFI conversion
- base/python-pyelftools.bst

depends:
- base/libcap.bst
- base/util-linux.bst
- base/openssl.bst
# sysupdate's downloader (systemd-pull): libcurl, and xz/zlib to unpack
- base/curl.bst
- base/xz.bst
- base/zlib.bst
# dm-verity for extension images (loaded with dlopen)
- base/cryptsetup.bst
# udev loads each device's driver module through libkmod
- base/kmod.bst
# measurements into the TPM (loaded with dlopen)
- base/tpm2-tss.bst

sources:
- kind: tar
  url: github:systemd/systemd/archive/refs/tags/v261.3.tar.gz
  ref: 3f8d3d3969af7214bda600930e14c6a24135eb3dce1ba7f1b980b74e6dc15b72

variables:
  # Every optional feature starts disabled (auto_features); the first line
  # turns on the libraries in use.  openssl gives resolved DNSSEC validation
  # and DNS-over-TLS.  The second line's libraries are for the update
  # components on the third, the boot components after it (SBAT: the
  # revocation metadata shim checks in systemd-boot).  logind tracks seats
  # and sessions: its udev rule tags graphics and input devices "seat",
  # which is how Plymouth, and later the compositor, find the screen.  The
  # rest are on by default and have no use here: no containers or VMs, no
  # hibernation.
  meson-local: >-
    -Dauto_features=disabled -Dmode=release
    -Dblkid=enabled -Dlibmount=enabled -Dopenssl=enabled -Dkmod=enabled
    -Dlibcryptsetup=enabled -Dlibcurl=enabled -Dxz=enabled -Dzlib=enabled -Dfdisk=enabled
    -Dsysupdate=enabled -Dsysupdated=enabled -Dimportd=enabled -Drepart=enabled -Dsysext=true
    -Defi=true -Dbootloader=enabled -Dukify=enabled -Dinitrd=true
    -Dsbat-distro=bunix -Dsbat-distro-summary=bunix -Dsbat-distro-pkgname=systemd
    -Dsbat-distro-version=261.3 -Dsbat-distro-url=https://github.com/bunasys/bunix
    -Dsysusers=true -Dtmpfiles=true -Danalyze=true
    -Dnetworkd=true -Dresolve=true -Dtimesyncd=true
    -Dlogind=true -Dhostnamed=false -Dlocaled=false -Dtimedated=false
    -Dmachined=false -Dportabled=false -Duserdb=false
    -Dcoredump=false -Doomd=false -Dhibernate=false -Dtpm=true -Dtpm2=enabled
    -Dutmp=false -Dbinfmt=false -Dfirstboot=false -Drandomseed=false
    -Dbacklight=false -Drfkill=false -Dvconsole=false -Dquotacheck=false
    -Dstoragetm=false -Dhwdb=false -Dkernel-install=false
    -Dnss-myhostname=false -Dnss-systemd=false -Didn=false
    -Dtranslations=false -Dtests=false -Dinstall-tests=false
