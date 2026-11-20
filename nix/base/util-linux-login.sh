unpack $src
# The element's arguments: of all of util-linux, login and runuser.
# --disable-makeinstall-chown, -setuid: as base/util-linux.sh.
./configure $configure_for_usr \
    --disable-all-programs --enable-login --enable-runuser \
    --disable-static --disable-nls --disable-asciidoc --disable-poman \
    --disable-bash-completion --disable-makeinstall-chown --disable-makeinstall-setuid \
    --without-python --without-systemd --without-udev --without-libmagic \
    --without-econf --without-audit --without-selinux --without-btrfs --without-readline
make
make DESTDIR=$out install

# UAPI.9: /usr/sbin is a link to /usr/bin; a few programs are installed
# there whatever --sbindir says, and the directory is made even when empty
if [ -d $out/usr/sbin ]; then
    find $out/usr/sbin -mindepth 1 -maxdepth 1 -exec mv {} $out/usr/bin/ \;
    rmdir $out/usr/sbin
fi
# a manual page of the whole source's, which base/util-linux.sh installs
rm $out/usr/share/man/man5/terminal-colors.d.5
