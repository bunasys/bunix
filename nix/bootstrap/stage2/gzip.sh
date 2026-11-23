unpack $src

# gzip.h defines a macro named `head`, and on aarch64 the kernel's signal
# structures have a member of that name: <signal.h> must come before
# gzip.h, not after.  Harmless on the other architectures.
sed -i 's/^#include "tailor.h"/#include <signal.h>\n&/' gzip.c
# a sed that matches nothing succeeds: make sure the line is there now
grep -q '^#include <signal.h>$' gzip.c

# GREP: zgrep runs it; by name, not the path configure would find
# (stage2.nix)
./configure --prefix=$out GREP=grep
make
make install
