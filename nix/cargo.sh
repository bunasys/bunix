# For a system package in Rust that cargo builds, and that needs nothing
# else: what `kind: cargo` is to a .bst element, as autotools.sh is for
# `kind: autotools`.  With nothing downloaded: cargo is given every crate.
#
# $crates is the crates the package is made of, each an archive: its
# Cargo.lock, pinned (the element's `cargo2` source; base/x-crates.json).
# $cargo_arguments is what the package adds (cargo-install-local in a .bst
# element).  It is split at spaces: a package that needs an argument with
# one in it, or another step, has a script of its own with these lines in
# it, as base/bindgen.sh is (it patches a crate).
unpack $src

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

export CARGO_HOME=$PWD/cargo-home
mkdir -p $CARGO_HOME
cat > $CARGO_HOME/config.toml <<END
[source.crates-io]
replace-with = "vendored"
[source.vendored]
directory = "$PWD/vendor"
END

# --no-track: without cargo's own list of what it installed, which is for
#   a person's home directory
cargo install --path . --root $out/usr --no-track --offline --locked -j$jobs ${cargo_arguments:-}
