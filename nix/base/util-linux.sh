unpack $src

# Left out: the programs for logging in (they come with their own package),
# what needs systemd, Python, PAM or a security module, and translations
# and manual pages.
# --disable-makeinstall-chown, -setuid: owners and set-user-id are an
#   image's to give, not a package's (docs/nix-usr-system.md).
# --bindir: with a prefix of /usr and no --bindir, util-linux takes it that
#   the root has directories of its own and installs mount and others in
#   /bin.
./configure $configure_for_usr --bindir=/usr/bin usrlib_execdir=/usr/lib/$triplet \
    --disable-static --disable-nls --disable-asciidoc --disable-poman \
    --disable-login --disable-su --disable-runuser --disable-chfn-chsh \
    --disable-newgrp --disable-sulogin --disable-setpriv --disable-uuidd \
    --disable-cramfs --disable-liblastlog2 --disable-pam-lastlog2 \
    --disable-pylibmount --disable-bash-completion \
    --disable-makeinstall-chown --disable-makeinstall-setuid \
    --without-python --without-systemd --without-udev --without-libmagic \
    --without-econf --without-cryptsetup --without-audit --without-selinux \
    --without-smack --without-btrfs --with-readline
make
make DESTDIR=$out install

# UAPI.9: /usr/sbin is a link to /usr/bin; a few programs are installed
# there whatever --sbindir says
if [ -d $out/usr/sbin ]; then
    mv $out/usr/sbin/* $out/usr/bin/
    rmdir $out/usr/sbin
fi
