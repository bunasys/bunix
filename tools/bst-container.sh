#!/bin/bash
# Create (once) and enter the container BuildStream runs in.
#
#   tools/bst-container.sh            create it if needed, then open a shell
#   tools/bst-container.sh bst ...    run a bst command inside it
#
# BuildStream needs Linux.  On Apple silicon this is an x86_64 Arch Linux
# container run through Rosetta, with the project mounted at /src/bunix.
# Two host-specific settings, both found the hard way:
#
#   * bubblewrap 0.12+ sets up mounts with the kernel's new mount API
#     (open_tree/move_mount), which Rosetta does not translate ("Function not
#     implemented"), so bubblewrap is pinned to 0.11.
#   * a sandbox can only mount a fresh /proc when the container's own /proc
#     has nothing masked over it: --read-only-path NONE --masked-path NONE.
set -euo pipefail
cd "$(dirname "$0")/.."

NAME=${NAME:-bunix-bst}
BST_VERSION=2.8.1
PLUGINS_VERSION=2.8.0
COMMUNITY_VERSION=2.4.0
BWRAP=https://archive.archlinux.org/packages/b/bubblewrap/bubblewrap-0.11.0-1-x86_64.pkg.tar.zst

exists() { container list --all --format json 2>/dev/null | grep -q "\"$NAME\""; }
running() { container list --format json 2>/dev/null | grep -q "\"$NAME\""; }

if ! exists; then
  container run -d --name "$NAME" --arch amd64 --rosetta --dns 1.1.1.1 \
    --cpus 8 --memory 12g --cap-add ALL \
    --read-only-path NONE --masked-path NONE \
    -v "$PWD/..:/src" --entrypoint /usr/bin/sleep \
    docker.io/library/archlinux:base-devel infinity >/dev/null
  container exec "$NAME" bash -c "
    set -e
    pacman -Syu --noconfirm --disable-sandbox
    pacman -S --noconfirm --needed --disable-sandbox python python-pip git lzip fuse3
    pacman -U --noconfirm --disable-sandbox $BWRAP
    sed -i 's/^#IgnorePkg *=.*/IgnorePkg = bubblewrap/' /etc/pacman.conf
    python -m venv /opt/bst
    /opt/bst/bin/pip install buildstream==$BST_VERSION buildstream-plugins==$PLUGINS_VERSION \
      'buildstream-plugins-community[git,cargo2,pypi]==$COMMUNITY_VERSION' requests
    ln -sf /opt/bst/bin/bst /usr/local/bin/bst
  "
elif ! running; then
  container start "$NAME" >/dev/null
fi

if [ $# -gt 0 ]; then
  exec container exec -it "$NAME" bash -c "cd /src/bunix && $(printf '%q ' "$@")"
fi
exec container exec -it "$NAME" bash -c "cd /src/bunix && exec bash"
