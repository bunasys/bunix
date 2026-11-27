# ../meson.sh's lines, without lv2_validate: a script that checks a
# plugin's description with sord_validate, which sord is built without
# (desktop.nix), and a build tool, not the desktop's
unpack $src
meson setup build --prefix=/usr --bindir=bin --sbindir=bin --libdir=lib/$triplet \
    --libexecdir=lib --sysconfdir=/etc --localstatedir=/var --buildtype=release \
    --wrap-mode=nodownload -Dauto_features=disabled
ninja -C build -j$jobs
DESTDIR=$out ninja -C build install
rm $out/usr/bin/lv2_validate
rmdir $out/usr/bin
