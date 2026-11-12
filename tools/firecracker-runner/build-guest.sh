#!/bin/bash
# Builds the runner VM's disk image, rootfs.ext4, in the current directory:
# Firecracker's CI image of Ubuntu 24.04 (the userland GitHub's own
# ubuntu-24.04 runners have) with the GitHub Actions runner, Docker and the
# usual build tools.  It holds no credentials: the registration reaches each VM
# on a separate drive (register.sh).  Also fetches the guest kernel, vmlinux.
#
#   tools/firecracker-runner/build-guest.sh       # on an x86_64 Linux host
#
# Needs sudo: apt runs in a chroot, and the image's files must be root's.
set -euo pipefail
here=$(dirname "$(readlink -f "$0")")

runner_version=2.338.2
runner_sha256=baebf204307bac6193480852732f0aba2ae97b6c5597c244f4d5558390147c40
# Firecracker's CI artifacts (docs/getting-started.md of Firecracker), pinned
ci=https://s3.amazonaws.com/spec.ccfc.min/firecracker-ci/20261111-778a26c0594c-0/x86_64
kernel=vmlinux-6.18.62
kernel_sha256=0ee1eb9074bfe4d90b3a6c0d3ea9c7c7b8c7563e69796fd73e7801db83a67b9f
ubuntu_sha256=f84ec1241d88414f43c417319fbaa31751d1cf4298f127b004c0bee8d95885c8
yq_version=4.54.3
yq_sha256=129534601871538efe0ba4c5e62a34fb1d5f469bcb975c4fddeb467d82974973
disk_size=40G

fetch() {
  local url=$1 file=$2 sha256=$3
  [ -f "$file" ] || curl -fsSL -o "$file" "$url"
  echo "$sha256  $file" | sha256sum -c --quiet
}
fetch "$ci/$kernel" vmlinux "$kernel_sha256"
fetch "$ci/ubuntu-24.04.squashfs" ubuntu-24.04.squashfs "$ubuntu_sha256"
runner_tarball=actions-runner-linux-x64-$runner_version.tar.gz
fetch "https://github.com/actions/runner/releases/download/v$runner_version/$runner_tarball" \
  "$runner_tarball" "$runner_sha256"
# mikefarah's yq, which GitHub's own runners have (Ubuntu's yq package is a
# different program)
fetch "https://github.com/mikefarah/yq/releases/download/v$yq_version/yq_linux_amd64" \
  yq "$yq_sha256"

sudo rm -rf root
mkdir -p root squashfs
sudo mount -o loop,ro ubuntu-24.04.squashfs squashfs
sudo cp -a squashfs/. root/
sudo umount squashfs
rmdir squashfs

# apt in the chroot needs the kernel's file systems and a resolver
cleanup() {
  for fs in dev/pts dev proc sys; do
    sudo umount "root/$fs" 2> /dev/null || true
  done
}
trap cleanup EXIT
for fs in proc sys dev dev/pts; do
  sudo mount --bind "/$fs" "root/$fs"
done
sudo rm -f root/etc/resolv.conf
echo 'nameserver 1.1.1.1' | sudo tee root/etc/resolv.conf > /dev/null
# (the image mounts a tmpfs there at boot; apt needs it in the chroot too)
sudo install -d -m 1777 root/tmp

sudo mkdir -p root/home/runner/actions-runner
sudo tar -xzf "$runner_tarball" -C root/home/runner/actions-runner
sudo chroot root /bin/bash -e <<'EOF'
export DEBIAN_FRONTEND=noninteractive
# (Ubuntu's PATH, not the build host's: useradd is in /usr/sbin)
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# (Firecracker's image is trimmed of apt's caches)
mkdir -p /var/cache/apt/archives/partial /var/lib/apt/lists/partial /var/log/apt
apt-get update
apt-get install -y --no-install-recommends passwd sudo git curl ca-certificates jq \
  unzip zip xz-utils zstd build-essential python3 openssh-client
# Docker, as on GitHub's own runners: service containers, docker build and
# buildx, docker compose
apt-get install -y --no-install-recommends docker.io docker-buildx docker-compose-v2 \
  iptables
useradd --uid 1001 --home-dir /home/runner --shell /bin/bash --groups docker runner
chown -R runner:runner /home/runner
# The VM is thrown away after every job: sudo in it reaches nothing else
echo 'runner ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/runner
/home/runner/actions-runner/bin/installdependencies.sh
apt-get clean
rm -rf /var/lib/apt/lists/*
EOF
cleanup
trap - EXIT

sudo install -m 0644 "$here"/guest/runner-net.service "$here"/guest/actions-runner.service \
  root/etc/systemd/system/
sudo install -m 0755 "$here"/guest/runner-net "$here"/guest/runner-config \
  "$here"/guest/runner-job-done.sh root/usr/local/bin/
sudo install -m 0755 yq root/usr/local/bin/yq
sudo chroot root systemctl enable runner-net.service actions-runner.service docker.service
# The VM's DNS: public resolvers, reached through the host's NAT (the home
# network itself is closed to it, host/fc-runner-forward.nft)
printf 'nameserver 1.1.1.1\nnameserver 9.9.9.9\n' | sudo tee root/etc/resolv.conf > /dev/null

rm -f rootfs.ext4
truncate -s "$disk_size" rootfs.ext4
sudo mkfs.ext4 -q -d root -F rootfs.ext4
sudo rm -rf root
ls -lsh vmlinux rootfs.ext4
