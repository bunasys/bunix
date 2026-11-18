unpack $src

# gzip.h defines a macro named `head`, and on aarch64 the kernel's signal
# structures have a member of that name: <signal.h> must come before
# gzip.h, not after.  Harmless on the other architectures.
sed -i 's/^#include "tailor.h"/#include <signal.h>\n&/' gzip.c
# a sed that matches nothing succeeds: make sure the line is there now
grep -q '^#include <signal.h>$' gzip.c

./configure $configure_for_usr --disable-nls
make
make DESTDIR=$out install
