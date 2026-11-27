# librsvg: its C library (librsvg-2.so, with rsvg.h and librsvg-2.0.pc),
# which is Rust inside.  Meson builds it, and has cargo-c (`cargo
# cbuild`) build the Rust.
unpack $src

# ../cargo.sh's lines that give cargo its crates (the same lines are in
# every Rust package's script that does not use cargo.sh: a fix to one
# is a fix to each).  Meson runs cargo with this environment.
mkdir vendor
for crate in $crates; do
    name=$(basename $crate .crate)
    # the store's name is <hash>-<name>-<version>.crate
    name=${name#*-}
    unpack $crate vendor/$name
    checksum=$(sha256sum < $crate)
    echo "{\"files\":{},\"package\":\"${checksum%% *}\"}" > vendor/$name/.cargo-checksum.json
done
export CARGO_HOME=$PWD/cargo-home
mkdir -p $CARGO_HOME
cat > $CARGO_HOME/config.toml <<END
[source.crates-io]
replace-with = "vendored"
[source.vendored]
directory = "$PWD/vendor"
END

# ../meson.sh's lines.  pixbuf, librsvg's functions that hand back a
# gdk-pixbuf picture, is in: tiny-dfr's binding of librsvg names them, and
# links gdk-pixbuf whether it calls them or not.  Left out:
#   pixbuf-loader: gdk-pixbuf reading SVG files, which nothing here asks
#     for
#   rsvg-convert: the program; the library is what is wanted
#   avif: AVIF pictures inside an SVG, with dav1d, which bunix lacks
#   introspection, vala, docs, tests: for building other things, or for
#     a person reading
meson setup build --prefix=/usr --bindir=bin --sbindir=bin --libdir=lib/$triplet \
    --libexecdir=lib --sysconfdir=/etc --localstatedir=/var --buildtype=release \
    --wrap-mode=nodownload \
    -Dpixbuf=enabled -Dpixbuf-loader=disabled -Drsvg-convert=disabled \
    -Davif=disabled -Dintrospection=disabled -Dvala=disabled -Ddocs=disabled \
    -Dtests=false
ninja -C build -j$jobs
DESTDIR=$out ninja -C build install
