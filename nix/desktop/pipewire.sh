# ../meson.sh's lines.  Every optional feature starts disabled
# (auto_features); the ones named below are what the desktop uses.
# Options whose default is "enabled", not "auto", are turned off by name.
unpack $src
meson setup build --prefix=/usr --bindir=bin --sbindir=bin --libdir=lib/$triplet \
    --libexecdir=lib --sysconfdir=/etc --localstatedir=/var --buildtype=release \
    --wrap-mode=nodownload \
    -Dauto_features=disabled \
    -Dlibsystemd=enabled -Dlogind=enabled -Dsystemd-user-service=enabled -Dudev=enabled \
    -Ddbus=enabled -Dreadline=enabled \
    -Dspa-plugins=enabled -Dalsa=enabled -Dpipewire-alsa=enabled \
    -Daudiomixer=enabled -Daudioconvert=enabled -Dsupport=enabled -Dcontrol=enabled \
    -Dvideoconvert=enabled \
    -Dpipewire-jack=disabled -Dpipewire-v4l2=disabled -Dflatpak=disabled \
    -Daudiotestsrc=disabled -Dvideotestsrc=disabled \
    -Dexamples=disabled -Dtests=disabled -Ddocs=disabled -Dman=disabled \
    "-Dsession-managers=[]" -Drlimits-install=false -Dlegacy-rtkit=false
ninja -C build -j$jobs
DESTDIR=$out ninja -C build install

# Started with each person's session: the sockets, which start the
# services when they are first used (systemctl --user --global enable,
# written into /usr)
units=$out/usr/lib/systemd/user
mkdir -p $units/sockets.target.wants
ln -s ../pipewire.socket $units/sockets.target.wants/pipewire.socket
ln -s ../pipewire-pulse.socket $units/sockets.target.wants/pipewire-pulse.socket
