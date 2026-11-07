#!/bin/bash
# Install, or update, the shared BuildStream cache on the build host
# (README.md): Buildbarn's bb_storage and bb_remote_asset as system services,
# their data on the host's USB disk, and BuildStream there set to use them.
#
#   tools/cache-server/install.sh
#   BUNIX_BUILD_HOST=otherbox tools/cache-server/install.sh
#
# Needs sudo on the host.  Running it again replaces the binaries, the
# configuration and the units, and keeps the cached data, unless the store's
# size changed (storage.jsonnet): then it starts empty.  It refuses to run
# while bst builds on the host, since it restarts the cache under it.
set -euo pipefail
cd "$(dirname "$0")"
HOST=${BUNIX_BUILD_HOST:-pro13.home.arpa}

# Pinned releases, with the checksums their release pages publish.  These are
# the last ones before Buildbarn's content-defined chunking (Nov 2026), whose
# storage format BuildStream has not been tested with.
STORAGE_URL=https://github.com/buildbarn/bb-storage/releases/download/20261023T030055Z-a00415f/bb_storage.linux_amd64
STORAGE_SHA256=c59e1d9778fa963076c1fc6976bab9a4fdafd4c54c85b894f2fde23edf72e046
ASSET_URL=https://github.com/buildbarn/bb-remote-asset/releases/download/20261029T132537Z-678eaf4/bb_remote_asset.linux_amd64
ASSET_SHA256=1c42b1e2c0246b72410bb5b0764fe7363a2ca6de1c7ba4e256ef7108c5b69c40

# The stores' sizes, from the one place they are set: each .jsonnet file's
# `local blocksBytes = ...;` line
blocks_bytes() { echo $(( $(sed -n 's/^local blocksBytes = \(.*\);$/\1/p' "$1") )); }
STORE_BYTES=$(blocks_bytes storage.jsonnet)
ASSET_BYTES=$(blocks_bytes asset.jsonnet)

# ([b]: the pattern must not match the shell running this check)
if ssh "$HOST" 'pgrep -f "[b]in/bst " > /dev/null'; then
  echo "bst is running on $HOST; run this when it is idle" >&2
  exit 1
fi

STAGING=.cache/bst-cache-install   # in the host user's home
ssh "$HOST" "rm -rf $STAGING && mkdir -p $STAGING"
scp -q storage.jsonnet asset.jsonnet access.libsonnet bb-storage.service bb-remote-asset.service buildstream.conf \
  "$HOST:$STAGING/"

ssh "$HOST" bash -s -- "$STAGING" "$STORE_BYTES" "$ASSET_BYTES" \
  "$STORAGE_URL" "$STORAGE_SHA256" "$ASSET_URL" "$ASSET_SHA256" <<'EOF'
set -euo pipefail
staging=$1 store_bytes=$2 asset_bytes=$3
storage_url=$4 storage_sha256=$5 asset_url=$6 asset_sha256=$7
data=/srv/ci/bst-cache
cd ~/"$staging"

fetch() {   # url sha256 name
  curl -fsSL -A bunix-build -o "$3" "$1"
  echo "$2  $3" | sha256sum --check --quiet
  sudo install -m 755 "$3" /usr/local/bin/"$3"
}
fetch "$storage_url" "$storage_sha256" bb_storage
fetch "$asset_url" "$asset_sha256" bb_remote_asset

getent passwd bst-cache > /dev/null ||
  sudo useradd --system --no-create-home --home-dir "$data" --shell "$(command -v nologin)" bst-cache

# A store whose size changed cannot be read back: then the cache starts
# empty, the index of what was in it too
store=$data/cas/blocks
asset=$data/asset/blocks
size_of() { if sudo test -f "$1"; then sudo stat -c %s "$1"; else echo none; fi; }
store_now=$(size_of "$store")
asset_now=$(size_of "$asset")
size_changed=no
if [ "$store_now" != none ] && [ "$store_now" != "$store_bytes" ]; then size_changed=yes; fi
if [ "$asset_now" != none ] && [ "$asset_now" != "$asset_bytes" ]; then size_changed=yes; fi

# Room for the store, checked before anything is stopped or wiped: what is
# free, plus what a wiped store gives back
sudo mkdir -p "$data"
free_bytes=$(df --output=avail -B1 "$data" | tail -n 1)
needed_bytes=$store_bytes
if [ "$store_now" != none ] && [ $size_changed = no ]; then needed_bytes=0; fi
if [ "$store_now" != none ] && [ $size_changed = yes ]; then
  free_bytes=$((free_bytes + $(sudo du -B1 -s "$store" | cut -f1)))
fi
if [ "$free_bytes" -lt "$needed_bytes" ]; then
  echo "not enough room in $data for the store ($needed_bytes bytes): nothing changed" >&2
  exit 1
fi

sudo systemctl stop bb-remote-asset.service bb-storage.service 2> /dev/null || true
if [ $size_changed = yes ]; then
  echo "the store's size changed: starting the cache empty"
  sudo rm -rf "$data/cas" "$data/asset"
fi
sudo install -d -o bst-cache -g bst-cache "$data" \
  "$data/cas" "$data/cas/state" "$data/asset" "$data/asset/state"
sudo -u bst-cache fallocate -l "$store_bytes" "$store"

sudo install -d /etc/bst-cache
sudo install -m 644 storage.jsonnet asset.jsonnet access.libsonnet /etc/bst-cache/
sudo install -m 644 bb-storage.service bb-remote-asset.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable bb-storage.service bb-remote-asset.service
sudo systemctl start bb-storage.service bb-remote-asset.service

install -D -m 644 buildstream.conf ~/.config/buildstream.conf
cd ~ && rm -rf "$staging"
systemctl --no-pager --lines=0 status bb-storage.service bb-remote-asset.service
EOF
