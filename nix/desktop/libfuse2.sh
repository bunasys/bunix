# ../autotools.sh's lines.  The library alone: libfuse 2 is no longer
# developed, and is here for the AppImages made with it, which load
# libfuse.so.2.  Its fusermount is libfuse 3's fusermount3 under the old
# name (images/desktop.nix, links), as Debian has it: they speak the
# same protocol.  Nor mount.fuse, examples or static library.
unpack $src
# The kernel's integer types (__u64 and the rest), which fuse_kernel.h
# defines as macros: a header of today's C library includes the kernel's
# own definitions after it, which the macros then turn into a second
# definition of uint64_t.  Taken from the kernel's header instead, as
# libfuse 3 does.
header=include/fuse_kernel.h
sed -i -e '/^#define __[us]\(64\|32\|16\) u\?int[0-9]*_t$/d' \
       -e 's|^#include <sys/types.h>$|#include <linux/types.h>|' $header
includes_the_kernel_types=no
grep -q '^#include <linux/types.h>$' $header && includes_the_kernel_types=yes
still_defines_them=no
grep -q '^#define __[us]64' $header && still_defines_them=yes
if [ $includes_the_kernel_types = no ] || [ $still_defines_them = yes ]; then
    echo "libfuse2.sh: $header's integer types were not replaced (is this source still 2.9.9?)" >&2
    exit 1
fi
./configure $configure_for_usr --disable-util --disable-example --disable-static
make
make DESTDIR=$out install
