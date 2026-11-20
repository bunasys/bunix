unpack $src
# The element's arguments.
./configure $configure_for_usr \
    --disable-static --disable-nls --disable-man \
    --with-libpam --with-yescrypt --without-su --disable-subordinate-ids \
    --without-audit --without-selinux --without-acl --without-btrfs --without-tcb \
    --without-sssd --without-libbsd --without-skey
make
# suidperms, sgidperms: passwd and others are installed set-user-id, which
#   a build cannot do and the store would not keep; an image that wants
#   one so says so itself (docs/nix-usr-system.md).
make DESTDIR=$out install suidperms=755 sgidperms=755

# its tools for administrators go to /usr/sbin whatever --sbindir says
mv $out/usr/sbin/* $out/usr/bin/
rmdir $out/usr/sbin
# Left out, as the element does: its own login and su (util-linux's login,
# run0), and what no one here uses.
cd $out
for program in login su nologin faillog lastlog chfn chsh newgrp sg expiry \
               vipw vigr pwconv pwunconv grpconv grpunconv logoutd newusers \
               getsubids newuidmap newgidmap; do
    rm -f usr/bin/$program
done
# PAM's rules are bunix's, in /usr/lib/pam.d of a system (files/rootfs):
# for passwd and chpasswd, the two of these tools that ask PAM
rm -rf etc/pam.d
# bunix's defaults for a new account: a group of its own, a home made
# with it that others cannot read, and bash (the element says fish, which
# is not a package here yet).
sed -i -e 's/^#\?ENCRYPT_METHOD.*/ENCRYPT_METHOD YESCRYPT/' \
       -e 's/^#\?CREATE_HOME.*/CREATE_HOME yes/' \
       -e 's/^#\?HOME_MODE.*/HOME_MODE 0700/' etc/login.defs
# sed says nothing when no line matched; and the group of their own is
# the file's own default, which a later version may change
grep -q '^ENCRYPT_METHOD YESCRYPT' etc/login.defs
grep -q '^CREATE_HOME yes' etc/login.defs
grep -q '^HOME_MODE 0700' etc/login.defs
grep -q '^USERGROUPS_ENAB yes' etc/login.defs
mkdir -p etc/default etc/skel
printf 'HOME=/home\nINACTIVE=-1\nEXPIRE=\nSHELL=/usr/bin/bash\nSKEL=/etc/skel\nCREATE_MAIL_SPOOL=no\n' \
    > etc/default/useradd
