# Makes an extension's image of its parts and the signature of its root
# hash (images/extension.nix, `image`).
#
#   $parts       the file system, its hashes, and the root hash
#                (extension-parts.sh)
#   $signature   the signature of that hash (tools/sign.sh), and
#   $certificate the certificate of the key it is to be of
#   $signature_check   images/signature-check.sh
#   $extension, $version, $partition_architecture
set -euo pipefail
cd /build

roothash=$(cat $parts/roothash)

# ---- The signature, checked ---------------------------------------------------

source $signature_check
check_signature $roothash $signature $certificate

# ---- The image -----------------------------------------------------------------

# The three as the partitions of one small disk.  The first two are found
# by ids made of the root hash, its first half and its second (the
# Discoverable Partitions Specification); the signature's by its type,
# beside them.
as_id() {
    echo "${1:0:8}-${1:8:4}-${1:12:4}-${1:16:4}-${1:20:12}"
}
mkdir -p image.d tmp $out
printf '%s\n' '[Partition]' 'Type=root' "CopyBlocks=$parts/root.raw" \
    "UUID=$(as_id ${roothash:0:32})" > image.d/10-root.conf
printf '%s\n' '[Partition]' 'Type=root-verity' "CopyBlocks=$parts/root-verity.raw" \
    "UUID=$(as_id ${roothash:32:32})" > image.d/20-root-verity.conf
printf '%s\n' '[Partition]' 'Type=root-verity-sig' "CopyBlocks=$signature" \
    > image.d/30-root-verity-sig.conf
# --offline: without the loop devices a build does not have.  --seed: the
# ids repart makes up are the same at every build.
TMPDIR=/build/tmp systemd-repart --empty=create --size=auto --dry-run=no --offline=yes \
    --definitions=image.d \
    --seed=$(printf 'bunix %s image %s' $extension $roothash | sha256sum | head -c 32) \
    $out/${extension}_$version.$partition_architecture.raw
