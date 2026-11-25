# Whether a file a release build is handed, signed for Secure Boot where
# bunix's key is (tools/publish.sh), is this build's own, signed by that
# key: a build has no key to sign with, and takes nothing else in its
# place.  "This build's own": the hash the signature covers (Authenticode's,
# the same whoever signs) is that of the build's unsigned file signed here
# with the development key, by the script a release's is signed with.
#
#   check-release-signed.sh <the build's unsigned file> <the signed one handed to it>
#
# from the build's environment: $sign_kernel_image, $development_key,
# $development_certificate, $release_certificate.  Stops the build if not.
set -euo pipefail
unsigned=$1
release_signed=$2
work=$(mktemp -d)

BUNIX_SECURE_BOOT_KEY_FILE=$development_key BUNIX_SECURE_BOOT_CERTIFICATE=$development_certificate \
    bash $sign_kernel_image $unsigned $work/development-signed.efi

# What a signature covers, as osslsigncode works it out of the file.
# (A file whose signature does not verify still has it worked out, and
# is turned down below, with a word of why, not ended here by pipefail.)
covered_hash() {
    { osslsigncode verify -CAfile "$2" -in "$1" 2>&1 || true; } | sed -n 's/^Calculated message digest *: *//p' | tr -d ' '
}
release_hash=$(covered_hash $release_signed $release_certificate)
own_hash=$(covered_hash $work/development-signed.efi $development_certificate)
is_signed_by_bunix=no
if osslsigncode verify -CAfile $release_certificate -in $release_signed > /dev/null 2>&1; then
    is_signed_by_bunix=yes
fi
is_this_builds_own=no
if [ -n "$own_hash" ] && [ "$release_hash" = "$own_hash" ]; then
    is_this_builds_own=yes
fi
rm -r $work
if [ $is_signed_by_bunix = no ] || [ $is_this_builds_own = no ]; then
    echo "check-release-signed.sh: $release_signed is not $(basename $unsigned) signed by bunix's key" >&2
    exit 1
fi
