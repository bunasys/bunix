# An LV2 plugin written in Rust, built by cargo (bankstown, triforce):
# $plugin.lv2/ in /usr/lib/<triplet>/lv2, where lilv looks, as the
# project's own Makefile installs it (its install only copies; cargo
# builds first, here).
unpack $src

# ../cargo.sh's lines that give cargo its crates.  The same lines are in
# every Rust package's script that does not use cargo.sh (those that
# write .cargo-checksum.json): a fix to one is a fix to each.  Not
# cargo.sh itself: `cargo install` installs programs, and this is a
# library.
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
cargo build --release --locked --offline -j$jobs

make install DESTDIR=$out LIBDIR=/usr/lib/$triplet
# where lilv looks, or the build fails here rather than the chain on a Mac
[ -f $out/usr/lib/$triplet/lv2/$plugin.lv2/$plugin.so ]
