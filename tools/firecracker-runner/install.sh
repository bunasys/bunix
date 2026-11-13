#!/bin/bash
# Installs the runners on a bunix machine, or updates them, as root:
#
#   ./install.sh 1 2        # instances fc-runner@1 and fc-runner@2
#
# from a directory with this script, host/, and build-guest.sh's vmlinux
# and rootfs.ext4.  The GitHub App's settings and key go in /etc/fc-runner
# first (README.md).  Needs a kernel with KVM, tun and NAT, and the
# devtools extension (firecracker).  /usr is the image's, so everything goes
# to /etc and /var/lib/fc-runner.
#
# Rerunning it is how the runners are updated.  It restarts every instance,
# which ends the jobs they are running.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

if [ $# -eq 0 ]; then
  echo "usage: $0 <instance>..." >&2
  exit 2
fi
if [ ! -f /etc/fc-runner/github.conf ] || [ ! -f /etc/fc-runner/app.pem ]; then
  echo "install.sh: /etc/fc-runner/github.conf and app.pem first (README.md)" >&2
  exit 1
fi
chmod 0700 /etc/fc-runner
chmod 0600 /etc/fc-runner/github.conf /etc/fc-runner/app.pem

# A user per instance, for its Firecracker (fc-runner@.service)
for index in "$@"; do
  echo "u fc-runner-$index - \"Firecracker runner VM $index\" /var/lib/fc-runner/$index"
done > /etc/sysusers.d/fc-runner.conf
systemd-sysusers /etc/sysusers.d/fc-runner.conf

install -d -m 0755 /var/lib/fc-runner /var/lib/fc-runner/bin
install -m 0755 host/fc-runner-vm /var/lib/fc-runner/bin/
install -m 0644 host/fc-runner.nft vmlinux /var/lib/fc-runner/
# Renamed into place: a running instance may be copying the old one
cp --sparse=always rootfs.ext4 /var/lib/fc-runner/rootfs.ext4.new
chmod 0644 /var/lib/fc-runner/rootfs.ext4.new
mv /var/lib/fc-runner/rootfs.ext4.new /var/lib/fc-runner/rootfs.ext4

# /dev/net/tun exists only once tun is loaded: the image does not enable
# systemd-tmpfiles-setup-dev, which would create it for loading on demand
mkdir -p /etc/modules-load.d
echo tun > /etc/modules-load.d/fc-runner.conf
modprobe tun

install -D -m 0644 host/fc-runner-forward.nft /etc/nftables.d/forward/fc-runner.nft
systemctl reload nftables
install -m 0644 host/fc-runner-network.service host/fc-runner@.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now fc-runner-network.service
# The rules again, in case they changed: restarting the service would stop
# every instance with it
nft -f /var/lib/fc-runner/fc-runner.nft

for index in "$@"; do
  systemctl enable "fc-runner@$index.service"
  systemctl restart "fc-runner@$index.service"
done
systemctl --no-pager list-units 'fc-runner*'
