#!/bin/bash
# Run bst on the Fly.io build machine (tools/fly/README.md): start the
# machine, reach it through `flyctl proxy`, run tools/bst-remote.sh there.
#
#   tools/bst-fly.sh build base/chromium.bst
#   tools/bst-fly.sh ssh                       # a shell on the machine
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

# No keys: nothing built here is signed (releases are made on pro13)
BUNIX_BUILD_HOST=root@localhost BUNIX_BUILD_SSH_OPTS="$SSH_OPTS" BUNIX_BUILD_KEYS=no \
  tools/bst-remote.sh "$@"
