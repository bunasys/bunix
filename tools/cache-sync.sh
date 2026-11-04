#!/bin/bash
# Copy what the test machine built into the release build host's BuildStream
# cache, so the build host uses those packages instead of building them again
# (LLVM alone takes it 2.5 hours, with its CI VMs beside it).
#
#   tools/cache-sync.sh
#
# Why plain copying works: BuildStream's cache keys come only from the
# project (sources, element files, plugin versions), so the same project gives
# the same keys on both machines; and the cache is content-addressed, so a
# copied object can only be the same bytes as one already there.  Both sides
# must run the same BuildStream (tools/bst-remote.sh pins it), and no `bst`
# may be running on the build host while this runs.
#
# The test machine pushes straight to the build host, through this Mac's SSH
# agent (ssh -A): no key for the build host is stored on the test machine.
set -euo pipefail

TESTBED=${BUNIX_TESTBED:-root@192.168.88.68}
TESTBED_KEY=${BUNIX_TESTBED_KEY:-$HOME/Projects/bunix/id_ed25519}
BUILD_HOST=${BUNIX_BUILD_HOST:-khaled@pro13.home.arpa}

# ([b]: the pattern must not match the shell running this check)
if ssh "$BUILD_HOST" 'pgrep -f "[b]in/bst " > /dev/null'; then
  echo "bst is running on $BUILD_HOST; run this when it is idle" >&2
  exit 1
fi

# objects first, then the artifact entries that name them, so the build host
# never sees an artifact whose files are not there yet
# (accept-new: the test machine learns the build host's key on first use)
ssh -A -i "$TESTBED_KEY" "$TESTBED" "bash -c '
  cd ~/.cache/buildstream &&
  rsync -a --ignore-existing -e \"ssh -o StrictHostKeyChecking=accept-new\" cas/objects/ $BUILD_HOST:.cache/buildstream/cas/objects/ &&
  rsync -a --ignore-existing -e \"ssh -o StrictHostKeyChecking=accept-new\" artifacts/ $BUILD_HOST:.cache/buildstream/artifacts/'"
echo "synced"
