# The source is a directory of the repository, not an archive.
cp -r $source_directory/. .
chmod -R u+w .

# As bunix-command.sh, but the program is not one a person runs: udev
# does (the rule below), so it is not in /usr/bin.
export CARGO_HOME=$PWD/cargo-home
cargo install --path . --root /build/installed --no-track --offline --locked -j$jobs
install -D -m 755 /build/installed/bin/boot-picture $out/usr/lib/bunix/boot-picture

# the picture it draws, where it looks for it, and what has udev run it
install -D -m 644 $picture $out/usr/share/bunix/boot-picture.bmp
install -D -m 644 $rule $out/usr/lib/udev/rules.d/90-bunix-boot-picture.rules
