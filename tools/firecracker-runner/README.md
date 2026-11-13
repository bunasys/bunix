# GitHub Actions jobs in Firecracker microVMs

Self-hosted GitHub Actions runners for the bunasys organization on a bunix
machine, where every job runs in a microVM of its own that is thrown away
afterwards.  Each instance (`fc-runner@1`, `fc-runner@2`, ...) runs one VM
at a time, so the number of instances is the number of jobs at once.

```
fc-runner@<n>.service, once per job
  prepare (root):  tap fc-tap<n>, a fresh copy of rootfs.ext4, a one-job
                   registration from GitHub on registration.ext4
  firecracker (as fc-runner-<n>):  the VM runs one job, then reboots
  cleanup (root):  tap, disk and an unused registration removed
VM: Ubuntu 24.04 (Firecracker's CI image) + the Actions runner, Docker, yq
    /dev/vda  the fresh copy of rootfs.ext4 (40 GB, sparse)
    /dev/vdb  registration.ext4, read-only
    eth0      172.16.0.<4n+2>/30 -> fc-tap<n> (.<4n+1>) -> NAT -> internet
    4 vCPUs, 12 GB
```

- **One job per VM, one registration per job.**  Before each VM, the host
  asks GitHub for a just-in-time runner registration: GitHub gives that
  runner one job and removes it afterwards.  A job can read its own
  registration, as on any runner, but it is no use once the job is over.
- **A GitHub App, not a token.**  The host signs in as a GitHub App whose
  one permission is the organization's self-hosted runners.  Its key is in
  /etc/fc-runner, readable by root alone; Firecracker runs as a user of its
  instance with no view of it (`host/fc-runner@.service`).
- **Only the jobs meant for it.**  The runners are in an organization
  runner group limited to bunasys/bunix and bunasys/banan-platform, with
  the single label `bunix-firecracker` (`runs-on: bunix-firecracker`).
  bunasys/bunix is public, so a pull request from a fork can ask for the
  label: the repository requires approval before any outside contributor's
  workflow runs.
- **Internet only.**  A VM reaches the internet through NAT and nothing
  else: not the machine, not the home network, not the other VMs
  (`host/fc-runner.nft`, a table of its own that holds whether or not
  bunix's firewall is loaded).  DNS is 1.1.1.1 and 9.9.9.9.

## Setting it up

Once, on GitHub (an organization owner):

1. A GitHub App for bunasys (Settings, Developer settings, GitHub Apps):
   no webhook; one permission, Organization: Self-hosted runners, read and
   write.  Install it on bunasys.  Generate a private key.
2. A runner group (Settings, Actions, Runner groups), e.g. `firecracker`:
   selected repositories bunix and banan-platform, public repositories
   allowed (bunix is one).  Its id:
   `gh api orgs/bunasys/actions/runner-groups --jq '.runner_groups[] | [.id, .name]'`

On an x86_64 Linux machine with sudo (pro13):

```
mkdir -p ~/fc-runner && cd ~/fc-runner
~/src/bunix/tools/firecracker-runner/build-guest.sh       # vmlinux, rootfs.ext4
```

On the bunix machine (kernel with KVM, tun and NAT; the devtools extension
enabled, for `firecracker`), as root: the app's key, copied there directly
(never through a chat or a repository), and its settings:

```
install -d -m 0700 /etc/fc-runner
install -m 0600 <key>.pem /etc/fc-runner/app.pem
cat > /etc/fc-runner/github.conf <<CONF
APP_ID=<the app's id>
INSTALLATION_ID=<its installation's id, from the installation page's URL>
ORGANIZATION=bunasys
RUNNER_GROUP_ID=<the group's id>
RUNNER_NAME=testbed
CONF
```

then, with vmlinux and rootfs.ext4 next to `install.sh` and `host/`:

```
./install.sh 1 2
journalctl -fu fc-runner@2    # instance 2's VMs
```

Until bunix enables systemd-tmpfiles-setup-dev, /dev/net/tun appears only
once tun is loaded: install.sh has it loaded at boot
(/etc/modules-load.d/fc-runner.conf).

## Keeping it current

The runner does not update itself (its update would be lost with the VM).
GitHub refuses runners more than 30 days behind the latest release: raise
`runner_version` in `build-guest.sh`, rebuild the image, and rerun
`install.sh` with the same instances.  That restarts them, which ends the
jobs they are running.
