#!/bin/bash
# Run BuildStream on a native x86_64 Linux machine over SSH, instead of in the
# Rosetta container on this Mac.
#
#   tools/bst-remote.sh build tests/toolchain.bst
#   tools/bst-remote.sh show bootstrap/toolchain.bst
#   tools/bst-remote.sh source track base/zlib.bst    # refs come back here
#   BUNIX_BUILD_HOST=otherbox tools/bst-remote.sh build ...
#
# Arguments are passed to `bst`.  The host needs python3, bubblewrap and FUSE
# (fusermount3); BuildStream is installed in a virtualenv in the user's home on
# first use.  The project is copied to ~/src/bunix there; the artifact cache
# stays on the host (~/.cache/buildstream), so later builds are incremental.
set -euo pipefail
cd "$(dirname "$0")/.."

HOST=${BUNIX_BUILD_HOST:-pro13.home.arpa}
BUILDERS=${BUNIX_BUILDERS:-2}   # parallel element builds; gcc at -j8 needs a few GB each
VENV='~/.local/share/bunix-bst'
# the same pinned versions as tools/bst-container.sh
PACKAGES='buildstream==2.8.1 buildstream-plugins==2.8.0 buildstream-plugins-community[git,cargo2,pypi]==2.4.0 requests'

ssh "$HOST" "mkdir -p src && { [ -x $VENV/bin/bst ] || { python3 -m venv $VENV && $VENV/bin/pip install -q $PACKAGES; }; }"
rsync -a --delete --exclude '.stage*.log' ./ "$HOST:src/bunix/"

status=0
ssh "$HOST" "cd src/bunix && $VENV/bin/bst --builders $BUILDERS $(printf '%q ' "$@")" || status=$?

# `bst source track` writes the refs it found into the element files on the
# host; bring them back.  --update keeps files edited here in the meantime.
rsync -a --update "$HOST:src/bunix/elements/" elements/
exit $status
