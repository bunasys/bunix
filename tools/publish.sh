#!/bin/bash
# Puts together one release's files, of every architecture, signed and
# ready to upload (docs/release.md):
#
#   tools/publish.sh out/updates            # -> out/updates/<release>/
#
# <release> is release-version in include/release.yml.  What is built is
# the last commit, not what is in the working tree beside it: each
# builder is sent the commit's files, so both architectures are of the
# same source, and the commit is what docs/release.md tags.  The
# directory, if not given from /, is the repository's.  For each architecture
# (<arch>: arm64, x86-64) the directory holds
#
#   bunix_<release>.usr-<arch>*.<id>.raw  the three partitions of a /usr
#                                         slot (nix/images/update.nix)
#   bunix_<release>.<arch>.efi            the kernel image that starts it
#   devtools_<release>.<arch>.raw         the devtools extension
#                                         (nix/images/devtools.nix)
#
# and, once, for all of them:
#
#   SHA256SUMS      their hashes, and a BEST-BEFORE-<date> entry: a
#                   machine refuses the list after that day, so that a
#                   mirror cannot keep machines on it forever
#   SHA256SUMS.gpg  the list's signature, by the release key
#
# Two keys sign, and neither is in a file: 1Password asks for the image
# key four times (a system and an extension for each architecture,
# tools/sign.sh) and for the release key once (tools/sign-list.sh).
#
# What a signature here vouches for is what the builders made of the
# commit: a builder says what the hash of its image is.  Each hash is
# shown before it is signed, and of what a builder sends back only its
# own architecture's files are taken.
#
# Nothing is uploaded here.  tools/release-test.sh tries the directory in
# a virtual machine first.  A run that fails leaves no <release>.
#
#   BUNIX_ARCHITECTURES  what to build for; default "aarch64 x86_64"
#   BUNIX_X86_BUILDER    where x86_64 is built, for ssh; default
#                        enas-asus.home.arpa.  (aarch64 is built on this
#                        Mac, in the builder of tools/nix-builder/lima.yaml.)
#   BUNIX_MANIFEST_DAYS  for how long the list is good; default 30
#   BUNIX_SIGNED_BY      `development`: test systems' files, whose images
#                        the builds sign with the development key
#                        (nix/development-key/README), and a list signed
#                        with the key in BUNIX_RELEASE_KEY_FILE.  To try
#                        this script and tools/release-test.sh without
#                        the real keys; the directory says -development
#                        in its name, and is never to be uploaded.
#
# Needs: git, limactl with the builder running, ssh to the x86_64
# builder, and what tools/sign.sh and tools/sign-list.sh need.
set -euo pipefail
cd "$(dirname "$0")/.."

out=${1:?usage: tools/publish.sh <output directory>}
architectures=${BUNIX_ARCHITECTURES:-aarch64 x86_64}
x86_builder=${BUNIX_X86_BUILDER:-enas-asus.home.arpa}
days=${BUNIX_MANIFEST_DAYS:-30}
signed_by=${BUNIX_SIGNED_BY:-release}

die() {
    echo "publish.sh: $*" >&2
    exit 1
}

# What would stop this run is found now, not after the builds.
command -v sq > /dev/null || die "no sq to sign the list with (brew install sequoia-sq)"
case $signed_by in
    release)
        # A key from a file is for a trial; left in the environment, it
        # would sign a release in place of bunix's.
        if [ -n "${BUNIX_RELEASE_KEY_FILE:-}${BUNIX_VERITY_KEY_FILE:-}" ]; then
            die "a release takes its keys from the password manager: unset BUNIX_RELEASE_KEY_FILE and BUNIX_VERITY_KEY_FILE"
        fi ;;
    development)
        [ -r "${BUNIX_RELEASE_KEY_FILE:-}" ] \
            || die "BUNIX_SIGNED_BY=development needs a key for the list in BUNIX_RELEASE_KEY_FILE (from /, or from the repository)" ;;
    *) die "BUNIX_SIGNED_BY is development, or not set" ;;
esac

version=$(git show HEAD:include/release.yml | sed -n 's/^  release-version: *//p')
commit=$(git rev-parse HEAD)
release=$out/$version
if [ $signed_by = development ]; then
    release=$release-development
fi
[ ! -e "$release" ] || die "$release is there already; move it away first"

# The tests build the working tree, and this the commit: what differs
# between the two was tested and is not released, or the other way round.
not_committed=$(git status --porcelain --untracked-files=no)
if [ -n "$not_committed" ]; then
    echo "publish.sh: changed since the commit, and NOT in this release:"
    echo "$not_committed"
fi

# The files are gathered beside where they are to be, and the directory
# gets its name once all of it is there and checked.
unfinished=$release.unfinished
rm -rf "$unfinished"
mkdir -p "$unfinished"
trap 'rm -rf "$unfinished"' EXIT

# in_builder <architecture> <shell commands>: runs them where that
# architecture is built, in the home directory there (where ssh starts).
# The commands are to have no single quote in them: x86_64's go to ssh
# inside a pair of them.
#
# The x86_64 builder's own shell is not bash, and its Nix is one
# installed for its user alone (tools/nix-builder/home-store/nix.conf),
# which is found by these two variables.
x86_nix='export NIX_CONF_DIR=$HOME/nix-tool PATH=$HOME/nix-tool/bin:$PATH'
in_builder() {
    case $1 in
        aarch64) limactl shell bunix-builder bash -c "cd && $2" ;;
        x86_64) ssh "$x86_builder" "bash -c '$x86_nix && $2'" ;;
        *) die "nothing builds for $1" ;;
    esac
}
# build <architecture> <nix-build's arguments>: prints where the builder
# has what was built, and nothing else, on its standard output.  That is
# the store path nix-build prints, but for x86_64: its store is under its
# user's home directory, and /nix/store/... is no path there.
build() {
    built_for=$1
    shift
    store_path=$(in_builder "$built_for" "nix-build $* --no-out-link")
    case $built_for in
        x86_64) echo "nix-root$store_path" ;;
        *) echo "$store_path" ;;
    esac
}
# leave_signature <architecture> <root hash> <file at the builder>: signs
# the hash here, where the password manager is, and leaves the signature
# with the builder, for its build to take.
leave_signature() {
    echo "  $2"
    tools/sign.sh "$2" | in_builder "$1" "cat > $3"
}

# ---- Each architecture's files -------------------------------------------------

images=bunix-release/source/nix/images
system_signature=bunix-release/system.signature
devtools_signature=bunix-release/devtools.signature
for architecture in $architectures; do
    echo "$architecture: sending the source, as of commit $commit"
    git archive "$commit" | in_builder "$architecture" \
        "rm -rf bunix-release && mkdir -p bunix-release/source && tar -xf - -C bunix-release/source"

    # A test system's images are signed in their builds.  A release's
    # are built up to their hashes, the hashes signed here, and the
    # builds then given the signatures.
    system_signed=
    devtools_signed=
    if [ $signed_by = release ]; then
        echo "$architecture: building the system and the extension, up to what is signed"
        system=$(build "$architecture" $images/system.nix --argstr signing release)
        system_hash=$(in_builder "$architecture" "cat $system/usr-partition/usrhash")
        devtools_parts=$(build "$architecture" $images/devtools.nix -A parts)
        devtools_hash=$(in_builder "$architecture" "cat $devtools_parts/roothash")

        echo "$architecture: signing the hash of the system, and of the extension"
        leave_signature "$architecture" "$system_hash" $system_signature
        leave_signature "$architecture" "$devtools_hash" $devtools_signature
        system_signed="--arg signature ./$system_signature"
        devtools_signed="--arg signature ./$devtools_signature"
    fi

    echo "$architecture: building the files of bunix $version"
    update=$(build "$architecture" $images/update.nix $system_signed)
    devtools=$(build "$architecture" $images/devtools.nix -A image $devtools_signed)
    received=$unfinished/from-$architecture
    mkdir "$received"
    for built in $update $devtools; do
        in_builder "$architecture" "cd $built && tar -cf - *" | tar -xf - -C "$received"
    done

    # Taken of what came: this architecture's five files, and files they
    # have to be.  A builder is another machine, and what it sends goes
    # into a list that the release key signs: not a file under the other
    # architecture's name, and not a link to a file of this Mac's.
    case $architecture in
        aarch64) named=arm64 ;;
        x86_64) named=x86-64 ;;
    esac
    for file in "$received"/*; do
        case ${file##*/} in
            "bunix_$version.usr-$named."*.raw | "bunix_$version.usr-$named-verity."*.raw) ;;
            "bunix_$version.usr-$named-verity-sig."*.raw) ;;
            "bunix_$version.$named.efi" | "devtools_$version.$named.raw") ;;
            *) die "the $architecture builder sent ${file##*/}, which is no file of bunix $version for $named" ;;
        esac
        is_a_file=no
        if [ -f "$file" ] && [ ! -L "$file" ]; then
            is_a_file=yes
        fi
        [ $is_a_file = yes ] || die "the $architecture builder sent ${file##*/}, which is not a file"
    done
    number_received=$(ls "$received" | wc -l)
    [ "$number_received" -eq 5 ] || die "the $architecture builder sent $number_received files, not five"
    # out of a store they come read-only
    chmod u+w "$received"/*
    mv "$received"/* "$unfinished/"
    rmdir "$received"
done

# ---- The list of them, and its signature ---------------------------------------

# The day is an entry of the list like a file's, with the hash of no
# bytes: that is how systemd reads it.  (date -v: this runs on a Mac.)
best_before=BEST-BEFORE-$(date -u -v+"$days"d +%F)
(cd "$unfinished" && touch "$best_before" && shasum -a 256 * > SHA256SUMS && rm "$best_before")
tools/sign-list.sh "$unfinished/SHA256SUMS" > "$unfinished/SHA256SUMS.gpg"

# Signed by the key machines take, and not by another document of the
# password manager: checked with the certificate they come with.
if [ $signed_by = release ]; then
    sq --home none verify --signer-file files/rootfs/usr/lib/systemd/import-pubring.pgp \
        --signature-file "$unfinished/SHA256SUMS.gpg" "$unfinished/SHA256SUMS" > /dev/null
fi

mv "$unfinished" "$release"
ls -l "$release"
if [ $signed_by = development ]; then
    echo "publish.sh: test systems' files, signed by no key of bunix's: NOT to be uploaded"
    exit 0
fi
echo "publish.sh: bunix $version is in $release"
echo "  next: tools/release-test.sh $release <the version before>"
echo "  its tag, when it is published (docs/release.md): git tag v$version $commit"
