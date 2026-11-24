# ../meson.sh's lines.  useroot=false: the install would make
# fusermount3 set-user-id root and /dev/fuse a device, which a build
# cannot; the extension makes fusermount3 set-user-id (images/desktop.nix,
# set_user_id), and the kernel makes /dev/fuse.  No init script, no
# io_uring (liburing, which the system does not have), and no examples or
# tests.
unpack $src
meson setup build --prefix=/usr --bindir=bin --sbindir=bin --libdir=lib/$triplet \
    --libexecdir=lib --sysconfdir=/etc --localstatedir=/var --buildtype=release \
    --wrap-mode=nodownload \
    -Duseroot=false -Dinitscriptdir= -Dudevrulesdir=/usr/lib/udev/rules.d \
    -Denable-io-uring=false -Dexamples=false -Dtests=false
ninja -C build -j$jobs
DESTDIR=$out ninja -C build install

# /etc/fuse.conf, which a machine writes itself when it wants other than
# fusermount3's defaults (no user_allow_other): an extension carries only
# /usr, and the system leaves /etc to the machine.  And its udev rule,
# which lets everyone open /dev/fuse: systemd's own rules and tmpfiles
# say so already, from the boot on (50-udev-default.rules,
# static-nodes-permissions.conf).
rm -r $out/etc $out/usr/lib/udev
