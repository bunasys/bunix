# The kernel image, without its modules for now (boot/linux/), and the
# program that packs an initramfs for it.
#
# The configuration is the kernel's own default for the architecture
# (with, on a Mac's, the source's list of what a Mac needs), then bunix's
# options: $options_directory has one file of them per
# architecture.
#
# Built with clang and LLVM's linker and tools (LLVM=1), on every
# architecture: the kernel's Rust code (a Mac's drivers) requires it,
# Aurora's kernel is tested so, and x86 is built the same way.
#
# Installed in /usr/lib/modules/<release>/, the place UAPI.9 gives the
# kernel image, as vmlinuz whatever the architecture calls it.
unpack $src

case $system in
    aarch64-linux)
        kernel_arch=arm64
        # asahi.config: the source's own list of what a Mac needs
        default_configuration="defconfig asahi.config"
        wanted_options=$options_directory/aarch64.config
        # a Mac's boot loader hands the kernel the device tree of the
        # machine: a directory of arch/arm64/boot/dts/
        device_trees=apple
        image=arch/arm64/boot/Image
        ;;
    x86_64-linux)
        kernel_arch=x86
        default_configuration=x86_64_defconfig
        wanted_options=$options_directory/x86_64.config
        # a PC's firmware describes the machine itself
        device_trees=
        image=arch/x86/boot/bzImage
        ;;
    *) echo "linux.sh: there is no kernel configuration for $system yet" >&2; exit 1 ;;
esac

# bindgen loads libclang, and looks for it where it is told
export LIBCLANG_PATH=/usr/lib/$triplet

# The kernel records who built it, where and when: always the same here.
kernel_make() {
    make ARCH=$kernel_arch LLVM=1 LOCALVERSION=-bunix \
        KBUILD_BUILD_USER=bunix KBUILD_BUILD_HOST=bunix \
        KBUILD_BUILD_TIMESTAMP="$(date -u -d @$SOURCE_DATE_EPOCH)" \
        "$@"
}

# where the configuration says the kernel's built-in certificate is
install -D -m 644 $verity_certificate bunix/verity.crt

kernel_make $default_configuration
scripts/kconfig/merge_config.sh -m .config $wanted_options
kernel_make olddefconfig

# An option whose requirements are not met is dropped without a word: make
# sure each one asked for is there.
grep -E '^(CONFIG_|# CONFIG_)' $wanted_options | while read -r option; do
    if ! grep -q -x -F "$option" .config; then
        echo "linux.sh: not applied: $option" >&2
        exit 1
    fi
done

kernel_make $(basename $image)

release=$(kernel_make -s kernelrelease)
install -D -m 644 $image $out/usr/lib/modules/$release/vmlinuz
install -m 644 .config $out/usr/lib/modules/$release/config

if [ -n "$device_trees" ]; then
    # Every vendor's device trees are built and one directory kept: asked
    # for the one directory, make finds nothing to do.
    kernel_make dtbs
    install -d $out/usr/lib/modules/$release/dtb/$device_trees
    install -m 644 arch/$kernel_arch/boot/dts/$device_trees/*.dtb $out/usr/lib/modules/$release/dtb/$device_trees/
fi

# built with the kernel, for making the initramfs it unpacks
# (images/image.sh)
install -D -m 755 usr/gen_init_cpio $out/usr/bin/gen_init_cpio
