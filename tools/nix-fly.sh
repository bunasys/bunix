#!/bin/bash
# Builds one Nix package for x86-64 on the Fly.io build machine
# (tools/fly/README.md), for a package too large for the x86 builder
# (Chromium: docs/browser.md):
#
#   tools/nix-fly.sh nix/browser.nix chromium
#   tools/nix-fly.sh ssh                       # a shell on the machine
#
# 1. starts the machine and reaches it through `flyctl proxy`;
# 2. copies the package's inputs from the x86 builder's store, those the
#    machine does not have yet (through this Mac: the two cannot reach
#    each other);
# 3. builds it there, detached from this connection (log: /data/builds/);
# 4. copies the result back into the x86 builder's store.
#
# Whatever the machine cannot get from the x86 builder (a source not
# downloaded there yet), it builds itself.  The machine stops itself after
# 30 idle minutes (tools/fly/start.sh).
set -euo pipefail
cd "$(dirname "$0")/.."

APP=${BUNIX_FLY_APP:-bunix-build}
PORT=${BUNIX_FLY_PORT:-2222}
X86=${BUNIX_X86_BUILDER:-enas-asus.home.arpa}
# accept-new: a machine made again has a new host key, which is learnt
# once; a changed key for a known machine is still refused
FLY_SSH="ssh -p $PORT -o HostKeyAlias=bunix-fly -o StrictHostKeyChecking=accept-new -o ServerAliveInterval=60 root@localhost"
# Nix on each side: on the x86 builder as tools/nix-builder/home-store/
# nix.conf sets it up; on the machine, the same static nix on the volume
X86_NIX='export NIX_CONF_DIR=$HOME/nix-tool PATH=$HOME/nix-tool/bin:$PATH'
FLY_NIX='export NIX_CONF_DIR=/data/nix-tool PATH=/data/nix-tool/bin:$PATH'

# ---- The machine ---------------------------------------------------------------

read -r machine state < <(flyctl machine list --app "$APP" --json | python3 -c '
import json, sys
machines = json.load(sys.stdin)
if not machines:
    sys.exit("the Fly app has no machine (tools/fly/README.md, \"Making it\")")
print(machines[0]["id"], machines[0]["state"])')
if [ "$state" != started ]; then
  flyctl machine start "$machine" --app "$APP" > /dev/null
fi

proxy_pid=
start_proxy() {
  # the machine has no public address: SSH goes over Fly's private
  # network, to our sshd on 2022 (22 is Fly's own SSH server)
  flyctl proxy "$PORT:2022" --app "$APP" > /dev/null 2>&1 &
  proxy_pid=$!
  for _ in $(seq 1 30); do
    if $FLY_SSH -o BatchMode=yes -o ConnectTimeout=5 true 2> /dev/null; then
      return 0
    fi
    sleep 2
  done
  echo "the Fly machine does not answer on localhost:$PORT" >&2
  return 1
}
stop_proxy() { [ -z "$proxy_pid" ] || kill $proxy_pid 2> /dev/null || true; }
trap stop_proxy EXIT
start_proxy

if [ "${1:-}" = ssh ]; then
  shift
  $FLY_SSH "$@"
  exit
fi
file=$1
attribute=$2
name=$(basename "$file" .nix)-$attribute

# ---- Nix on the machine, and the repository ---------------------------------

# The static nix, from the x86 builder, once
if ! $FLY_SSH test -x /data/nix-tool/nix; then
  echo "Copying the static nix to the machine"
  $FLY_SSH 'mkdir -p /data/nix-tool/bin /data/nix-root'
  ssh "$X86" cat nix-tool/nix | $FLY_SSH 'cat > /data/nix-tool/nix && chmod 755 /data/nix-tool/nix'
  $FLY_SSH 'cd /data/nix-tool/bin && for tool in nix-build nix-store nix-instantiate nix-hash; do ln -sf ../nix $tool; done'
fi
$FLY_SSH 'cat > /data/nix-tool/nix.conf && mkdir -p /data/ccache' < tools/fly/nix.conf

# The repository as it is here, committed or not, as on the x86 builder
copy_repository() {
  local host_command=$1 destination=$2
  git ls-files --cached --others --exclude-standard |
    grep -v -E '^(elements/|files/hudhud/shields/target/)' |
    COPYFILE_DISABLE=1 tar --no-xattrs -T - -cf - |
    $host_command "rm -rf $destination && mkdir -p $destination && tar -xf - -C $destination"
}
copy_repository "$FLY_SSH" /data/bunix
copy_repository "ssh $X86" bunix-test/fly

# ---- The inputs: from the x86 builder's store ----------------------------------

# What the package is built from, and what of it the x86 builder has
# (dependencies before what needs them, as -qR lists them)
derivation=$(ssh "$X86" "$X86_NIX && cd bunix-test/fly && nix-instantiate $file -A $attribute 2> /dev/null")
ssh "$X86" "$X86_NIX && nix-store -qR --include-outputs $derivation" > /tmp/nix-fly-inputs.$$
ssh "$X86" "$X86_NIX && nix-store --check-validity --print-invalid \$(cat)" < /tmp/nix-fly-inputs.$$ > /tmp/nix-fly-absent.$$ || true
# ... and what of that the machine does not have
grep -v -x -F -f /tmp/nix-fly-absent.$$ /tmp/nix-fly-inputs.$$ > /tmp/nix-fly-present.$$ || true
$FLY_SSH "$FLY_NIX && nix-store --check-validity --print-invalid \$(cat)" < /tmp/nix-fly-present.$$ > /tmp/nix-fly-missing.$$ || true
# in -qR's order again, which an import needs
grep -x -F -f /tmp/nix-fly-missing.$$ /tmp/nix-fly-present.$$ > /tmp/nix-fly-copy.$$ || true
echo "Copying $(wc -l < /tmp/nix-fly-copy.$$) store paths to the machine"
if [ -s /tmp/nix-fly-copy.$$ ]; then
  ssh "$X86" "$X86_NIX && nix-store --export \$(cat)" < /tmp/nix-fly-copy.$$ |
    $FLY_SSH -C "$FLY_NIX && nix-store --import > /dev/null"
fi
rm -f /tmp/nix-fly-*.$$

# ---- The build, detached ----------------------------------------------------------

# A build started before runs on when the session that started it is gone
# (stopped here, or this Mac asleep): it is stopped first, whole, rather
# than racing this one for the machine and the log.
$FLY_SSH 'for pid in $(pgrep -x nix-build); do kill -9 -- -$(ps -o sid= -p $pid | tr -d " ") 2> /dev/null || true; done'

echo "Building $attribute on the machine (log: /data/builds/$name.log)"
$FLY_SSH "mkdir -p /data/builds && rm -f /data/builds/$name.log /data/builds/$name.exit /data/builds/$name.out
  cd /data/bunix && $FLY_NIX && setsid nohup bash -c 'nix-build $file -A $attribute --no-out-link > /data/builds/$name.out 2> /data/builds/$name.log; echo \$? > /data/builds/$name.exit' < /dev/null > /dev/null 2>&1 &"

# Waits, through dropped connections (this Mac asleep, the proxy gone)
until $FLY_SSH -o ConnectTimeout=20 test -f /data/builds/$name.exit 2> /dev/null; do
  sleep 300
  if ! kill -0 "$proxy_pid" 2> /dev/null; then start_proxy || true; fi
done
status=$($FLY_SSH cat /data/builds/$name.exit)
if [ "$status" != 0 ]; then
  echo "the build failed ($status); its log's end:" >&2
  $FLY_SSH tail -40 /data/builds/$name.log >&2
  exit 1
fi
result=$($FLY_SSH cat /data/builds/$name.out)
echo "Built: $result"

# ---- The result: into the x86 builder's store ---------------------------------

$FLY_SSH "$FLY_NIX && nix-store -qR $result" > /tmp/nix-fly-result.$$
ssh "$X86" "$X86_NIX && nix-store --check-validity --print-invalid \$(cat)" < /tmp/nix-fly-result.$$ > /tmp/nix-fly-missing.$$ || true
grep -x -F -f /tmp/nix-fly-missing.$$ /tmp/nix-fly-result.$$ > /tmp/nix-fly-copy.$$ || true
echo "Copying $(wc -l < /tmp/nix-fly-copy.$$) store paths back to the x86 builder"
if [ -s /tmp/nix-fly-copy.$$ ]; then
  $FLY_SSH -C "$FLY_NIX && nix-store --export \$(cat)" < /tmp/nix-fly-copy.$$ |
    ssh "$X86" "$X86_NIX && nix-store --import > /dev/null"
fi
rm -f /tmp/nix-fly-*.$$
echo "$result is in the x86 builder's store"
