#!/bin/bash
# Put together one release's update files, ready to upload:
#
#   tools/bst-remote.sh build system/uki.bst sysext/gcc.bst sysext/rust.bst sysext/swift.bst \
#     sysext/devtools.bst sysext/desktop.bst
#   tools/publish.sh out/updates            # -> out/updates/<release>/
#
# <release> is release-version in include/release.yml; the directory holds
#
#   bunix_<release>.usr-x86-64*.<uuid>.raw  the three partitions of a /usr
#                         slot (system/usr.bst)
#   bunix_<release>.efi   the UKI that boots it (system/uki.bst)
#   gcc_<release>.raw   the gcc extension (sysext/gcc.bst), and rust_,
#                         swift_, devtools_ and desktop_<release>.raw likewise
#   SHA256SUMS            their hashes, and a BEST-BEFORE-<date> entry: systemd-
#                         sysupdate refuses the manifest after that date, so
#                         a mirror cannot keep machines on it forever
#   SHA256SUMS.gpg        OpenPGP signature over SHA256SUMS, by the release
#                         key (keys/release.key), made with Sequoia's sqop
#
# and is uploaded as is, to the URL in files/rootfs/usr/lib/sysupdate.d/
# (one directory per release).  Signing runs on the build host, in
# `bst shell tools/sqop.bst`; the key is copied there for the signature only.
#
# BUNIX_MANIFEST_DAYS sets how long the manifest is valid (default 30).
set -euo pipefail
cd "$(dirname "$0")/.."

out=${1:?usage: tools/publish.sh <output directory>}
HOST=${BUNIX_BUILD_HOST:-pro13.home.arpa}
DAYS=${BUNIX_MANIFEST_DAYS:-30}
BST='~/.local/share/bunix-bst/bin/bst'
release=$(sed -n 's/^  release-version: *//p' include/release.yml)
remote=bunix-publish/$release

ssh "$HOST" "rm -rf ~/$remote ~/$remote.parts && mkdir -p ~/$remote.parts && cd src/bunix &&
  for element in system/usr.bst system/uki.bst sysext/gcc.bst sysext/rust.bst sysext/swift.bst sysext/devtools.bst sysext/desktop.bst; do
    $BST artifact checkout \$element --directory ~/$remote.parts/\$(basename \$element .bst)
  done &&
  mkdir ~/$remote && mv ~/$remote.parts/*/*.raw ~/$remote.parts/*/*.efi ~/$remote/ &&
  rm -rf ~/$remote.parts"

ssh "$HOST" "cd ~/$remote && best_before=\$(date -u -d '+$DAYS days' +%F) &&
  touch BEST-BEFORE-\$best_before &&
  sha256sum *.raw *.efi BEST-BEFORE-\$best_before > SHA256SUMS &&
  rm BEST-BEFORE-\$best_before && cat SHA256SUMS"

# The key goes to a private directory on the host for the one signature.
keydir=$(ssh "$HOST" 'mktemp -d')
trap 'ssh "$HOST" "rm -rf $keydir"' EXIT
scp -q keys/release.key "$HOST:$keydir/release.key"
ssh "$HOST" "cd src/bunix && $BST shell --mount ~/$remote /release --mount $keydir /key \
  tools/sqop.bst -- sh -c 'sqop sign --no-armor /key/release.key < /release/SHA256SUMS > /release/SHA256SUMS.gpg'"

mkdir -p "$out"
rsync -a --delete "$HOST:$remote/" "$out/$release/"
ls -l "$out/$release"
