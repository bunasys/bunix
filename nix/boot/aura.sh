# Aura's images, in /usr/lib/aura:
#
#   aura.bin         the raw image: what a Mac is told to start
#                    (kmutil configure-boot --raw), and what a boot loader
#                    already running loads into memory
#   aura.macho       the same program in the format that the tools which
#                    drive a boot loader over USB load
#   aura-boot.macho  the raw image as a Mach-O boot object
#
# Stage 1 as the source's documents build it, with no configuration filled
# in: it waits for a computer on USB to tell it what to start.
#
# The directory is named as an archive of the source unpacks: with no
# repository to ask, aura takes the commit it labels itself with from
# that name, and what reads the label tells a release from a later commit
# by it.
unpack $src aura-$aura_commit
cd aura-$aura_commit

# Cargo is given the crates as a directory of their sources, one
# directory a crate, each with the checksum of the archive it came from
# (as base/bindgen.sh).  The repository and commit below are what
# rust/Cargo.lock names.
mkdir vendor
for crate in $crates; do
    name=$(basename $crate .crate)
    # the store's name is <hash>-<name>-<version>.crate
    name=${name#*-}
    unpack $crate vendor/$name
    checksum=$(sha256sum < $crate)
    echo "{\"files\":{},\"package\":\"${checksum%% *}\"}" > vendor/$name/.cargo-checksum.json
done
# the crate from a repository has no archive, and so no checksum
unpack $fatfs vendor/fatfs
echo '{"files":{},"package":null}' > vendor/fatfs/.cargo-checksum.json

export CARGO_HOME=$PWD/cargo-home
mkdir -p $CARGO_HOME
cat > $CARGO_HOME/config.toml <<END
[source.crates-io]
replace-with = "vendored"
[source.fatfs-repository]
git = "https://github.com/aurora-silicon/fatfs"
rev = "$fatfs_commit"
replace-with = "vendored"
[source.vendored]
directory = "$PWD/vendor"
[net]
offline = true
END
# Offline is said there, and the number of jobs here, because aura's
# makefile runs cargo and takes no arguments for it.
export CARGO_BUILD_JOBS=$jobs
cp rust/Cargo.lock Cargo.lock.pinned

# USE_CLANG, ARCH: clang, told the processor it compiles for, whatever the
#   builder's own is.
# RELEASE, CHAINLOADING: the Stage 1 of the source's documents.
make USE_CLANG=1 ARCH=aarch64-linux-gnu RELEASE=1 CHAINLOADING=1
# cargo was not told --locked either: had the crates above not been the
# lock's, it would have chosen others and rewritten it
cmp rust/Cargo.lock Cargo.lock.pinned

install -d $out/usr/lib/aura
install -m 644 build/aura.bin build/aura.macho build/aura-boot.macho $out/usr/lib/aura/
