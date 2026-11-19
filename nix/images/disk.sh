# Makes the disk of images/disk.nix with systemd-repart, from the
# description of its partitions written here.
#
# $system_image is the result of images/system.nix; its usr-partition/ has
# /usr's image, the hashes of its blocks, the root hash and the version
# (image.sh).
# $signature is the signature of that hash (tools/sign.sh), and
# $certificate the certificate of the key it is to be of.
set -euo pipefail
cd /build
export SOURCE_DATE_EPOCH=1728000000

usr=$system_image/usr-partition
version=$(cat $usr/version)
usrhash=$(cat $usr/usrhash)
# The two partitions are found by ids made of the root hash: its first
# half is /usr's, its second half the hashes' (the Discoverable Partitions
# Specification).  With the dashes an id is written with.
as_id() {
    echo "${1:0:8}-${1:8:4}-${1:12:4}-${1:16:4}-${1:20:12}"
}
usr_id=$(as_id ${usrhash:0:32})
usr_verity_id=$(as_id ${usrhash:32:32})

mkdir -p disk.d tmp
# /usr and its hashes: the images, block for block.  The labels carry the
# version: sysupdate reads what is installed from them.
printf '%s\n' '[Partition]' 'Type=usr' "CopyBlocks=$usr/usr.raw" \
    "UUID=$usr_id" "Label=bunix_$version" > disk.d/10-usr.conf
printf '%s\n' '[Partition]' 'Type=usr-verity' "CopyBlocks=$usr/usr-verity.raw" \
    "UUID=$usr_verity_id" "Label=bunix_${version}_verity" > disk.d/20-usr-verity.conf
# The signature of the hash: for what is not told the hash on its command
# line, and so finds /usr by whose it is.  Checked here, where a wrong one
# costs a build, and not on a machine: that it is of this hash, and made
# with the key of this certificate.  (-noverify: the certificate is not
# asked who vouches for it; it is the one given.)
if ! grep -a -q "\"rootHash\":\"$usrhash\"" $signature; then
    echo "disk.sh: $signature is not the signature of this system's hash, $usrhash" >&2
    exit 1
fi
tr -d '\000' < $signature | sed 's/.*"signature":"\([^"]*\)".*/\1/' | base64 -d > signature.der
printf %s $usrhash > signed
if ! openssl smime -verify -binary -noverify -nointern -inform der -in signature.der \
        -content signed -certfile $certificate -out /dev/null; then
    echo "disk.sh: $signature was not made with the key of $certificate" >&2
    exit 1
fi
# 16K: what systemd gives such a partition, and room for a signature that
# is longer than this one
printf '%s\n' '[Partition]' 'Type=usr-verity-sig' "CopyBlocks=$signature" \
    'SizeMinBytes=16K' "Label=bunix_${version}_verity_sig" > disk.d/30-usr-verity-sig.conf
# The root partition: /etc, /var, /home.  Empty but for what has to be
# there before systemd can make the rest: the directories that are mounted
# on, the links of a UAPI.9 root as image.sh has them (/lib64 only where
# the loader is asked for there), and the journal's directory, without
# which the journal stays in memory.  Not /root: systemd makes it, for
# root alone.  No validatefs: a build cannot store the attribute it marks
# a file system with.
links='/bin:usr/bin /sbin:usr/bin /lib:usr/lib'
case $loader in
    /lib64/*) links="$links /lib64:usr/lib/$triplet" ;;
esac
printf '%s\n' '[Partition]' 'Type=root' 'Format=ext4' 'Label=bunix-root' 'SizeMinBytes=512M' \
    'AddValidateFS=no' \
    'MakeDirectories=/usr /etc /var /var/log/journal /home /srv /tmp /proc /sys /dev /run' \
    "MakeSymlinks=$links" > disk.d/50-root.conf

mkdir -p $out
# --offline: without the loop devices a build does not have
TMPDIR=/build/tmp systemd-repart --empty=create --size=auto --dry-run=no --offline=yes \
    --definitions=disk.d --seed=$(printf 'bunix disk' | sha256sum | head -c 32) \
    $out/disk.raw
cp $usr/usrhash $out/usrhash
