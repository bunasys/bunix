unpack $src

# The build runs a few scripts of its own that start with #!/bin/bash, and
# a build has no /bin/bash, only /bin/sh, which is a bash here.
grep -r -l '^#! */bin/bash' tools | xargs sed -i '1s|/bin/bash|/bin/sh|'

# Left out: what needs a library that is not a package yet (ncurses,
# readline, PAM, systemd, Python), the programs for logging in, and
# translations and manual pages.
# --disable-makeinstall-chown, -setuid: the install would make files root's
# and set-user-id, which a build cannot do.
./configure --prefix=$out \
    --disable-static --disable-nls --disable-asciidoc --disable-poman \
    --disable-login --disable-su --disable-runuser --disable-chfn-chsh \
    --disable-newgrp --disable-sulogin --disable-setpriv --disable-uuidd \
    --disable-cramfs --disable-liblastlog2 --disable-pam-lastlog2 \
    --disable-pylibmount --disable-bash-completion \
    --disable-makeinstall-chown --disable-makeinstall-setuid \
    --without-python --without-systemd --without-udev --without-libmagic \
    --without-econf --without-cryptsetup --without-audit --without-selinux \
    --without-smack --without-btrfs \
    --without-ncurses --without-ncursesw --without-tinfo --without-readline
make
make install

# one directory of programs: PATH is made of each package's bin/
mv $out/sbin/* $out/bin/
rmdir $out/sbin
