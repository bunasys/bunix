#!/bin/bash
# Run bst on the Fly.io build machine (tools/fly/README.md): start the
# machine, reach it through `flyctl proxy`, run tools/bst-remote.sh there.
#
#   tools/bst-fly.sh build base/chromium.bst
#   tools/bst-fly.sh artifact push --deps all base/buna-browser.bst   # into the shared cache
#   tools/bst-fly.sh ssh                       # a shell on the machine
#   BUNIX_CACHE_HOST=otherbox tools/bst-fly.sh ...   # the shared cache's host
#
# The machine stops itself after 30 idle minutes (tools/fly/start.sh); it
# is not stopped here, so commands run one after another reuse it.
set -euo pipefail
cd "$(dirname "$0")/.."

APP=${BUNIX_FLY_APP:-bunix-build}
PORT=${BUNIX_FLY_PORT:-2222}
SSH_OPTS="-p $PORT -o HostKeyAlias=bunix-fly"

# The app has one machine: its id and state ("started", "stopped", ...)
read -r machine state < <(flyctl machine list --app "$APP" --json | python3 -c '
import json, sys
machines = json.load(sys.stdin)
if not machines:
    sys.exit("the Fly app has no machine (tools/fly/README.md, \"Making it again\")")
print(machines[0]["id"], machines[0]["state"])')
if [ "$state" != started ]; then
  flyctl machine start "$machine" --app "$APP" > /dev/null
fi

# The proxy carries SSH over Fly's private network: the machine has no
# public address.  Our sshd is on 2022 (22 is Fly's own SSH server).
flyctl proxy "$PORT:2022" --app "$APP" > /dev/null 2>&1 &
# Everything started in the background ends with this script.  (|| true:
# under set -e a failing kill would become the exit status, and the proxy is
# gone already when another one holds the port)
background_pids=$!
trap 'kill $background_pids 2> /dev/null || true' EXIT
reachable=no
for _ in $(seq 1 30); do
  if ssh $SSH_OPTS -o BatchMode=yes -o ConnectTimeout=5 root@localhost true 2> /dev/null; then
    reachable=yes
    break
  fi
  sleep 2
done
if [ $reachable = no ]; then
  echo "the Fly machine does not answer on localhost:$PORT" >&2
  exit 1
fi

if [ "${1:-}" = ssh ]; then
  shift
  ssh $SSH_OPTS root@localhost "$@"
  exit
fi

# The shared cache on the build host (tools/cache-server/README.md).  This
# run forwards two of its ports from there to this Mac, on a pair of free
# local ports, and the ssh session that runs bst forwards them on to the
# machine, to 7981 and 7982 there.  When this Mac cannot reach the build host,
# bst uses only the machine's own cache.
#
# The machine gets the cache's pull-only ports, except for `tools/bst-fly.sh
# artifact push ...`: what it builds enters the cache that releases are made
# from only when we push it, whatever is done on the machine, and a tunnel
# lost during a long build (this Mac asleep) cannot stop the build with a
# failed push.
CACHE_HOST=${BUNIX_CACHE_HOST:-pro13.home.arpa}
push=false
cache_index=7983 cache_storage=7984
if [ "${1:-} ${2:-}" = "artifact push" ]; then
  push=true
  cache_index=7981 cache_storage=7982
fi

port_in_use() { nc -z 127.0.0.1 "$1" 2> /dev/null; }
index_port=17981
while port_in_use $index_port || port_in_use $((index_port + 1)); do
  index_port=$((index_port + 2))
done
storage_port=$((index_port + 1))
ssh -N -o ExitOnForwardFailure=yes -o BatchMode=yes -o ConnectTimeout=5 \
  -o ServerAliveInterval=30 \
  -L $index_port:127.0.0.1:$cache_index -L $storage_port:127.0.0.1:$cache_storage "$CACHE_HOST" 2> /dev/null &
cache_tunnel=$!
background_pids="$background_pids $cache_tunnel"
for _ in $(seq 1 10); do
  if port_in_use $index_port || ! kill -0 $cache_tunnel 2> /dev/null; then break; fi
  sleep 1
done

CACHE_TUNNEL_SSH_OPTS=""
if port_in_use $index_port; then
  # A forward left by a session that died is still held for a few minutes
  # by sshd: fail then, rather than talk to it
  CACHE_TUNNEL_SSH_OPTS="-o ExitOnForwardFailure=yes -R 7981:127.0.0.1:$index_port -R 7982:127.0.0.1:$storage_port"
  # The same servers as the build host's tools/cache-server/buildstream.conf,
  # with push set for this run
  ssh $SSH_OPTS root@localhost 'mkdir -p ~/.config && cat > ~/.config/buildstream.conf' <<EOF
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
  echo "the shared cache on $CACHE_HOST is not reachable: using the machine's own cache only" >&2
  ssh $SSH_OPTS root@localhost 'rm -f ~/.config/buildstream.conf'
fi

# No keys: nothing built here is signed (releases are made on pro13)
BUNIX_BUILD_HOST=root@localhost BUNIX_BUILD_SSH_OPTS="$SSH_OPTS" BUNIX_BUILD_KEYS=no \
  BUNIX_BUILD_BST_SSH_OPTS="$CACHE_TUNNEL_SSH_OPTS" tools/bst-remote.sh "$@"
