# The kernel image, without its modules for now (system/linux/), and the
# program that packs an initramfs for it.
#
# $options is system/linux/: one file of options per architecture, on top
# of the kernel's own default configuration.
#
# Installed in /usr/lib/modules/<release>/, the place UAPI.9 gives the
# kernel image, as vmlinuz whatever the architecture calls it.
unpack $src

case $system in
    aarch64-linux)
        kernel_arch=arm64
        wanted=$options/aarch64.config
        image=arch/arm64/boot/Image
        ;;
    *) echo "linux.sh: there is no kernel configuration for $system yet" >&2; exit 1 ;;
esac

make ARCH=$kernel_arch defconfig
scripts/kconfig/merge_config.sh -m .config $wanted
make ARCH=$kernel_arch olddefconfig

# An option whose requirements are not met is dropped without a word: make
# sure each one asked for is there.
grep -E '^(CONFIG_|# CONFIG_)' $wanted | while read -r option; do
    if ! grep -q -x -F "$option" .config; then
        echo "linux.sh: not applied: $option" >&2
        exit 1
    fi
done

# The kernel records who built it, where and when: always the same here.
build() {
    make ARCH=$kernel_arch LOCALVERSION=-bunix \
        KBUILD_BUILD_USER=bunix KBUILD_BUILD_HOST=bunix \
        KBUILD_BUILD_TIMESTAMP="$(date -u -d @$SOURCE_DATE_EPOCH)" \
        "$@"
}
build $(basename $image)

release=$(build -s kernelrelease)
install -D -m 644 $image $out/usr/lib/modules/$release/vmlinuz
install -m 644 .config $out/usr/lib/modules/$release/config
# built with the kernel, for making the initramfs it unpacks
# (images/initramfs.sh)
install -D -m 755 usr/gen_init_cpio $out/usr/bin/gen_init_cpio
