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

# The sound's threads at a real-time priority, and PipeWire's processes at
# a higher one than other programs: without them, a busy machine makes
# the sound crackle, worst on a Mac, whose speakers' processing
# (asahi-audio) runs in WirePlumber.  PipeWire takes them itself
# (libpipewire-module-rt) within the limits a person's session has, set
# here for every session; with no RealtimeKit, these limits are the only
# way, and /etc/security, where they are usually set, is the system's.
# Here and not in desktop/pipewire.sh, which Chromium depends on.
mkdir -p $out/usr/lib/systemd/system/user@.service.d
cat > $out/usr/lib/systemd/system/user@.service.d/sound-real-time.conf <<UNIT
[Service]
LimitRTPRIO=95
LimitNICE=-19
UNIT
