#!/bin/bash
# Signs the root hash of a bunix image with bunix's key, which is in a
# password manager: it is asked for here, used, and gone.  No build reads
# it, and it is in no file this script writes.
#
#   tools/sign.sh <root hash> > signature
#
# The root hash is what a build of images/system.nix writes as
# usr-partition/usrhash: 64 hexadecimal digits that stand for the whole
# of an image.  The signature is the contents of the partition that goes
# beside the image and its hashes, as systemd-repart would have written
# it: a line of JSON, with zeros after it to a whole block.  It is not
# secret, and for one key and one hash it is always the same.
#
# A system for release, on this Mac, with the builder of
# tools/nix-builder/lima.yaml (which sees the repository as /bunix):
#
#   system=$(limactl shell bunix-builder nix-build /bunix/nix/images/system.nix \
#       --argstr signing release --no-out-link)
#   hash=$(limactl shell bunix-builder cat $system/usr-partition/usrhash)
#   mkdir -p out
#   tools/sign.sh $hash > out/signature             # 1Password asks
#   limactl shell bunix-builder nix-build /bunix/nix/images/disk.nix \
#       --arg signature /bunix/out/signature --no-out-link
#
#   BUNIX_VERITY_KEY_FILE
#                       a file to take the key from, in place of the
#                       password manager: for the development key, which
#                       is not secret (nix/development-key/README), with
#                       its certificate in BUNIX_VERITY_CERTIFICATE
#   BUNIX_VERITY_CERTIFICATE
#                       the key's certificate; default keys/verity.crt
#
# Needs: openssl, and the 1Password command line (op), signed in, with the
# key as the document "bunix verity key".
set -euo pipefail

root_hash=${1:?usage: sign.sh <root hash> > signature}
if ! [[ $root_hash =~ ^[0-9a-f]{64}$ ]]; then
    echo "sign.sh: not a root hash (64 hexadecimal digits): $root_hash" >&2
    exit 1
fi
if [ -t 1 ]; then
    echo "sign.sh: the signature is a block with zeros in it; send it to a file" >&2
    exit 1
fi
repository=$(cd "$(dirname "$0")/.." && pwd)
certificate=${BUNIX_VERITY_CERTIFICATE:-$repository/keys/verity.crt}

# The key goes from where it is kept into openssl through a pipe: it is
# on no disk on the way, and in no argument that other programs can see.
key() {
    if [ -n "${BUNIX_VERITY_KEY_FILE:-}" ]; then
        cat "$BUNIX_VERITY_KEY_FILE"
    else
        op document get "bunix verity key"
    fi
}

# What is signed is the hash as it is written, in hexadecimal, which is
# what the kernel checks a signature against.  -noattr: no time of
# signing in it, so that the signature is the same whenever it is made.
# The certificate goes in with it, as systemd-repart puts it.
signature=$(printf %s "$root_hash" |
    openssl smime -sign -noattr -binary -md sha256 -signer "$certificate" \
        -inkey <(key) -outform der | base64 | tr -d '\n')
fingerprint=$(openssl x509 -in "$certificate" -outform der | openssl dgst -sha256 -r | cut -d' ' -f1)

json="{\"rootHash\":\"$root_hash\",\"certificateFingerprint\":\"$fingerprint\",\"signature\":\"$signature\"}"
block=4096
if [ ${#json} -gt $block ]; then
    echo "sign.sh: the signature is ${#json} bytes, and the block it goes in is $block" >&2
    exit 1
fi
# the line, and zeros after it to the end of the block
{ printf %s "$json"; head -c $block /dev/zero; } | head -c $block
