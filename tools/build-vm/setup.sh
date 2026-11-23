#!/bin/bash
# Makes the build VM on a bunix machine (README.md), as root: its disk, from
# the runners' Ubuntu image (tools/firecracker-runner), with what BuildStream
# needs and an SSH server added, and the unit that runs it.
#
#   ./setup.sh "$(cat ~/.ssh/id_ed25519.pub)"   # the key that may log in
#
# Needs the runners installed first (their image, kernel and network
# rules).  A disk that exists is kept, with the cache on it: rerunning only
# updates the unit and the VM's settings.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
authorized_key=$1

dir=/var/lib/fc-build
disk=$dir/disk.ext4
disk_size=70G

echo 'u fc-build - "Firecracker build VM" /var/lib/fc-build' > /etc/sysusers.d/fc-build.conf
systemd-sysusers /etc/sysusers.d/fc-build.conf
install -d -o fc-build -g fc-build -m 0700 $dir

if [ ! -f $disk ]; then
  new=$disk.new
  cp --sparse=always /var/lib/fc-runner/rootfs.ext4 $new
  truncate -s $disk_size $new
  e2fsck -fp $new
  resize2fs $new
  root=$(mktemp -d)
  mount -o loop $new "$root"
  # apt in the chroot needs the kernel's file systems
  for fs in proc sys dev dev/pts; do
    mount --bind /$fs "$root/$fs"
  done
  chroot "$root" /bin/bash -e <<'EOF'
export DEBIAN_FRONTEND=noninteractive
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
apt-get update
# BuildStream's sandbox (bubblewrap) and FUSE, a virtualenv for the pinned
# BuildStream (tools/bst-remote.sh), rsync for the project copy, sshd
# (the image's own sysctl.conf and others are kept: there is no one to ask)
apt-get install -y --no-install-recommends -o Dpkg::Options::=--force-confold \
  -o Dpkg::Options::=--force-confdef openssh-server bubblewrap fuse3 python3-venv rsync
apt-get clean
rm -rf /var/lib/apt/lists/*
# Not a runner: no job, and no reboot when there is none
systemctl disable actions-runner.service docker.service docker.socket
systemctl enable ssh.service
EOF
  for fs in dev/pts dev sys proc; do
    umount "$root/$fs"
  done
  install -d -m 0700 "$root/root/.ssh"
  printf '%s\n' "$authorized_key" > "$root/root/.ssh/authorized_keys"
  chmod 0600 "$root/root/.ssh/authorized_keys"
  # The VM's host key, for this machine's known_hosts (README.md)
  cp "$root/etc/ssh/ssh_host_ed25519_key.pub" $dir/host-key.pub
  umount "$root"
  rmdir "$root"
  chown fc-build:fc-build $new
  chmod 0600 $new
  mv $new $disk
fi

# Every CPU of the testbed (the runners' VMs share them), and memory enough
# for the kernel's and LLVM's links.  The MAC gives the VM 172.16.0.250
# (fc-build.service).
cat > $dir/vm.json <<JSON
{
  "boot-source": {
    "kernel_image_path": "/var/lib/fc-runner/vmlinux",
    "boot_args": "console=ttyS0 reboot=k panic=1 pci=off quiet"
  },
  "drives": [
    { "drive_id": "disk", "path_on_host": "$disk",
      "is_root_device": true, "is_read_only": false }
  ],
  "machine-config": { "vcpu_count": $(nproc), "mem_size_mib": 16384 },
  "network-interfaces": [
    { "iface_id": "eth0", "guest_mac": "06:00:AC:10:00:FA", "host_dev_name": "fc-tap62" }
  ]
}
JSON

install -m 0644 fc-build.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable fc-build.service
systemctl restart fc-build.service
echo "host key: $(cut -d' ' -f1,2 $dir/host-key.pub)"
