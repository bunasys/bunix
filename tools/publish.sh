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
#   bunix_<release>.<arch>.efi            the kernel image that starts it;
#                                         x86-64's signed for Secure Boot
#   devtools_<release>.<arch>.raw         the devtools extension
#                                         (nix/images/devtools.nix)
#   llvm_<release>.<arch>.raw             the llvm extension
#                                         (nix/images/llvm.nix)
#   desktop_<release>.<arch>.raw          the desktop extension
#                                         (nix/images/desktop.nix)
#
# and, once, for all of them:
#
#   SHA256SUMS      their hashes, and a BEST-BEFORE-<date> entry: a
#                   machine refuses the list after that day, so that a
#                   mirror cannot keep machines on it forever
#   SHA256SUMS.gpg  the list's signature, by the release key
#
# Three keys sign, and none is in a file: 1Password asks for the image
# key once an image (the system and each of $extensions below, for each
# architecture; tools/sign.sh), for the Secure Boot key once (the x86_64
# kernel image, tools/sign-kernel-image.sh), and for the release key once
# (tools/sign-list.sh).
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
#                        enas-asus.home.arpa
#   BUNIX_AARCH64_BUILDER
#                        the Mac that has the builder of
#                        tools/nix-builder/lima.yaml, where aarch64 is
#                        built, for ssh; default: this Mac.  For a run
#                        on another Mac than the builder's: the one
#                        whose person is at it, for the password manager.
#   BUNIX_MANIFEST_DAYS  for how long the list is good; default 30
#   BUNIX_SIGNED_BY      `development`: test systems' files, whose images
#                        the builds sign with the development key
#                        (nix/development-key/README), and a list signed
#                        with the key in BUNIX_RELEASE_KEY_FILE.  To try
#                        this script and tools/release-test.sh without
#                        the real keys; the directory says -development
#                        in its name, and is never to be uploaded.
#
# Needs: git, limactl with the builder running (here, or on
# BUNIX_AARCH64_BUILDER), ssh to the x86_64 builder, and what
# tools/sign.sh, tools/sign-kernel-image.sh and tools/sign-list.sh need.
set -euo pipefail
cd "$(dirname "$0")/.."

out=${1:?usage: tools/publish.sh <output directory>}
architectures=${BUNIX_ARCHITECTURES:-aarch64 x86_64}
x86_builder=${BUNIX_X86_BUILDER:-enas-asus.home.arpa}
aarch64_builders_mac=${BUNIX_AARCH64_BUILDER:-}
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
        if [ -n "${BUNIX_RELEASE_KEY_FILE:-}${BUNIX_VERITY_KEY_FILE:-}${BUNIX_SECURE_BOOT_KEY_FILE:-}" ]; then
            die "a release takes its keys from the password manager: unset BUNIX_RELEASE_KEY_FILE, BUNIX_VERITY_KEY_FILE and BUNIX_SECURE_BOOT_KEY_FILE"
        fi
        # and its certificates from the repository
        if [ -n "${BUNIX_VERITY_CERTIFICATE:-}${BUNIX_SECURE_BOOT_CERTIFICATE:-}" ]; then
            die "a release's signatures are checked against bunix's certificates: unset BUNIX_VERITY_CERTIFICATE and BUNIX_SECURE_BOOT_CERTIFICATE"
        fi
        case " $architectures " in
            *" x86_64 "*)
                command -v osslsigncode > /dev/null \
                    || die "no osslsigncode to sign the x86_64 kernel image with (brew install osslsigncode)"
                [ -r keys/secureboot.crt ] \
                    || die "no keys/secureboot.crt: the certificate of the key the x86_64 kernel image is signed with" ;;
        esac ;;
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
# The commands are to have no single quote in them: what goes to ssh
# goes inside a pair of them.
#
# The x86_64 builder's own shell is not bash, and its Nix is one
# installed for its user alone (tools/nix-builder/home-store/nix.conf),
# which is found by these two variables.
x86_nix='export NIX_CONF_DIR=$HOME/nix-tool PATH=$HOME/nix-tool/bin:$PATH'
in_builder() {
    case $1 in
        aarch64)
            if [ -z "$aarch64_builders_mac" ]; then
                limactl shell bunix-builder bash -c "cd && $2"
            else
                ssh "$aarch64_builders_mac" "limactl shell bunix-builder bash -c 'cd && $2'"
            fi ;;
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
# each has nix/images/<name>.nix, and a feature of its name in the system
extensions="devtools llvm desktop"
for architecture in $architectures; do
    echo "$architecture: sending the source, as of commit $commit"
    git archive "$commit" | in_builder "$architecture" \
        "rm -rf bunix-release && mkdir -p bunix-release/source && tar -xf - -C bunix-release/source"

    # A test system's images are signed in their builds.  A release's
    # are built up to their hashes, the hashes signed here, and the
    # builds then given the signatures.
    system_signed=
    if [ $signed_by = release ]; then
        echo "$architecture: building the system, up to what is signed, and signing its hash"
        system=$(build "$architecture" $images/system.nix --argstr signing release)
        system_hash=$(in_builder "$architecture" "cat $system/usr-partition/usrhash")
        leave_signature "$architecture" "$system_hash" $system_signature
        system_signed="--arg signature ./$system_signature"
    fi

    echo "$architecture: building the files of bunix $version"
    built_directories=$(build "$architecture" $images/update.nix $system_signed)
    for extension in $extensions; do
        extension_signed=
        if [ $signed_by = release ]; then
            echo "$architecture: the $extension extension, up to what is signed, and signing its hash"
            extension_signature=bunix-release/$extension.signature
            extension_parts=$(build "$architecture" $images/$extension.nix -A parts)
            extension_hash=$(in_builder "$architecture" "cat $extension_parts/roothash")
            leave_signature "$architecture" "$extension_hash" $extension_signature
            extension_signed="--arg signature ./$extension_signature"
        fi
        extension_image=$(build "$architecture" $images/$extension.nix -A image $extension_signed)
        built_directories="$built_directories $extension_image"
    done
    received=$unfinished/from-$architecture
    mkdir "$received"
    for directory in $built_directories; do
        in_builder "$architecture" "cd $directory && tar -cf - *" | tar -xf - -C "$received"
    done

    # Taken of what came: this architecture's files, and files they have
    # to be: the four of the system, and one for each extension.  A
    # builder is another machine, and what it sends goes into a list that
    # the release key signs: not a file under the other architecture's
    # name, and not a link to a file of this Mac's.
    case $architecture in
        aarch64) named=arm64 ;;
        x86_64) named=x86-64 ;;
    esac
    extension_files=
    for extension in $extensions; do
        extension_files="$extension_files ${extension}_$version.$named.raw"
    done
    for file in "$received"/*; do
        is_an_extension=no
        case " $extension_files " in
            *" ${file##*/} "*) is_an_extension=yes ;;
        esac
        case $is_an_extension:${file##*/} in
            yes:*) ;;
            no:"bunix_$version.usr-$named."*.raw | no:"bunix_$version.usr-$named-verity."*.raw) ;;
            no:"bunix_$version.usr-$named-verity-sig."*.raw) ;;
            no:"bunix_$version.$named.efi") ;;
            *) die "the $architecture builder sent ${file##*/}, which is no file of bunix $version for $named" ;;
        esac
        is_a_file=no
        if [ -f "$file" ] && [ ! -L "$file" ]; then
            is_a_file=yes
        fi
        [ $is_a_file = yes ] || die "the $architecture builder sent ${file##*/}, which is not a file"
    done
    number_received=$(ls "$received" | wc -l)
    number_of_extensions=$(echo $extensions | wc -w)
    number_expected=$((4 + number_of_extensions))
    [ "$number_received" -eq "$number_expected" ] \
        || die "the $architecture builder sent $number_received files, not $number_expected"
    # out of a store they come read-only
    chmod u+w "$received"/*

    # A release's x86_64 kernel image is signed here, where the password
    # manager is; a test system's was signed in its build, with the
    # development key (nix/images/uki.nix).
    if [ $signed_by = release ] && [ "$architecture" = x86_64 ]; then
        echo "$architecture: signing the kernel image for Secure Boot"
        kernel_image=$received/bunix_$version.$named.efi
        tools/sign-kernel-image.sh "$kernel_image" "$kernel_image.signed"
        mv "$kernel_image.signed" "$kernel_image"
    fi
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
