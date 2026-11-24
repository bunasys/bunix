unpack $src
# files/niri/: software rendering where it is asked for, and what that
# needs (each patch says why)
for fix in $patches; do
    patch --fuzz=0 -p1 -i $fix
done

# libdisplay-info 0.3, which niri reads screens' descriptions (EDID)
# with, built here and linked in: niri's Rust binding of it takes no
# version from 0.4 on, and nothing else of bunix uses it.  It moves to a
# package of its own when the binding takes 0.4, or something else needs
# it.  It names the makers of screens from hwdata's pnp.ids.
unpack $libdisplay_info /build/libdisplay-info
meson setup /build/libdisplay-info/build /build/libdisplay-info \
    --prefix=/build/display-info --libdir=lib --buildtype=release \
    --wrap-mode=nodownload --default-library=static -Dwerror=false
ninja -C /build/libdisplay-info/build -j$jobs install
export PKG_CONFIG_PATH=/build/display-info/lib/pkgconfig

# ../cargo.sh's lines that give cargo its crates.
#
# Cargo is given the crates as a directory of their sources, one
# directory a crate, each with the checksum of the archive it came from.
mkdir vendor
for crate in $crates; do
    name=$(basename $crate .crate)
    # the store's name is <hash>-<name>-<version>.crate
    name=${name#*-}
    unpack $crate vendor/$name
    checksum=$(sha256sum < $crate)
    echo "{\"files\":{},\"package\":\"${checksum%% *}\"}" > vendor/$name/.cargo-checksum.json
done
# Two crates are not published ones: smithay and smithay-drm-extras, of
# Smithay's repository at a commit (in Cargo.lock, the entries whose
# source is "git+..."; sources.json has the commit).  Among the others,
# as `cargo vendor` puts such crates: with no checksum, since a
# repository has none, and cargo told below that that repository at that
# commit is in the same directory.  Not fish's way (base/fish.sh, a
# repository whole and a [patch] of it): these two take nothing from the
# top of their repository, and a [patch] would change what Cargo.lock
# says, which --frozen refuses.
unpack $smithay /build/smithay
cp -r /build/smithay vendor/smithay
cp -r /build/smithay/smithay-drm-extras vendor/smithay-drm-extras
for crate in smithay smithay-drm-extras; do
    echo '{"files":{},"package":null}' > vendor/$crate/.cargo-checksum.json
done

export CARGO_HOME=$PWD/cargo-home
mkdir -p $CARGO_HOME
cat > $CARGO_HOME/config.toml <<END
[source.crates-io]
replace-with = "vendored"
[source."git+https://github.com/Smithay/smithay.git?rev=$smithay_commit"]
git = "https://github.com/Smithay/smithay.git"
rev = "$smithay_commit"
replace-with = "vendored"
[source.vendored]
directory = "$PWD/vendor"
END

# The compositor alone: the workspace's other members are its library
# crates, which it is built with, and its visual tests, which need GTK 4.
# Of its features, `dbus` and `systemd`: no screencasting, which needs
# PipeWire and xdg-desktop-portal-gnome.  No Xwayland: bunix has none.
cargo build --release --frozen -j$jobs --package niri --no-default-features --features dbus,systemd

# Its session is a systemd user unit: niri-session, which the login
# screen starts (niri.desktop), starts niri.service, which brings up
# graphical-session.target.
install -D -m 755 target/release/niri $out/usr/bin/niri
install -D -m 755 resources/niri-session $out/usr/bin/niri-session
install -D -m 644 resources/niri.desktop $out/usr/share/wayland-sessions/niri.desktop
install -D -m 644 -t $out/usr/lib/systemd/user resources/niri.service resources/niri-shutdown.target
