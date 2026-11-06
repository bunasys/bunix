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
#
# A build machine that must not get the signing keys (the test machine, which
# builds packages and passes them on with tools/cache-sync.sh):
#
#   BUNIX_BUILD_HOST=root@192.168.88.68 BUNIX_BUILD_SSH_KEY=~/Projects/bunix/id_ed25519 \
#   BUNIX_BUILD_VENV=/opt/bst/venv BUNIX_BUILD_PATH=/opt/bst/bin:/usr/bin \
#   BUNIX_BUILD_KEYS=no tools/bst-remote.sh build base/mesa.bst
#
# The Fly.io build machine: tools/bst-fly.sh (tools/fly/README.md).
#
# BUNIX_BUILD_PATH: the whole PATH bst runs with, for a host whose
# bubblewrap is not in the SSH session's PATH.
set -euo pipefail
cd "$(dirname "$0")/.."

HOST=${BUNIX_BUILD_HOST:-pro13.home.arpa}
BUILDERS=${BUNIX_BUILDERS:-2}   # parallel element builds; gcc at -j8 needs a few GB each
# The jobs each build runs (make -j, project.conf's MAKEFLAGS), the same on
# every host: they are part of every cache key, and equal keys are what lets
# tools/cache-sync.sh share one host's packages with another.
MAX_JOBS=8
VENV=${BUNIX_BUILD_VENV:-'~/.local/share/bunix-bst'}
SSH=(ssh)
if [ -n "${BUNIX_BUILD_SSH_KEY:-}" ]; then
  SSH=(ssh -i "$BUNIX_BUILD_SSH_KEY")
fi
# BUNIX_BUILD_SSH_OPTS: more ssh options, split on spaces (tools/bst-fly.sh
# passes a port and a host key alias)
if [ -n "${BUNIX_BUILD_SSH_OPTS:-}" ]; then
  SSH+=($BUNIX_BUILD_SSH_OPTS)
fi
RUN=""
if [ -n "${BUNIX_BUILD_PATH:-}" ]; then
  RUN="env PATH=$BUNIX_BUILD_PATH "
fi
# out/: release files and test images made here, which no build reads.
# .bst/: the host's own BuildStream state (its workspaces), kept there.
EXCLUDE=(--exclude '.stage*.log' --exclude /out --exclude /.bst)
if [ "${BUNIX_BUILD_KEYS:-yes}" = no ]; then
  # only elements that sign (system/uki.bst, the sysext images) read keys/
  EXCLUDE+=(--exclude /keys)
fi
# the same pinned versions as tools/bst-container.sh
PACKAGES='buildstream==2.8.1 buildstream-plugins==2.8.0 buildstream-plugins-community[git,cargo2,pypi]==2.4.0 requests'

"${SSH[@]}" "$HOST" "mkdir -p src && { [ -x $VENV/bin/bst ] || { python3 -m venv $VENV && $VENV/bin/pip install -q $PACKAGES; }; }"
# only the executable bit of the modes matters (and a symlink's mode cannot
# be set on Linux, which some rsync versions treat as an error)
rsync -rlt --executability --delete -e "${SSH[*]}" "${EXCLUDE[@]}" ./ "$HOST:src/bunix/"

status=0
"${SSH[@]}" "$HOST" "cd src/bunix && $RUN$VENV/bin/bst --builders $BUILDERS --max-jobs $MAX_JOBS $(printf '%q ' "$@")" || status=$?

# `bst source track` writes the refs it found into the element files on the
# host; bring them back.  --update keeps files edited here in the meantime.
rsync -rlt --update -e "${SSH[*]}" "$HOST:src/bunix/elements/" elements/
exit $status
