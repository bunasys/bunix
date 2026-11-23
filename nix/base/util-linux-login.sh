unpack $src
# The element's arguments: of all of util-linux, login and runuser.
# --enable-chfn-chsh: not the element's.  chsh, with which a user chooses
#   between bash and fish; x86 has one shell and no chsh.  It asks PAM
#   for the user's password, and takes only a shell of /etc/shells.
# --disable-makeinstall-chown, -setuid: as base/util-linux.sh.
./configure $configure_for_usr \
    --disable-all-programs --enable-login --enable-runuser --enable-chfn-chsh \
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
# chfn comes with chsh, and is not wanted: nothing here reads what it
# changes, a user's name and telephone numbers
rm $out/usr/bin/chfn $out/usr/share/man/man1/chfn.1
# a manual page of the whole source's, which base/util-linux.sh installs
rm $out/usr/share/man/man5/terminal-colors.d.5
