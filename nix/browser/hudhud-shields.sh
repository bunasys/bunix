# Hudhud's Shields engine (docs/browser.md, "Shields"): Brave's
# adblock-rust behind a small C interface (files/hudhud/shields), and the
# filter lists compiled into one engine file the browser loads at start.
# Both go next to the browser, where it looks for them
# (shields_engine.cc).
cp -r $shields shields
chmod -R u+w shields
cd shields

# ../cargo.sh's lines that give cargo its crates (a fix to one is a fix
# to the others: crubit.sh and base/bindgen.sh have them too).  Not
# cargo.sh itself: `cargo install` installs programs, and this is mostly
# a library.
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

# The lists, in the order Brave and uBlock Origin apply them; the unbreak
# and quick-fix lists hold the exceptions that keep sites working
unpack $ublock_assets ublock-assets
unpack $liste_ar liste-ar
./target/release/hudhud-shields-compile shields.dat \
    ublock-assets/thirdparties/easylist/easylist.txt \
    ublock-assets/thirdparties/easylist/easyprivacy.txt \
    ublock-assets/filters/filters.txt \
    ublock-assets/filters/privacy.txt \
    ublock-assets/filters/unbreak.txt \
    ublock-assets/filters/quick-fixes.txt \
    liste-ar/Liste_AR.txt

browser_dir=$out/usr/lib/hudhud
mkdir -p $browser_dir
cp target/release/libhudhud_shields.so shields.dat $browser_dir/
ls -l $browser_dir
