# speakersafetyd (docs/mac-speakers.md): keeps a Mac's speakers within
# what they take, from a model of their temperature that the amplifiers'
# voltage and current feed; macaudio plays through them only while it
# runs.  Upstream's 2.0.1 with Aurora Silicon's fixes ($patches) and
# Aurora's profiles of the Macs upstream lacks ($aurora: files/
# speakersafetyd/aurora).  Started by its udev rule when a Mac it has a
# profile for shows its speakers' sense PCM: on no other machine.
unpack $src
for fix in $patches; do
    patch --fuzz=0 -p1 -i $fix
done

# ../cargo.sh's lines that give cargo its crates (the same lines are in
# every Rust package's script that does not use cargo.sh: a fix to one
# is a fix to each).  Not cargo.sh itself: the Makefile, below, installs
# the unit, udev rule and profiles with the program.
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

# The program, its unit, its udev rule and the profiles, as its Makefile
# installs them, under /usr
make install DESTDIR=$out BINDIR=/usr/bin UNITDIR=/usr/lib/systemd/system \
    UDEVDIR=/usr/lib/udev/rules.d SHAREDIR=/usr/share
install -m 644 $aurora/j616.conf $aurora/j575c.conf $out/usr/share/speakersafetyd/apple/
install -m 644 $aurora/96-speakersafetyd-aurora.rules $out/usr/lib/udev/rules.d/
install -D -m 644 $aurora/50-aurora-warm-restart.conf \
    $out/usr/lib/systemd/system/speakersafetyd.service.d/50-aurora-warm-restart.conf
# the J293's profile (mbp20): the build fails here, rather than the
# speakers staying silent on the Mac
[ -f $out/usr/share/speakersafetyd/apple/j293.conf ]
