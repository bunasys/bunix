# GitHub Actions jobs in Firecracker microVMs

A self-hosted runner for `bunasys/bunix` on a bunix machine, where every
job runs in a microVM of its own that is thrown away afterwards.

```
fc-runner.service (host, as fc-runner)
  loop: copy rootfs.ext4 -> boot Firecracker -> VM runs one job -> VM reboots
        -> Firecracker exits -> loop
VM: Ubuntu 24.04 (Firecracker's CI image) + the Actions runner
    /dev/vda  a fresh copy of rootfs.ext4 (40 GB, sparse)
    /dev/vdb  config.ext4, read-only: the runner's registration
    eth0      172.16.0.2/30 -> tap fc-tap0 (172.16.0.1) -> NAT -> internet
```

- **One job per VM.**  The runner's job-completed hook stops it ten seconds
  after the job, so the result is reported first; when the runner stops,
  the VM reboots, which ends Firecracker.  Nothing a job writes reaches the
  next one.
- **No admin token on the machine.**  The runner is registered once
  (`register.sh`); every VM gets that registration from the config drive.
  A job can read it (as on any self-hosted runner), but only for its own
  VM's lifetime.
- **Only jobs that ask for it.**  The runner's single label is
  `bunix-firecracker`, without GitHub's default `self-hosted` labels:
  `runs-on: bunix-firecracker`.  The repository is public, so a workflow
  that runs on it must not run for pull requests from forks.
- **Internet only.**  The VMs reach the internet through NAT; the home
  network and every other private address are dropped
  (`host/fc-runner-forward.nft`, in bunix's firewall forward chain).  DNS
  is 1.1.1.1 and 9.9.9.9.

## Setting it up

On an x86_64 Linux machine with sudo (pro13):

```
mkdir -p ~/fc-runner && cd ~/fc-runner
~/src/bunix/tools/firecracker-runner/build-guest.sh       # vmlinux, rootfs.ext4
token=$(gh api -X POST repos/bunasys/bunix/actions/runners/registration-token --jq .token)
~/src/bunix/tools/firecracker-runner/register.sh "$token"  # config.ext4
```

On the bunix machine (kernel with KVM, tun and NAT; the devtools extension
enabled, for `firecracker`), as root, with those three files next to
`install.sh` and `host/`:

```
./install.sh
journalctl -fu fc-runner    # the VMs' consoles
```

## Keeping it current

The runner does not update itself (its update would be lost with the VM).
GitHub refuses runners more than 30 days behind the latest release:
raise `runner_version` in `build-guest.sh`, rebuild the image and copy
`rootfs.ext4` over `/var/lib/fc-runner/rootfs.ext4`.  The registration
stays valid.
