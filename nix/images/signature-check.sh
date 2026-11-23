# Checks the signature of an image's root hash before it becomes part of
# what is published (images/update.sh, images/extension.sh source this).
# Here, where a wrong one costs a build, and not on a machine.
#
# check_signature <root hash> <signature> <certificate>: fails unless the
# signature (tools/sign.sh) is of this hash, and made with the key of
# this certificate.
check_signature() {
    local root_hash=$1 signature=$2 certificate=$3
    if ! grep -a -q "\"rootHash\":\"$root_hash\"" $signature; then
        echo "$signature is not the signature of the hash $root_hash" >&2
        return 1
    fi
    tr -d '\000' < $signature | sed 's/.*"signature":"\([^"]*\)".*/\1/' | base64 -d > signature.der
    printf %s $root_hash > signed
    # -noverify: the certificate is not asked who vouches for it; it is
    # the one given.
    if ! openssl smime -verify -binary -noverify -nointern -inform der -in signature.der \
            -content signed -certfile $certificate -out /dev/null; then
        echo "$signature was not made with the key of $certificate" >&2
        return 1
    fi
}
