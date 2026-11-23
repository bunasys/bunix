# U-Boot for one kind of machine, in /usr/lib/u-boot/$machine/:
#
#   u-boot-nodtb.bin  the program without a device tree: what starts it
#                     hands it the machine's
#   config            what it was built with
#
# $configuration is the file of the source's configs/ for that kind of
# machine.
#
# Built with the system's compiler: U-Boot's own tools and the program
# are both for the architecture the build runs on.
unpack $src

make $configuration
# A tool for making firmware updates, which nothing here uses, and which
# needs a library the build does not have.
scripts/config --disable TOOLS_MKEFICAPSULE
make olddefconfig
if grep -q '^CONFIG_TOOLS_MKEFICAPSULE=y' .config; then
    echo "u-boot.sh: TOOLS_MKEFICAPSULE is still on" >&2
    exit 1
fi

make u-boot-nodtb.bin

install -D -m 644 u-boot-nodtb.bin $out/usr/lib/u-boot/$machine/u-boot-nodtb.bin
install -m 644 .config $out/usr/lib/u-boot/$machine/config
