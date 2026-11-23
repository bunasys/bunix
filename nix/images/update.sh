# Makes the files of images/update.nix: one version, as it is downloaded.
#
# $system_image is the result of images/system.nix; its usr-partition/ has
# /usr's image, the hashes of its blocks, the root hash and the version
# (image.sh).
# $uki is the result of images/uki.nix: what starts that system.
# $signature is the signature of that hash (tools/sign.sh), and
# $certificate the certificate of the key it is to be of.
# $partition_architecture: arm64, x86-64 (nix/architecture.nix).
# $signature_check: images/signature-check.sh.
set -euo pipefail
cd /build

usr=$system_image/usr-partition
version=$(cat $usr/version)
usrhash=$(cat $usr/usrhash)

# ---- The signature, checked ---------------------------------------------------

source $signature_check
check_signature $usrhash $signature $certificate

# ---- The files, under the names they are asked for by -------------------------

# The two partitions of /usr are found by ids made of the root hash: its
# first half is /usr's, its second half the hashes' (the Discoverable
# Partitions Specification).  With the dashes an id is written with.
as_id() {
    echo "${1:0:8}-${1:8:4}-${1:12:4}-${1:16:4}-${1:20:12}"
}
# The signature's partition is found by its type, beside them; its id
# only has to differ from version to version, two of which are on one
# disk, so it is made of the hash as well.
signature_id=$(printf 'bunix usr-verity-sig %s' $usrhash | sha256sum | head -c 32)

name=bunix_$version.usr-$partition_architecture
mkdir -p $out
cp $usr/usr.raw $out/$name.$(as_id ${usrhash:0:32}).raw
cp $usr/usr-verity.raw $out/$name-verity.$(as_id ${usrhash:32:32}).raw
cp $signature $out/$name-verity-sig.$(as_id $signature_id).raw
cp $uki/bunix_$version.efi $out/bunix_$version.$partition_architecture.efi
