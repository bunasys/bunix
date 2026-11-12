# GitHub Actions jobs in Firecracker microVMs

Self-hosted GitHub Actions runners on a bunix machine, where every job
runs in a microVM of its own that is thrown away afterwards.  One instance
per registered runner (a repository-level runner takes only its own
repository's jobs): on the testbed, `fc-runner@1` for bunasys/bunix and
`fc-runner@2` for bunasys/banan-platform, so the two never share a VM.

```
fc-runner@<n>.service (host, as fc-runner)
  loop: copy rootfs.ext4 -> boot Firecracker -> VM runs one job -> VM reboots
        -> Firecracker exits -> loop
VM: Ubuntu 24.04 (Firecracker's CI image) + the Actions runner, Docker, yq
    /dev/vda  a fresh copy of rootfs.ext4 (40 GB, sparse)
    /dev/vdb  config-<n>.ext4, read-only: the runner's registration
    eth0      172.16.0.<4n+2>/30 -> tap fc-tap<n> (.<4n+1>) -> NAT -> internet
    4 vCPUs, 12 GB
```

- **One job per VM.**  The runner runs with `--once`: it takes one job,
  reports it and exits; when the runner stops, the VM reboots, which ends
  Firecracker.  Nothing a job writes reaches the next one.
- **No admin token on the machine.**  The runner is registered once
  (`register.sh`); every VM gets that registration from the config drive.
  A job can read it (as on any self-hosted runner), but only for its own
  VM's lifetime.
- **Only jobs that ask for it.**  The runner's single label is
  `bunix-firecracker`, without GitHub's default `self-hosted` labels:
  `runs-on: bunix-firecracker`.  bunasys/bunix is public, so a workflow
  there that runs on it must not run for pull requests from forks.
- **Internet only.**  The VMs reach the internet through NAT; the home
  network and every other private address are dropped
  (`host/fc-runner-forward.nft`, in bunix's firewall forward chain).  DNS
  is 1.1.1.1 and 9.9.9.9.

## Setting it up

On an x86_64 Linux machine with sudo (pro13):

```
mkdir -p ~/fc-runner && cd ~/fc-runner
~/src/bunix/tools/firecracker-runner/build-guest.sh       # vmlinux, rootfs.ext4
token() { gh api -X POST repos/$1/actions/runners/registration-token --jq .token; }
~/src/bunix/tools/firecracker-runner/register.sh 1 bunasys/bunix \
  "$(token bunasys/bunix)" bunix-testbed-fc                # config-1.ext4
~/src/bunix/tools/firecracker-runner/register.sh 2 bunasys/banan-platform \
  "$(token bunasys/banan-platform)" banan-testbed-fc       # config-2.ext4
```

On the bunix machine (kernel with KVM, tun and NAT; the devtools extension
enabled, for `firecracker`), as root, with vmlinux, rootfs.ext4 and the
config-<n>.ext4 files next to `install.sh` and `host/`:

```
./install.sh
journalctl -fu fc-runner@2    # instance 2's VM consoles
```

Until bunix enables systemd-tmpfiles-setup-dev, /dev/net/tun appears only
once tun is loaded: install.sh has it loaded at boot
(/etc/modules-load.d/fc-runner.conf).

## Keeping it current

The runner does not update itself (its update would be lost with the VM).
GitHub refuses runners more than 30 days behind the latest release:
raise `runner_version` in `build-guest.sh`, rebuild the image, copy
`rootfs.ext4` over `/var/lib/fc-runner/rootfs.ext4` and restart the
instances.  The registrations stay valid.
