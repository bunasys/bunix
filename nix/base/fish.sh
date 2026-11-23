# In a directory of its own, with fish's git repositories beside it
# (below): inside fish's source, cargo would take fish's settings for
# theirs.
unpack $src fish
cd fish

# fish is Rust, and CMake drives cargo for it: the lines of ../cargo.sh
# that give cargo its crates, then those of ../cmake.sh.
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

export CARGO_HOME=$PWD/cargo-home
mkdir -p $CARGO_HOME
cat > $CARGO_HOME/config.toml <<END
[source.crates-io]
replace-with = "vendored"
[source.vendored]
directory = "$PWD/vendor"
END

# Eight of fish's crates are not published ones: they are directories of
# three git repositories, at a commit each (the element's `kind: git`
# crates; in Cargo.lock, the entries whose source is "git+...", which is
# where a new version of fish says which, and sources.json has the
# commits).  Each repository is unpacked whole, and cargo is told that
# what fish asks of the repository is in it.  Whole, and not a directory
# a crate among the others: these crates take settings from the top of
# their repository.
repositories=$(dirname $PWD)/git
unpack $fluent_rs $repositories/fluent-rs
unpack $fluent_ftl_tools $repositories/fluent-ftl-tools
unpack $rust_pcre2 $repositories/rust-pcre2
cat >> $CARGO_HOME/config.toml <<END
[patch."https://github.com/danielrainer/fluent-rs"]
fluent = { path = "$repositories/fluent-rs/fluent" }
fluent-bundle = { path = "$repositories/fluent-rs/fluent-bundle" }
fluent-syntax = { path = "$repositories/fluent-rs/fluent-syntax" }
intl-memoizer = { path = "$repositories/fluent-rs/intl-memoizer" }
[patch."https://codeberg.org/danielrainer/fluent-ftl-tools"]
fluent-ftl-tools = { path = "$repositories/fluent-ftl-tools" }
gettext-po-file-parser = { path = "$repositories/fluent-ftl-tools/crates/gettext-po-file-parser" }
[patch."https://github.com/fish-shell/rust-pcre2"]
pcre2 = { path = "$repositories/rust-pcre2" }
pcre2-sys = { path = "$repositories/rust-pcre2/pcre2-sys" }
END
# as the element: cargo is not to look for a network
export CARGO_NET_OFFLINE=true
# CMake starts cargo, and does not pass on how many jobs a build may run
export CARGO_BUILD_JOBS=$jobs

# WITH_DOCS=OFF: the manual is made with Sphinx, which is not here.
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=lib/$triplet \
    -DCMAKE_INSTALL_SBINDIR=bin -DCMAKE_INSTALL_LIBEXECDIR=lib \
    -DCMAKE_INSTALL_SYSCONFDIR=/etc -DCMAKE_INSTALL_LOCALSTATEDIR=/var \
    -DWITH_DOCS=OFF
ninja -C build -j$jobs
DESTDIR=$out ninja -C build install
