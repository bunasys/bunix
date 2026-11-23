unpack $src
# configure would install, with pip, what QEMU's tests run with; this
# Python has no pip (the patch says more)
for fix in $patches; do
    patch --fuzz=0 -p1 -i $fix
done

# What differs between the architectures: the kind of machine QEMU is
# built to be, which is the one it runs on, as its source names it; and
# which of the firmware in its source such a machine takes (below).
case $triplet in
    x86_64-linux-gnu)
        target=x86_64-softmmu
        own_firmware="edk2-x86_64-* edk2-i386-vars.fd bios*.bin qboot.rom linuxboot*.bin multiboot*.bin kvmvapic.bin pvh.bin"
        ;;
    aarch64-linux-gnu)
        target=aarch64-softmmu
        own_firmware="edk2-aarch64-* edk2-arm-vars.fd"
        ;;
    *) echo "qemu.sh: which machine QEMU is to be for $triplet is not said here" >&2; exit 1 ;;
esac

# QEMU's build is meson's, started by a configure script of its own, which
# wants meson (and pycotap, for its tests) as Python packages it can ask
# the version of, and installs the ones the source carries, as wheels,
# with pip.  A wheel is a zip of what goes on Python's path: unpacked
# there, configure finds both, and takes them.
wheels=/build/wheels
mkdir $wheels
for wheel in python/wheels/meson-*.whl python/wheels/pycotap-*.whl; do
    python3 -m zipfile -e $wheel $wheels
done
export PYTHONPATH=$wheels

# Nothing that is found is built in unasked (--without-default-features);
# then what a machine for testing a system needs:
#
#   kvm, tcg    the machine's processor: the real one, where /dev/kvm is;
#               and one in software, where it is not (a builder that is
#               itself a virtual machine)
#   slirp       a network without root (base.nix: libslirp)
#   pixman, vnc a screen, looked at over the network: a machine that
#               builds has none of its own
#   fdt         the device tree QEMU writes for a machine, with the
#               system's libfdt (base.nix: dtc), not one it downloads
#   vhost-net, vhost-kernel
#               the host's kernel carries a network card's packets
#               itself, for a machine given a device of the host's
#   tools       qemu-img, which makes and converts disk images
#   pie         as every program of the system
#
# No manual (docs): it is made with Sphinx.  werror: off, as for dtc.
#
# The directories are spelled out: configure takes fewer of them than
# $configure_for_usr has.
./configure --prefix=/usr --bindir=/usr/bin --libdir=/usr/lib/$triplet --libexecdir=/usr/lib \
    --sysconfdir=/etc --localstatedir=/var \
    --target-list=$target --without-default-features \
    --enable-kvm --enable-tcg --enable-slirp --enable-pixman --enable-vnc --enable-fdt=system \
    --enable-vhost-net --enable-vhost-kernel --enable-tools --enable-pie \
    --disable-docs --disable-werror
make
make DESTDIR=$out install

# The firmware a machine starts with is not built here: QEMU's source
# carries it built (pc-bios/), for every architecture QEMU can be, and
# installs all of it.  Kept is what this architecture's machines take:
# EFI (EDK II: edk2-*, and its licences), a PC's BIOS and what it starts
# a kernel with, and, of either, the ROMs of the cards a machine is
# given; and the keyboard layouts, which are no firmware (for vnc).  Not
# the lists of firmware for other programs to read (firmware/): they
# name files that are not kept.
share=$out/usr/share/qemu
mkdir /build/kept
(cd $share && mv keymaps efi-*.rom vgabios*.bin pxe-*.rom edk2-licenses.txt $own_firmware /build/kept/)
rm -r $share
mv /build/kept $share
