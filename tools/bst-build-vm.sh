#!/bin/bash
# Run bst in the build VM on the testbed (tools/build-vm/README.md),
# reached through the testbed over SSH.
#
#   tools/bst-build-vm.sh build system/uki.bst
#   tools/bst-build-vm.sh artifact push --deps all system/uki.bst   # into the shared cache
#   tools/bst-build-vm.sh ssh                    # a shell in the VM
#
# The VM gets the shared cache on pro13 as the Fly machine does
# (tools/bst-fly.sh, whose cache tunnel this repeats): pull-only, except
# for `artifact push`, so nothing built there enters the cache releases
# are made from until it is pushed.
set -euo pipefail
cd "$(dirname "$0")/.."

TESTBED=${BUNIX_TESTBED:-root@192.168.88.68}
VM=root@172.16.0.250
SSH_OPTS="-J $TESTBED -o HostKeyAlias=bunix-build-vm"

if [ "${1:-}" = ssh ]; then
  shift
  ssh $SSH_OPTS $VM "$@"
  exit
fi

CACHE_HOST=${BUNIX_CACHE_HOST:-pro13.home.arpa}
push=false
cache_index=7983 cache_storage=7984
if [ "${1:-} ${2:-}" = "artifact push" ]; then
  push=true
  cache_index=7981 cache_storage=7982
fi

port_in_use() { nc -z 127.0.0.1 "$1" 2> /dev/null; }
index_port=18981
while port_in_use $index_port || port_in_use $((index_port + 1)); do
  index_port=$((index_port + 2))
done
storage_port=$((index_port + 1))
ssh -N -o ExitOnForwardFailure=yes -o BatchMode=yes -o ConnectTimeout=5 \
  -o ServerAliveInterval=30 \
  -L $index_port:127.0.0.1:$cache_index -L $storage_port:127.0.0.1:$cache_storage "$CACHE_HOST" 2> /dev/null &
cache_tunnel=$!
trap 'kill $cache_tunnel 2> /dev/null || true' EXIT
for _ in $(seq 1 10); do
  if port_in_use $index_port || ! kill -0 $cache_tunnel 2> /dev/null; then break; fi
  sleep 1
done

CACHE_TUNNEL_SSH_OPTS=""
if port_in_use $index_port; then
  CACHE_TUNNEL_SSH_OPTS="-o ExitOnForwardFailure=yes -R 7981:127.0.0.1:$index_port -R 7982:127.0.0.1:$storage_port"
  ssh $SSH_OPTS $VM 'mkdir -p ~/.config && cat > ~/.config/buildstream.conf' <<EOF
artifacts:
  servers:
  - url: http://127.0.0.1:7981
    type: index
    push: $push
  - url: http://127.0.0.1:7982
    type: storage
    push: $push
EOF
elif [ $push = true ]; then
  echo "cannot push: the shared cache on $CACHE_HOST is not reachable" >&2
  exit 1
else
  echo "the shared cache on $CACHE_HOST is not reachable: using the VM's own cache only" >&2
  ssh $SSH_OPTS $VM 'rm -f ~/.config/buildstream.conf'
fi

# No keys: nothing built there is signed (releases are made on pro13)
BUNIX_BUILD_HOST=$VM BUNIX_BUILD_SSH_OPTS="$SSH_OPTS" BUNIX_BUILD_KEYS=no \
  BUNIX_BUILD_BST_SSH_OPTS="$CACHE_TUNNEL_SSH_OPTS" tools/bst-remote.sh "$@"
