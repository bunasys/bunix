# The Fly.io build machine

A build host for what the x86 builder cannot build (Chromium:
docs/browser.md), which runs, and costs, only while it builds.  Fly app
`bunix-build`, one machine in Frankfurt with a volume.  x86-64 only:
Fly's machines are x86-64, and arm64's Chromium is built on this Mac's
builder (tools/nix-builder/lima.yaml).

```
tools/nix-fly.sh nix/browser.nix chromium   # starts the machine, builds, copies the result back
tools/nix-fly.sh ssh                        # a shell on it
```

## How it fits together

- **Image** (`Dockerfile`, `start.sh`, `sshd_config`): Debian with sshd.
  Nix is upstream's static `nix`, the x86 builder's, which
  tools/nix-fly.sh copies to the volume once (`/data/nix-tool`), with
  `nix.conf`.
- **Volume** at `/data`: the store (`/data/nix-root`, as the x86
  builder's is under its home), the repository (`/data/bunix`) and the
  builds' logs (`/data/builds`).  The machine's own root file system is
  reset on every start.
- **Inputs** come from the x86 builder's store, through this Mac (the two
  cannot reach each other): what the package is built from and the
  machine does not have yet.  What the x86 builder has not built (a
  source not downloaded there), the machine builds itself.  The result
  goes back into the x86 builder's store, where images are made.
- **SSH** on port 2022 (22 is Fly's own SSH server, `fly ssh console`),
  keys only, reached only through `flyctl proxy` over Fly's private
  network: the machine has no public address.  The allowed keys are the
  machine's `AUTHORIZED_KEYS` environment variable.
- **No signing keys**: nothing built here is signed; releases are signed
  on this Mac.
- **Stops itself** after 30 minutes with neither an SSH connection nor a
  running nix-build or nix-store (`start.sh`).  A build runs detached
  from the SSH session that started it.

## Cost (Frankfurt, November 2026)

| | |
| --- | --- |
| Building: performance-16x, 32 GB | about $1 an hour while it runs |
| Volume, 150 GB | about $0.15 per GB a month, while it exists |
| Data | in free, out $0.02/GB |

A Chromium build takes about six hours.  The volume is made for a round
of builds and deleted after it (`flyctl volumes destroy`), so that it is
not billed for the months between.  Snapshots of it are off.

## Making it

```
cd tools/fly
flyctl deploy --build-only --push --image-label nix        # the image: registry.fly.io/bunix-build:nix
flyctl volumes create data --app bunix-build --region fra --size 150 --scheduled-snapshots=false --yes
flyctl machine run registry.fly.io/bunix-build:nix --app bunix-build --region fra \
  --vm-size performance-16x --volume data:/data --restart no \
  --env AUTHORIZED_KEYS="$(cat ~/.ssh/id_ed25519.pub)"
ssh-keygen -R bunix-fly     # a new volume, a new host key
```

And when the round of builds is done:

```
flyctl machine destroy <id> --app bunix-build --force
flyctl volumes destroy <volume id> --app bunix-build --yes
```
