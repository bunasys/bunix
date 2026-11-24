#!/bin/bash
# Signs the list of a release's files with bunix's release key, which is
# in a password manager: it is asked for here, used, and gone.  As
# tools/sign.sh does for the hash of an image; one of a release's three
# kinds of signature (docs/updates.md; tools/sign-kernel-image.sh is the
# third).
#
#   tools/sign-list.sh <release directory>/SHA256SUMS > <release directory>/SHA256SUMS.gpg
#
# The list names each file a machine may download, with its hash, and the
# day until which the list is good.  A machine takes the list only with
# this signature, by the certificate it comes with
# (files/rootfs/usr/lib/systemd/import-pubring.pgp), and a file only
# with the hash the list says.  tools/publish.sh writes the list and
# calls this.
#
#   BUNIX_RELEASE_KEY_FILE
#           a file to take the key from, in place of the password
#           manager: for a key made to try this with
#
# Needs: Sequoia's sq, and the 1Password command line (op), signed in,
# with the key as the document "bunix release key".
set -euo pipefail

list=${1:?usage: sign-list.sh <list of files> > signature}
if [ ! -s "$list" ]; then
    echo "sign-list.sh: no list of files in $list" >&2
    exit 1
fi
if [ -t 1 ]; then
    echo "sign-list.sh: the signature is not text; send it to a file" >&2
    exit 1
fi

# The key goes from where it is kept into sq through a pipe: it is on no
# disk on the way.
key() {
    if [ -n "${BUNIX_RELEASE_KEY_FILE:-}" ]; then
        cat "$BUNIX_RELEASE_KEY_FILE"
    else
        op document get "bunix release key"
    fi
}

# --home none: sq is to take nothing from, and keep nothing in, the
# stores of keys it has for a person.  --binary, and beside the list
# rather than around it: the form systemd asks for (SHA256SUMS.gpg).
# sq says on its standard error whose key signed.
sq --home none sign --signer-file <(key) --signature-file - --binary "$list"
