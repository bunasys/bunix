unpack $src
# chromium-rust's directory (chromium-rust.sh): Chromium looks for
# Crubit in its Rust toolchain
prefix=/usr/lib/chromium-rust

# ../cargo.sh's lines that give cargo its crates: a directory of their
# sources, one directory a crate, each with the checksum of the archive
# it came from.
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

# Compiled by the rustc it runs inside, whose librustc_driver it finds
# in that toolchain's lib/.  Recorded as that directory itself, not as
# build_crubit.py's $ORIGIN/../lib: the library is chromium-rust's, a
# package of its own, and $ORIGIN would only name this one's files.
export RUSTC=$prefix/bin/rustc
RUSTFLAGS="-Clink-args=-Wl,-rpath,$prefix/lib" \
    cargo build --release --locked --offline -j$jobs \
    -p cc_bindings_from_rs --bin cc_bindings_from_rs

mkdir -p $out$prefix/bin
install -m 755 target/release/cc_bindings_from_rs $out$prefix/bin/
# Crubit's support library, at the #include paths Chromium uses:
# "third_party/crubit/support/..."
crubit=$out$prefix/lib/third_party/crubit
mkdir -p $crubit
cp -r BUILD.gn LICENSE crubit.gni support $crubit/
# it starts, finding librustc_driver through its RUNPATH
$out$prefix/bin/cc_bindings_from_rs --help > /dev/null
