#!/bin/bash
# The build machine's main process: sshd, then a wait for the machine to go
# idle.  When this script exits, Fly stops the machine, and a stopped machine
# costs only its disk.
set -euo pipefail

# root's home is on the volume: the BuildStream cache (~/.cache/buildstream),
# the project copy (~/src/bunix) and the BuildStream virtualenv
# (~/.local/share/bunix-bst) survive restarts.
mkdir -p /data/root /data/ssh
mount --bind /data/root /root

# A host key made once and kept, so SSH knows the machine across restarts
if [ ! -f /data/ssh/ssh_host_ed25519_key ]; then
  ssh-keygen -q -t ed25519 -N '' -f /data/ssh/ssh_host_ed25519_key
fi
printf '%s\n' "$AUTHORIZED_KEYS" > /etc/ssh/authorized_keys
mkdir -p /run/sshd
/usr/sbin/sshd

# Idle: no SSH connection and no bst for IDLE_MINUTES in a row.  A build
# keeps the machine up even when the SSH session that started it is gone.
IDLE_MINUTES=${IDLE_MINUTES:-30}
idle=0
while [ $idle -lt $IDLE_MINUTES ]; do
  sleep 60
  ssh_sessions=$(ss -Htn state established '( sport = :2022 )' | wc -l)
  bst_running=no
  if pgrep -f 'bin/bst ' > /dev/null; then bst_running=yes; fi

  if [ "$ssh_sessions" -eq 0 ] && [ $bst_running = no ]; then
    idle=$((idle + 1))
  else
    idle=0
  fi
done
echo "idle for $IDLE_MINUTES minutes: stopping"
