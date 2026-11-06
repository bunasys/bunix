# The shared build cache

Every machine that builds bunix pulls from one BuildStream artifact cache on
the build host (pro13), so a package built anywhere is not built again
elsewhere.  It replaces copying caches with `tools/cache-sync.sh`.

It is Buildbarn, the cache server BuildStream documents:

| Service | Port | What it holds |
| --- | --- | --- |
| `bb_remote_asset` (`asset.jsonnet`) | 7981 | the index: artifact names → content |
| `bb_storage` (`storage.jsonnet`) | 7982 | the content, 140 GiB, least recently used goes first |

A port is set in `asset.jsonnet` or `storage.jsonnet`, `buildstream.conf`
and `tools/bst-fly.sh`; changing one means changing all of them.

## Who can put artifacts in it

Releases are built on pro13 from this cache, so what is in it ends up
signed.  Both services listen only on pro13's 127.0.0.1, and nothing else
reaches them:

- **pro13's own builds** pull and push (`buildstream.conf`, installed as the
  build user's `~/.config/buildstream.conf`).
- **The CI VMs** on pro13 cannot reach the host's loopback: passt runs with
  `--no-map-gw`, and `ci-vm-firewall` blocks private and loopback addresses.
- **The Fly machine** reaches the cache through SSH tunnels from this Mac
  (`tools/bst-fly.sh`), and only pulls.  What it builds enters the cache
  only when we push it: `tools/bst-fly.sh artifact push <elements>`.  That
  trusts whoever can log in to the Fly machine, as copying its cache did.

## Disk space

The data is in `/srv/ci/bst-cache` on pro13's USB disk (234 GB), next to the
CI VMs' images in `/srv/ci/ci-vm`.  install.sh allocates the whole store up
front (140 GiB, plus 1 GiB of index), so the CI VMs keep about 90 GB that
the cache can never take.

## Install or update

```
tools/cache-server/install.sh            # BUNIX_BUILD_HOST picks the host
```

It installs the pinned binaries (checked against their published
checksums), the configuration in `/etc/bst-cache`, and two system services;
and it writes `buildstream.conf` as the host's `~/.config/buildstream.conf`,
so every `tools/bst-remote.sh` build there uses the cache.  Running it again
keeps the cached data, unless the store's size changed.

## From another machine

`tools/bst-fly.sh` does this for the Fly machine on every run.  By hand, for
a machine you are logged in to: forward the ports, and give its BuildStream
`buildstream.conf` with `push: false`:

```
ssh -N -L 7981:127.0.0.1:7981 -L 7982:127.0.0.1:7982 pro13.home.arpa
```
