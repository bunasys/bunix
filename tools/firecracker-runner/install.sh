#!/bin/bash
# Installs the runners on a bunix machine, as root, from a directory with
# this script, host/, and what build-guest.sh and register.sh made:
# vmlinux, rootfs.ext4, and one config-<n>.ext4 per registered runner, which
# becomes instance fc-runner@<n>.  Needs a kernel with KVM, tun and NAT and
# the devtools extension (firecracker).  /usr is the image's, so everything
# goes to /etc and /var/lib/fc-runner.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

install -D -m 0644 host/fc-runner.sysusers /etc/sysusers.d/fc-runner.conf
systemd-sysusers /etc/sysusers.d/fc-runner.conf

install -d -o fc-runner -g fc-runner -m 0750 /var/lib/fc-runner
install -d -m 0755 /var/lib/fc-runner/bin
install -m 0755 host/fc-runner-network host/fc-runner-loop /var/lib/fc-runner/bin/
install -o fc-runner -g fc-runner -m 0644 vmlinux /var/lib/fc-runner/
# (the image is sparse: a plain copy would write every empty block)
cp --sparse=always rootfs.ext4 /var/lib/fc-runner/rootfs.ext4
chown fc-runner:fc-runner /var/lib/fc-runner/rootfs.ext4

install -D -m 0644 host/fc-runner-forward.nft /etc/nftables.d/forward/fc-runner.nft
systemctl reload nftables
install -m 0644 host/fc-runner@.service /etc/systemd/system/
systemctl daemon-reload

for drive in config-*.ext4; do
  index=${drive#config-}
  index=${index%.ext4}
  install -d -o fc-runner -g fc-runner -m 0750 /var/lib/fc-runner/$index
  install -o fc-runner -g fc-runner -m 0600 "$drive" /var/lib/fc-runner/$index/config.ext4
  systemctl enable "fc-runner@$index.service"
  systemctl restart "fc-runner@$index.service"
done
systemctl --no-pager list-units 'fc-runner@*'
