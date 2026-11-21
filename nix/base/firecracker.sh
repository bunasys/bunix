# The archive is the release as its makers built it: the two programs,
# each named with its version and architecture.
unpack $src
install -D -m 755 firecracker-v*-x86_64 $out/usr/bin/firecracker
install -D -m 755 jailer-v*-x86_64 $out/usr/bin/jailer
