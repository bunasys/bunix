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
# 30 idle minutes (tools/fly/start.sh).  Run again after a failure in step
# 4: a finished build is in the machine's store, and is only copied.
set -euo pipefail
cd "$(dirname "$0")/.."

APP=${BUNIX_FLY_APP:-bunix-build}
PORT=${BUNIX_FLY_PORT:-2222}
X86=${BUNIX_X86_BUILDER:-enas-asus.home.arpa}
# accept-new: the first machine's host key is learnt once.  A machine made
# again on a new volume has a new key, which ssh refuses until the old one
# is forgotten (README.md, "Making it": ssh-keygen -R bunix-fly).
FLY_SSH="ssh -p $PORT -o HostKeyAlias=bunix-fly -o StrictHostKeyChecking=accept-new -o ServerAliveInterval=60 root@localhost"
# Nix on each side: on the x86 builder as tools/nix-builder/home-store/
# nix.conf sets it up; on the machine, the same static nix on the volume
X86_NIX='export NIX_CONF_DIR=$HOME/nix-tool PATH=$HOME/nix-tool/bin:$PATH'
FLY_NIX='export NIX_CONF_DIR=/data/nix-tool PATH=/data/nix-tool/bin:$PATH'

work=$(mktemp -d)
proxy_pid=
clean_up() {
    [ -z "$proxy_pid" ] || kill $proxy_pid 2> /dev/null || true
    rm -rf "$work"
}
trap clean_up EXIT

# ---- The machine ---------------------------------------------------------------

start_machine() {
    local machine state
    read -r machine state < <(flyctl machine list --app "$APP" --json | python3 -c '
import json, sys
machines = json.load(sys.stdin)
if not machines:
    sys.exit("the Fly app has no machine (tools/fly/README.md, \"Making it\")")
print(machines[0]["id"], machines[0]["state"])')
    if [ "$state" != started ]; then
        flyctl machine start "$machine" --app "$APP" > /dev/null
    fi
}

start_proxy() {
    [ -z "$proxy_pid" ] || kill $proxy_pid 2> /dev/null || true
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

start_machine
start_proxy

if [ "${1:-}" = ssh ]; then
    shift
    $FLY_SSH "$@"
    exit
fi
if [ $# -ne 2 ]; then
    echo "usage: tools/nix-fly.sh FILE.nix ATTRIBUTE, or tools/nix-fly.sh ssh" >&2
    exit 2
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
$FLY_SSH 'cat > /data/nix-tool/nix.conf' < tools/fly/nix.conf
# The directories nix.conf names on the volume.  Made here rather than by
# the image's start.sh, so that a change to them needs no new image.
$FLY_SSH 'mkdir -p /data/ccache /data/build-dirs'

# The repository as it is here, committed or not, as on the x86 builder:
# what git has of it and is still there, and what is new and not ignored.
# Not BuildStream's elements, nor Shields' Rust build output from a Mac
# (as tools/test-machine.sh sends it).
copy_repository() {
    local host_command=$1 destination=$2
    git ls-files --cached --others --exclude-standard |
        grep -v -E '^(elements/|files/hudhud/shields/target/)' |
        while IFS= read -r path; do
            if [ -e "$path" ] || [ -L "$path" ]; then echo "$path"; fi
        done > "$work/repository-files"
    COPYFILE_DISABLE=1 tar --no-xattrs -T "$work/repository-files" -cf - |
        $host_command "rm -rf $destination && mkdir -p $destination && tar -xf - -C $destination"
}
copy_repository "$FLY_SSH" /data/bunix
copy_repository "ssh $X86" bunix-test/fly

# ---- Store paths, from one store to another ----------------------------------

# Copies the store paths on stdin, a closure in -qR's order (dependencies
# first, which an import needs), that the source has and the destination
# lacks.  Each side is a command that runs a shell command there.
copy_store_paths() {
    local from=$1 to=$2 from_nix=$3 to_nix=$4 what=$5
    cat > "$work/paths"
    $from "$from_nix && nix-store --check-validity --print-invalid \$(cat)" < "$work/paths" > "$work/source-lacks"
    grep -v -x -F -f "$work/source-lacks" "$work/paths" > "$work/source-has" || true
    $to "$to_nix && nix-store --check-validity --print-invalid \$(cat)" < "$work/source-has" > "$work/destination-lacks"
    grep -x -F -f "$work/destination-lacks" "$work/source-has" > "$work/copy" || true
    echo "Copying $(wc -l < "$work/copy") store paths $what"
    if [ -s "$work/copy" ]; then
        $from "$from_nix && nix-store --export \$(cat)" < "$work/copy" |
            $to -C "$to_nix && nix-store --import > /dev/null"
    fi
}

# What the package is built from, as the x86 builder evaluates it; and the
# builds' /bin/sh (tools/fly/nix.conf), which no derivation names
derivation=$(ssh "$X86" "$X86_NIX && cd bunix-test/fly && nix-instantiate $file -A $attribute")
if [ -z "$derivation" ]; then
    echo "$file has no $attribute" >&2
    exit 1
fi
sh=$(ssh "$X86" "$X86_NIX && cd bunix-test/fly && nix-store -q --outputs \$(nix-instantiate nix/bootstrap/sh.nix)")
{
    ssh "$X86" "$X86_NIX && nix-store -qR $sh"
    ssh "$X86" "$X86_NIX && nix-store -qR --include-outputs $derivation"
} | copy_store_paths "ssh $X86" "$FLY_SSH" "$X86_NIX" "$FLY_NIX" "to the machine"

# ---- The build, detached ----------------------------------------------------------

# A build started before runs on when the session that started it is gone
# (stopped here, or this Mac asleep): it is stopped first, whole, rather
# than racing this one for the machine and the log; and its build
# directory, tens of GB for Chromium, with it.
$FLY_SSH 'if pgrep -x nix-build > /dev/null; then
    echo "Stopping the build left running on the machine"
    for pid in $(pgrep -x nix-build); do kill -9 -- -$(ps -o sid= -p $pid | tr -d " ") 2> /dev/null || true; done
    sleep 5
    rm -rf /data/build-dirs/*
fi'

echo "Building $attribute on the machine (log: /data/builds/$name.log)"
$FLY_SSH "mkdir -p /data/builds && rm -f /data/builds/$name.log /data/builds/$name.exit /data/builds/$name.out
  cd /data/bunix && $FLY_NIX && setsid nohup bash -c 'nix-build $file -A $attribute --no-out-link > /data/builds/$name.out 2> /data/builds/$name.log; echo \$? > /data/builds/$name.exit' < /dev/null > /dev/null 2>&1 &"

# Waits, through dropped connections (this Mac asleep, the proxy gone) and
# a machine that stopped meanwhile (idle after the build, or stopped by
# Fly): it is started again, and its volume still has the build's end.
build_state() {
    $FLY_SSH -o ConnectTimeout=20 "if [ -f /data/builds/$name.exit ]; then echo finished
        elif pgrep -x nix-build > /dev/null; then echo running
        else echo gone; fi" 2> /dev/null || echo unreachable
}
while true; do
    sleep 300
    state=$(build_state)
    case $state in
        finished) break ;;
        running) ;;
        gone)
            echo "the build stopped without finishing (the machine restarted?); run again" >&2
            exit 1 ;;
        unreachable)
            start_machine || true
            start_proxy || true ;;
    esac
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

$FLY_SSH "$FLY_NIX && nix-store -qR $result" |
    copy_store_paths "$FLY_SSH" "ssh $X86" "$FLY_NIX" "$X86_NIX" "back to the x86 builder"
echo "$result is in the x86 builder's store"
