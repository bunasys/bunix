# The seed: the one thing in the store that was not built in it.  A static
# toolchain (gcc, binutils, glibc, bash and the usual tools) for one
# architecture, built outside Nix: cross-compiled on an x86_64 bunix
# machine by tools/seed.sh.
# Stage 1 is built with it; nothing after stage 3 depends on it, except
# that its bash is still every build's /bin/sh (sh.nix).
#
#   import ./seed.nix { system = "aarch64-linux"; }
#
# Evaluates to the store path of the unpacked tarball.  The sha256 is of the
# unpacked tree, so it pins every file of the seed.  The store path comes
# from the name and the sha256, not the url: the url can change (each is
# where the seed is on its builder today, until the seeds are published)
# and nothing is rebuilt.
#
# This is the only download made while evaluating, by Nix itself: before the
# seed there is no program in the store that could unpack a tarball.  Every
# other source is a fixed-output derivation.
{ system }:

let
  # One seed for each architecture bunix builds on.  Each url is where
  # that seed is today, as its builder sees it: the Mac that serves it to
  # the aarch64 VM, and the file tools/seed.sh leaves on the x86_64 machine.
  seeds = {
    aarch64-linux = {
      name = "bunix-seed-aarch64";
      url = "http://host.lima.internal:8642/bunix-seed-aarch64.tar.xz";
      sha256 = "1glm6rh0xbf431damk1qb0gqapa3azgi1xgnqwqw00mmszhfq75s";
    };
    x86_64-linux = {
      name = "bunix-seed-x86_64";
      url = "file:///home/khaled/seed-x86_64/bunix-seed-x86_64.tar.xz";
      sha256 = "1jik92g40w37lcscmqcphdqw72z4cz1hfmy5hld5v26kqlhvlyl1";
    };
  };
in
if builtins.hasAttr system seeds
then builtins.fetchTarball seeds.${system}
else throw "there is no seed for ${system}: nix/seed.nix lists the ones that exist"
