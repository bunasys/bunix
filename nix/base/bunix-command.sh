# The source is a directory of the repository, not an archive.
cp -r $source_directory/. .
chmod -R u+w .

# As ../cargo.sh, with no crates to give cargo: --offline, and it asks
# for none.
export CARGO_HOME=$PWD/cargo-home
cargo install --path . --root $out/usr --no-track --offline --locked -j$jobs
