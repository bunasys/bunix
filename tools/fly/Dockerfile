# The Fly.io build machine (tools/fly/README.md): only what BuildStream
# needs from its host.  Everything a build produces lives on the volume
# (/data), because a Fly machine's root file system is reset on every start.
FROM debian:trixie-slim

# python3-venv and a C compiler: tools/bst-remote.sh pip-installs the pinned
# BuildStream into a virtualenv on first use (it builds from source when no
# wheel fits).  bubblewrap and fuse3: BuildStream's sandbox and its view of
# the cache.  patch: BuildStream's patch sources run the host's.  iproute2
# and procps: the idle check in start.sh.
RUN apt-get update && apt-get install -y --no-install-recommends \
      python3 python3-venv python3-dev gcc \
      bubblewrap fuse3 patch \
      openssh-server rsync git ca-certificates \
      iproute2 procps \
    && rm -rf /var/lib/apt/lists/*

COPY sshd_config /etc/ssh/sshd_config.d/bunix.conf
COPY start.sh /usr/local/bin/start.sh

CMD ["/usr/local/bin/start.sh"]
