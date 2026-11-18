unpack $src
# The element's arguments, without --with-pam: there is no PAM here yet,
# and with keys only sshd does not need it.
# --with-privsep-path, --with-privsep-user: sshd handles a connection that
#   has not logged in yet as the user sshd, inside an empty directory.
# --disable-lastlog ... --disable-wtmpx: no records of logins in files
#   that no program here reads.
./configure $configure_for_usr \
    --sysconfdir=/etc/ssh --libexecdir=/usr/lib/ssh \
    --with-privsep-path=/usr/share/empty.sshd --with-privsep-user=sshd \
    --with-pid-dir=/run --with-default-path=/usr/bin --with-superuser-path=/usr/bin \
    --disable-lastlog --disable-utmp --disable-utmpx --disable-wtmp --disable-wtmpx \
    --disable-strip
# ssh-keysign is installed set-user-id, which a build cannot do and the
# store would not keep; an image that wants it so says so itself
# (docs/nix-usr-system.md).
grep -q -- '-m 4711' Makefile
sed -i 's/-m 4711/-m 0711/' Makefile
make
# install-nokeys: host keys are a machine's, made when it first boots.
# -j1: the install steps write the same directories at once otherwise.
make -j1 DESTDIR=$out install-nokeys
install -d $out/usr/share/empty.sshd
install -m 644 $sshd_config $out/etc/ssh/sshd_config
