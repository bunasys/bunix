# ../meson.sh's lines, with Lua the system's (desktop/lua.sh) and not the
# copy its build would download
unpack $src
meson setup build --prefix=/usr --bindir=bin --sbindir=bin --libdir=lib/$triplet \
    --libexecdir=lib --sysconfdir=/etc --localstatedir=/var --buildtype=release \
    --wrap-mode=nodownload \
    -Dsystem-lua=true -Dsystemd=enabled -Dsystemd-user-service=true \
    -Dsystemd-system-service=false -Delogind=disabled \
    -Dintrospection=disabled -Ddoc=disabled -Dtests=false -Ddbus-tests=false
ninja -C build -j$jobs
DESTDIR=$out ninja -C build install

# Started with PipeWire, and named as its session manager: what
# `systemctl --user --global enable wireplumber` does, written into /usr.
units=$out/usr/lib/systemd/user
mkdir -p $units/pipewire.service.wants
ln -s ../wireplumber.service $units/pipewire.service.wants/wireplumber.service
ln -s wireplumber.service $units/pipewire-session-manager.service
# PipeWire, and so this, start with each person's session, and not when
# a program first asks for sound: PipeWire then has no output until this
# adds the card a moment later, and a program that found none (a
# browser) stays silent.  Here and not in desktop/pipewire.sh, which
# Quickshell builds against: a change there rebuilds Quickshell.
mkdir -p $units/default.target.wants
ln -s ../pipewire.service $units/default.target.wants/pipewire.service
