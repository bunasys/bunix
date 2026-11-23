#!/bin/bash
# Signs a kernel image for Secure Boot with bunix's key, which is in a
# password manager: it is asked for here, used, and gone.  One of a
# release's three kinds of signature, beside tools/sign.sh's (an image's
# hash) and tools/sign-list.sh's (the list of a release's files).
#
#   tools/sign-kernel-image.sh <kernel image> <the signed one, to write>
#
# A release's x86_64 kernel image, by hand, on this Mac, with the builder
# of tools/nix-builder/lima.yaml on the x86_64 builder's place (its
# image is built unsigned, as for release: publish.sh does the same):
#
#   image=$(nix-build /bunix/nix/images/uki.nix --argstr signing release --no-out-link)
#   tools/sign-kernel-image.sh $image/bunix_<version>.efi out/bunix_<version>.x86-64.efi
#
# A PC with Secure Boot on starts only what is signed by a key it knows.
# Its firmware knows Microsoft's, which signed shim; shim knows the keys
# a machine's owner enrolled with it, which is where bunix's goes
# (docs/install.md); and with shim there, systemd-boot asks it about
# each kernel image.  So an x86-64 kernel image of a release has this
# signature, or such a machine does not start it.  tools/publish.sh calls
# this.  A Mac has no Secure Boot, and its kernel image no signature.
#
# The signature is in the file itself, after what it signs: a signed
# kernel image starts as the unsigned one does, where nothing checks.
# Made with the same key and the same image, it is the same to the
# byte: the time it says it was made is always the same (below).
#
# The build of a test system signs its kernel image with this script
# too, and the development key (nix/images/uki.nix), so that what a
# release's signature is made by is what every test starts with Secure
# Boot on (tools/secure-boot-test.sh).
#
#   BUNIX_SECURE_BOOT_KEY_FILE
#           a file to take the key from, in place of the password
#           manager: for the development key, which is not secret
#           (nix/development-key/README), with its certificate in
#           BUNIX_SECURE_BOOT_CERTIFICATE
#   BUNIX_SECURE_BOOT_CERTIFICATE
#           the key's certificate; default keys/secureboot.crt
#
# Needs: osslsigncode (brew install osslsigncode; a build has its own,
# nix/base.nix), and, for bunix's key, the 1Password
# command line (op), signed in, with the key as the document "bunix
# secure boot key".
set -euo pipefail

usage="usage: sign-kernel-image.sh <kernel image> <the signed one, to write>"
image=${1:?$usage}
signed=${2:?$usage}
if [ ! -s "$image" ]; then
    echo "sign-kernel-image.sh: no kernel image in $image" >&2
    exit 1
fi
if [ -e "$signed" ]; then
    echo "sign-kernel-image.sh: $signed is there already" >&2
    exit 1
fi
repository=$(cd "$(dirname "$0")/.." && pwd)
certificate=${BUNIX_SECURE_BOOT_CERTIFICATE:-$repository/keys/secureboot.crt}
if [ ! -r "$certificate" ]; then
    echo "sign-kernel-image.sh: no certificate in $certificate" >&2
    exit 1
fi

# The key goes from where it is kept into osslsigncode through a pipe:
# it is on no disk on the way.
key() {
    if [ -n "${BUNIX_SECURE_BOOT_KEY_FILE:-}" ]; then
        cat "$BUNIX_SECURE_BOOT_KEY_FILE"
    else
        op document get "bunix secure boot key"
    fi
}

# -time: the time the signature says it was made, which every signature
# has.  Always the same, as every file a build makes has the same time
# (SOURCE_DATE_EPOCH): a release's list of files may be signed again
# with a later day on it (docs/release.md), and only if every other file
# comes out the same to the byte.  Nothing that starts a kernel image
# checks this time against the certificate's.
osslsigncode sign -certs "$certificate" -key <(key) -h sha256 -time 1 \
    -in "$image" -out "$signed" > /dev/null

# Signed by this certificate's key, and not by another document of the
# password manager.
if ! verified=$(osslsigncode verify -CAfile "$certificate" -in "$signed" 2>&1); then
    rm -f "$signed"
    echo "$verified" >&2
    echo "sign-kernel-image.sh: osslsigncode does not find the signature good against $certificate" >&2
    exit 1
fi
