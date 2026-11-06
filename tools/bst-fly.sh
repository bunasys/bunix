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
proxy=$!
# (|| true: under set -e a failing kill would become the exit status, and
# the proxy is gone already when another one holds the port)
trap 'kill $proxy 2> /dev/null || true' EXIT
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
# Mac forwards its two ports from there, on 17981 and 17982 here (so a tunnel
# made by hand on 7981 does not clash), and the ssh sessions to the machine
# forward them on, back to 7981 and 7982 there.  When this Mac cannot reach
# the build host, bst uses only the machine's own cache.
#
# The machine only pulls, except for `tools/bst-fly.sh artifact push`: what
# it builds enters the cache that releases are made from only when we push
# it, and a tunnel lost during a long build (this Mac asleep) cannot stop the
# build with a failed push.
CACHE_HOST=${BUNIX_CACHE_HOST:-pro13.home.arpa}
cache_reachable() { nc -z 127.0.0.1 17981 2> /dev/null; }
if ! cache_reachable; then
  # (a tunnel already open, from another run, is reused)
  ssh -N -o ExitOnForwardFailure=yes -o BatchMode=yes -o ConnectTimeout=5 \
    -o ServerAliveInterval=30 \
    -L 17981:127.0.0.1:7981 -L 17982:127.0.0.1:7982 "$CACHE_HOST" 2> /dev/null &
  cache_tunnel=$!
  # (replaces the trap above: both background processes end with this script)
  trap 'kill $proxy $cache_tunnel 2> /dev/null || true' EXIT
  for _ in $(seq 1 10); do
    if cache_reachable || ! kill -0 $cache_tunnel 2> /dev/null; then break; fi
    sleep 1
  done
fi

is_push=no
if [ "${1:-} ${2:-}" = "artifact push" ]; then is_push=yes; fi
CACHE_OPTS=""
if cache_reachable; then
  # A forward left by a session that died is still held for a few minutes
  # by sshd; fail then, rather than talk to it
  CACHE_OPTS="-o ExitOnForwardFailure=yes -R 7981:127.0.0.1:17981 -R 7982:127.0.0.1:17982"
  push=false
  if [ $is_push = yes ]; then push=true; fi
  sed "s/push: true/push: $push/" tools/cache-server/buildstream.conf |
    ssh $SSH_OPTS root@localhost 'mkdir -p ~/.config && cat > ~/.config/buildstream.conf'
else
  echo "the shared cache on $CACHE_HOST is not reachable: using the machine's own cache only" >&2
  ssh $SSH_OPTS root@localhost 'rm -f ~/.config/buildstream.conf'
fi

# No keys: nothing built here is signed (releases are made on pro13)
BUNIX_BUILD_HOST=root@localhost BUNIX_BUILD_SSH_OPTS="$SSH_OPTS $CACHE_OPTS" BUNIX_BUILD_KEYS=no \
  tools/bst-remote.sh "$@"
