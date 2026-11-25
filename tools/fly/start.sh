#!/bin/bash
# The build machine's main process: sshd, then a wait for the machine to go
# idle.  When this script exits, Fly stops the machine, and a stopped machine
# costs only its volume.
set -euo pipefail

mkdir -p /data/ssh
# A host key made once and kept, so SSH knows the machine across restarts
if [ ! -f /data/ssh/ssh_host_ed25519_key ]; then
  ssh-keygen -q -t ed25519 -N '' -f /data/ssh/ssh_host_ed25519_key
fi
printf '%s\n' "$AUTHORIZED_KEYS" > /etc/ssh/authorized_keys
mkdir -p /run/sshd
/usr/sbin/sshd

# Idle: no SSH connection and no nix process for IDLE_MINUTES in a row.  A
# build keeps the machine up after the SSH session that started it is gone.
IDLE_MINUTES=${IDLE_MINUTES:-30}
idle=0
while [ $idle -lt $IDLE_MINUTES ]; do
  sleep 60
  ssh_sessions=$(ss -Htn state established '( sport = :2022 )' | wc -l)
  nix_running=no
  if pgrep -x nix-build > /dev/null || pgrep -x nix-store > /dev/null; then nix_running=yes; fi

  if [ "$ssh_sessions" -eq 0 ] && [ $nix_running = no ]; then
    idle=$((idle + 1))
  else
    idle=0
  fi
done
echo "idle for $IDLE_MINUTES minutes: stopping"
