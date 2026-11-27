# tiny-dfr: the Touch Bar's keys.  The program, the pictures of its keys
# and its settings (/usr/share/tiny-dfr; a person's own in
# /etc/tiny-dfr), its unit, and its udev rules: one puts the bar's
# display and touch screen on a seat of their own (seat-touchbar), which
# the compositor on seat0 leaves alone; the other starts tiny-dfr when
# the bar's touch screen shows up, and names the bar's display and
# backlight, which its unit waits for (docs/mac-touch-bar.md).  Upstream has the unit and rules under etc/, for /etc: here they
# are the package's, under /usr/lib.  Not its units that keep the
# backlights' brightness across boots: bunix's systemd is built without
# that service (base/systemd.sh).
unpack $src

# ../cargo.sh's lines that give cargo its crates (the same lines are in
# every Rust package's script that does not use cargo.sh: a fix to one
# is a fix to each).  Not cargo.sh itself: the files beside the program
# are installed by hand, below; upstream has no install step.
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

install -D -m 755 target/release/tiny-dfr $out/usr/bin/tiny-dfr
install -d $out/usr/share/tiny-dfr
install -m 644 share/tiny-dfr/* $out/usr/share/tiny-dfr/
install -D -m 644 etc/systemd/system/tiny-dfr.service $out/usr/lib/systemd/system/tiny-dfr.service
install -D -m 644 -t $out/usr/lib/udev/rules.d \
    etc/udev/rules.d/99-touchbar-seat.rules etc/udev/rules.d/99-touchbar-tiny-dfr.rules
