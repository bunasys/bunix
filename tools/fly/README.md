# The Fly.io build machine

A build host for the large packages (Chromium: docs/browser.md) that runs,
and costs, only while it builds.  Fly app `bunix-build`, one machine
(`builder`) in Frankfurt with a 200 GB volume.

Fly boots its own kernel; only the image's files are ours.  That is all
BuildStream needs: it builds every element in its own sandbox
(bubblewrap) from the element's declared dependencies, so the host's
Debian never reaches a build.  The cache keys are the same as on every
other host (checked: base/zlib.bst has the same key here and on the
testbed), so packages built anywhere can be copied in.

```
tools/bst-fly.sh build base/chromium.bst    # starts the machine if it is stopped
tools/bst-fly.sh ssh                        # a shell on it
```

## How it fits together

- **Image** (`Dockerfile`, `start.sh`, `sshd_config`): Debian with
  python3, bubblewrap, FUSE, sshd and rsync.  tools/bst-remote.sh installs
  the pinned BuildStream on first use, as on any host.
- **Volume** at `/data`; root's home is bind-mounted from `/data/root`, so
  the BuildStream cache, the project copy and BuildStream itself survive
  restarts.  The machine's own root file system is reset on every start.
- **SSH** on port 2022 (22 is Fly's own SSH server, `fly ssh console`),
  keys only, reached only through `flyctl proxy` over Fly's private
  network: the machine has no public address.  The allowed keys are the
  machine's `AUTHORIZED_KEYS` environment variable.
- **No signing keys**: nothing built here is signed; releases are made on
  pro13.
- **Stops itself** after 30 minutes with neither an SSH connection nor a
  running `bst` (`start.sh`).  A stopped machine costs only its disk.

## Cost (Frankfurt, November 2026)

| | |
| --- | --- |
| Building: performance-16x, 48 GB | about $1.00 per hour running |
| Copying caches: shared-cpu-2x, 2 GB | about $0.02 per hour running |
| Volume, 200 GB | about $35 a month, whether running or not |
| Data | in free, out $0.02/GB |

Snapshots of the volume are turned off: the cache can always be rebuilt,
and snapshots are billed per GB stored.

The size is changed between copying and building (the volume stays):

```
flyctl machine update <id> --app bunix-build --vm-size performance-16x --vm-memory 49152 --yes
flyctl machine update <id> --app bunix-build --vm-size shared-cpu-2x --vm-memory 2048 --yes
```

## The shared cache

`tools/bst-fly.sh` connects the machine to the shared cache on pro13
(tools/cache-server/README.md) when pro13 is reachable: the machine pulls
what pro13 built, so nothing is copied by hand.  It gets the cache's
pull-only ports: what it builds goes into the cache only when pushed, with
`tools/bst-fly.sh artifact push <elements>`.

## Filling the cache from the testbed (before the shared cache)

The first time, the testbed's cache was copied in (29 GB, about an hour at
7 MB/s): the testbed reaches the machine through this Mac's proxy
(`ssh -R`), with this Mac's key through the agent (`ssh -A`):

```
flyctl proxy 2222:2022 --app bunix-build &
ssh-add ~/.ssh/id_ed25519
FLY_SSH="ssh -p 2222 -o HostKeyAlias=bunix-fly -o StrictHostKeyChecking=accept-new"
ssh -A -R 2222:localhost:2222 -i ~/Projects/bunix/id_ed25519 root@192.168.88.68 "bash -c 'cd ~/.cache/buildstream &&
  rsync -a --ignore-existing -e \"$FLY_SSH\" cas/objects/ root@localhost:.cache/buildstream/cas/objects/ &&
  rsync -a --ignore-existing -e \"$FLY_SSH\" artifacts/ root@localhost:.cache/buildstream/artifacts/'"
```

Objects first, then the artifact entries that name them (as
tools/cache-sync.sh does), and no `bst` running on either side.

## Making it again

```
flyctl apps create bunix-build --org personal
flyctl volumes create bunix_data --app bunix-build --region fra --size 200 --yes
flyctl volumes update <volume id> --app bunix-build --scheduled-snapshots=false
cd tools/fly && flyctl deploy --build-only --push --image-label v3 --app bunix-build
flyctl machine run registry.fly.io/bunix-build:v3 --app bunix-build --name builder --region fra \
  --vm-size shared-cpu-2x --vm-memory 2048 --volume bunix_data:/data --restart no --detach \
  --env AUTHORIZED_KEYS="$(cat ~/.ssh/id_ed25519.pub)"
```

## Open points

- `bst` runs inside the SSH session: if this Mac sleeps or loses its
  connection during a day-long build, the build stops (the machine stays
  up until it is idle).  Long builds should run detached on the machine.
- tools/bst-remote.sh pins `make -j8` for every host (it is part of the
  cache keys); with 16 CPUs, `--builders 2` keeps them busy.  Chromium's
  own job count is set in its element.
