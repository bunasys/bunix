unpack $src
# ../meson.sh's lines, with the paths of its configuration and cache:
# /usr/share/fontconfig and not /etc/fonts, since an extension has only
# /usr.  -Dcache-build=disabled: the cache is made where it runs, by the
# unit below.
meson setup build --prefix=/usr --bindir=bin --sbindir=bin --libdir=lib/$triplet \
    --libexecdir=lib --sysconfdir=/etc --localstatedir=/var --buildtype=release \
    --wrap-mode=nodownload \
    -Ddoc=disabled -Dnls=disabled -Dtests=disabled -Dtools=enabled \
    -Dcache-build=disabled -Dxml-backend=expat -Dcache-dir=/var/cache/fontconfig \
    -Dbaseconfig-dir=/usr/share/fontconfig -Dconfig-dir=/usr/share/fontconfig/conf.d
ninja -C build -j$jobs
DESTDIR=$out ninja -C build install

# bunix's rule for the generic names ($files: files/fontconfig/)
share=$out/usr/share/fontconfig
install -D -m 644 $files/58-bunix-fonts.conf $share/conf.avail/58-bunix-fonts.conf
ln -s ../conf.avail/58-bunix-fonts.conf $share/conf.d/58-bunix-fonts.conf

# the font cache at every start, and what starts it
units=$out/usr/lib/systemd/system
install -D -m 644 $files/fontconfig-cache.service $units/fontconfig-cache.service
install -D -m 644 $files/fontconfig-cache.conf $units/multi-user.target.d/fontconfig-cache.conf
