# The Fly.io build machine (README.md): sshd and the tools to copy Nix
# store paths in and out.  Nix itself is upstream's static `nix`, which
# tools/nix-fly.sh puts on the volume, as on the x86 builder
# (tools/nix-builder/home-store/nix.conf).  Everything a build produces
# lives on the volume (/data): a Fly machine's root file system is reset
# on every start.
FROM debian:trixie-slim

# iproute2 and procps: the idle check in start.sh
RUN apt-get update && apt-get install -y --no-install-recommends \
      openssh-server ca-certificates iproute2 procps \
    && rm -rf /var/lib/apt/lists/*

COPY sshd_config /etc/ssh/sshd_config.d/bunix.conf
COPY start.sh /usr/local/bin/start.sh

CMD ["/usr/local/bin/start.sh"]
