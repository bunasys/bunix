# The seed: the one thing in the store that was not built in it.  A static
# aarch64 toolchain (gcc, binutils, glibc, bash and the usual tools),
# cross-compiled on an x86_64 bunix machine by tools/aarch64-seed.sh.
# Stage 1 is built with it; nothing after stage 3 depends on it.
#
# Evaluates to the store path of the unpacked tarball.  The sha256 is of the
# unpacked tree, so it pins every file of the seed.  The store path comes
# from the name and the sha256, not the url: the url can change (it is this
# Mac, as the builder VM sees it, until the seed is published) and nothing
# is rebuilt.
#
# This is the only download made while evaluating, by Nix itself: before the
# seed there is no program in the store that could unpack a tarball.  Every
# other source is a fixed-output derivation.
builtins.fetchTarball {
  name = "bunix-seed-aarch64";
  url = "http://host.lima.internal:8642/bunix-seed-aarch64.tar.xz";
  sha256 = "1glm6rh0xbf431damk1qb0gqapa3azgi1xgnqwqw00mmszhfq75s";
}
