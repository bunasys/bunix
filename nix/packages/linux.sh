# The kernel image, without its modules for now (packages/linux/), and the
# program that packs an initramfs for it.
#
# $options is packages/linux/: one file of options per architecture, on
# top of the kernel's own default configuration.
#
# Installed as vmlinuz whatever the architecture calls its image, so that
# what boots it need not know.
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
make ARCH=$kernel_arch LOCALVERSION=-bunix \
    KBUILD_BUILD_USER=bunix KBUILD_BUILD_HOST=bunix \
    KBUILD_BUILD_TIMESTAMP="$(date -u -d @$SOURCE_DATE_EPOCH)" \
    $(basename $image)

mkdir -p $out/bin
cp $image $out/vmlinuz
cp .config $out/config
# built with the kernel, for making the initramfs it unpacks (initramfs.sh)
cp usr/gen_init_cpio $out/bin/
