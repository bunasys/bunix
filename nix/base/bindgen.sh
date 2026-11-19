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

# The patches are of bindgen's repository, where the library's crate is
# the directory bindgen/.
# --fuzz=0: one that no longer fits exactly is to be looked at, not applied.
for fix in $patches; do
    patch --fuzz=0 -p2 -d vendor/bindgen-[0-9]* -i $fix
done

export CARGO_HOME=$PWD/cargo-home
mkdir -p $CARGO_HOME
cat > $CARGO_HOME/config.toml <<END
[source.crates-io]
replace-with = "vendored"
[source.vendored]
directory = "$PWD/vendor"
END

cargo build --release --offline --locked -j$jobs
install -D -m 755 target/release/bindgen $out/usr/bin/bindgen
