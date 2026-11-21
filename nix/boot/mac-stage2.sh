# /usr/lib/mac-stage2/stage2.bin: the one file of a Mac's ESP that aura's
# first stage loads (boot.nix says what is in it), and beside it the
# tool's list of the parts, with the hash of each.
#
# The build's /usr has the packages the parts come from.
tree_arguments=
for tree in /usr/lib/modules/*/dtb/apple/*.dtb; do
    tree_arguments="$tree_arguments --dtb $tree"
done

install -d $out/usr/lib/mac-stage2
python3 /usr/lib/aura/tools/compose_stage2.py \
    --aura /usr/lib/aura/aura-stage2.bin \
    --kernel-commit $kernel_commit \
    $tree_arguments \
    --uboot /usr/lib/u-boot/apple/u-boot-nodtb.bin \
    --output $out/usr/lib/mac-stage2/stage2.bin
