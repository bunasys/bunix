unpack $src

# ../cargo.sh's lines that give cargo its crates; the rest is its own:
# one member of the workspace, with features of its choosing, and the
# files a desktop shows it by
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

# Wayland alone: no X11, which the system does not have.  Wayland's
# libraries, libxkbcommon and EGL are loaded when it runs (wayland-dlopen),
# and found by their names, as Mesa's are; fontconfig and FreeType it
# links.
cargo build --release --frozen -j$jobs -p alacritty --no-default-features --features wayland
install -D -m 755 target/release/alacritty $out/usr/bin/alacritty

# What a desktop shows it by: its entry in the launcher, and its icon.
# Its terminfo entries (alacritty, alacritty-direct) are ncurses', which
# the system has.
install -D -m 644 extra/linux/Alacritty.desktop $out/usr/share/applications/Alacritty.desktop
install -D -m 644 extra/logo/alacritty-term.svg $out/usr/share/icons/hicolor/scalable/apps/Alacritty.svg
