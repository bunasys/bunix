unpack $src
version=$(cat meson.version)
# Built with meson, with more steps than ../meson.sh has; the arguments
# for UAPI.9's places are as there.
#
# After base/systemd.bst: every optional feature starts off
# (auto_features), and what is in use is turned on.  cryptsetup is for
# dm-verity, which /usr and the extension images are checked with; curl,
# xz and zlib for what downloads and unpacks an update (importd), and so
# for sysupdate.  Of EFI: systemd-boot, which starts the newest kernel on
# the partition a machine boots from, and can count the boots of one
# that is new and go back to the one before; the
# stub a kernel, its command line and what starts it are made one file
# with (a unified kernel image), and ukify, which makes it.  A Mac has
# EFI by U-Boot.  Not yet on, for want of what they are built against,
# each a step of its own: PAM (logins as sessions), polkit, the TPM, and
# seccomp: until that one is, the units of systemd's own services that
# confine them to the system calls they need confine nothing.
#
# sbat-...: what a UKI and systemd-boot say of themselves to what may one
#   day revoke them (as the element).
# split-bin=false: /usr/sbin is /usr/bin here; left to find out, systemd
#   looks at the machine that builds it.
# fallback-hostname: the machine's name until /etc has one, which on a
#   first boot from a disk is some way into the boot.
# time-epoch: the time a clock is not allowed to be before, for a machine
#   whose own clock starts at 1970: the first of November 2026, to be
#   moved on with the version.  Left alone it is the time of the build,
#   which here is second 1 of 1970.
# systemd's programs find its two private libraries in a directory of
# their own, which each program names.  One of the two needs the other and
# names no directory: it relies on the program having loaded it already.
# Every file is given the directory, so that each finds what it needs by
# itself, which is what is checked of a package.
export LDFLAGS="${LDFLAGS:-} -Wl,-rpath,/usr/lib/$triplet/systemd"
meson setup build --prefix=/usr --bindir=bin --sbindir=bin --libdir=lib/$triplet \
    --libexecdir=lib --sysconfdir=/etc --localstatedir=/var --buildtype=release \
    --wrap-mode=nodownload \
    -Dsplit-bin=false \
    -Dauto_features=disabled -Dmode=release -Dtime-epoch=1793491200 -Dfallback-hostname=bunix \
    -Dblkid=enabled -Dlibmount=enabled -Dopenssl=enabled -Dkmod=enabled \
    -Dxz=enabled -Dzlib=enabled -Dfdisk=enabled -Dacl=enabled \
    -Drepart=enabled -Dsysext=true -Dinitrd=true \
    -Dsysusers=true -Dtmpfiles=true -Danalyze=true \
    -Dnetworkd=true -Dresolve=true -Dtimesyncd=true \
    -Dlogind=true -Dhostnamed=true -Dtimedated=true -Dlocaled=false \
    -Dlibcryptsetup=enabled -Dlibcurl=enabled \
    -Dsysupdate=enabled -Dsysupdated=enabled -Dimportd=enabled \
    -Dpam=disabled -Dpolkit=disabled \
    -Defi=true -Dbootloader=enabled -Dukify=enabled -Dtpm=false -Dtpm2=disabled \
    -Dsbat-distro=bunix -Dsbat-distro-summary=bunix -Dsbat-distro-pkgname=systemd \
    -Dsbat-distro-version=$version -Dsbat-distro-url=https://github.com/bunasys/bunix \
    -Dmachined=false -Dportabled=false -Duserdb=false \
    -Dcoredump=false -Doomd=false -Dhibernate=false \
    -Dutmp=false -Dbinfmt=false -Dfirstboot=false -Drandomseed=false \
    -Dbacklight=false -Drfkill=false -Dvconsole=false -Dquotacheck=false \
    -Dstoragetm=false -Dhwdb=true -Dkernel-install=false \
    -Dnss-myhostname=false -Dnss-systemd=false -Didn=false \
    -Dtranslations=false -Dtests=false -Dinstall-tests=false
ninja -C build -j$jobs
DESTDIR=$out ninja -C build install
# /var is the running system's, not a package's
rm -rf $out/var

# ukify is Python, and a tool of what builds a unified kernel image, not a
# program of a running system: among the programs it would make systemd
# need Python to run.  It is kept beside systemd's own helpers, for
# `python3 /usr/lib/systemd/ukify` (images/uki.sh).
# (rm: systemd leaves a link there to where the file was)
rm -f $out/usr/lib/systemd/ukify
mv $out/usr/bin/ukify $out/usr/lib/systemd/ukify

# What starts a login prompt on every console: there is no login program
# for one to run (PAM, above), and on a serial console it would take the
# keys meant for root's shell.  To come back with PAM.
rm $out/usr/lib/systemd/system-generators/systemd-getty-generator
