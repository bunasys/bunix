# A build VM on a bunix machine

bunix itself has no Python, bubblewrap or FUSE, so BuildStream cannot run
on it directly.  This makes a Firecracker microVM that can: the runners'
Ubuntu image (tools/firecracker-runner) with BuildStream's needs and an SSH
server added, on a disk it keeps, so its build cache survives restarts.  On
the testbed it adds 6 CPUs and 16 GB to pro13 and the Fly machine.

```
tools/bst-build-vm.sh build system/uki.bst          # bst in the VM
tools/bst-build-vm.sh artifact push --deps all system/uki.bst
tools/bst-build-vm.sh ssh                           # a shell in the VM
```

- **Network:** the runners' (host/fc-runner.nft), as their instance 62:
  the internet and nothing else; the VM cannot reach the testbed or the
  home network.  This Mac reaches it at 172.16.0.250 by SSH, jumping
  through the testbed.
- **The shared cache:** as the Fly machine has it (tools/bst-fly.sh):
  pull-only, through SSH tunnels from this Mac, and pushed into only with
  `artifact push`.  Releases are built from that cache, so nothing built
  in the VM enters it unless we push it.
- **No signing keys** in the VM.
- **Firecracker runs as fc-build**, sandboxed as the runners' is.

## Setting it up

With the runners installed on the machine (their image, kernel and
network rules), as root there, in a copy of this directory:

```
./setup.sh "$(cat ~/.ssh/id_ed25519.pub)"
```

It makes `/var/lib/fc-build/disk.ext4` (70 GB, sparse), installs and starts
`fc-build.service`, and prints the VM's host key, which goes into this
Mac's `~/.ssh/known_hosts` as `bunix-build-vm <key>`.  Rerunning it keeps
the disk and its cache.

`systemctl stop fc-build` shuts the VM down cleanly; `systemctl disable`
keeps it from starting at boot.
