# Makes an image (images/system.nix, images/initrd.nix): the root of a
# system as a tree, and then that tree as an archive the kernel unpacks
# into memory, initramfs.cpio.gz.
#
#   $contents_packages   the store path of every package the image has
#                        (stage.nix).  The archive gets their files; it
#                        never names where they came from.
#   $bunix_files         bunix's own configuration, a tree laid over them
#   $shared_files, $same_as_x86
#                        files/rootfs, and the paths of it that this image
#                        has the same as the system on x86, if any
#   $usr_partition       set for an image that is also to be installed on
#                        a disk: its /usr is made into the images of a
#                        /usr partition as well ("/usr as a partition",
#                        below), in usr-partition/ of the result
#   $certificates        whose signature on an image's hash this system
#                        takes: certificates, for /usr/lib/verity.d
#   $variant             what the system says it is, if it is not the one
#                        for release: VARIANT_ID in /usr/lib/os-release
#   $version             of a system that is updated (images/system.nix):
#                        IMAGE_VERSION and SYSEXT_LEVEL in
#                        /usr/lib/os-release.  Needed with $usr_partition.
set -euo pipefail
cd /build

# The time of the build, for whatever would record it: always the same.
# Not second 1, as packages have: sysusers writes the day into /etc/shadow
# as the day a password was last changed, and day 0 there means that it
# has to be changed.
export SOURCE_DATE_EPOCH=1728000000
root=/build/root
mkdir -p $root

# ---- What the packages have ------------------------------------------------

# Two packages with the same file would make the system depend on which
# came last; so would a path that is a directory in one and a file in
# another.
for package in $contents_packages; do
    cd $package
    for top in usr etc; do
        [ -d $top ] || continue
        find $top -type d -printf '/%p\n' >> /build/directories
        find $top ! -type d -printf '/%p\n' >> /build/files
    done
    cd /build
done
in_two_packages=$(sort files | uniq -d)
file_and_directory=$(comm -12 <(sort -u files) <(sort -u directories))
if [ -n "$in_two_packages$file_and_directory" ]; then
    echo "$in_two_packages$file_and_directory" >&2
    echo "image.sh: the paths above are in more than one package" >&2
    exit 1
fi

for package in $contents_packages; do
    for top in usr etc; do
        # --no-preserve=ownership: a build is one user, and cannot give
        # a file to the store's
        [ ! -d $package/$top ] || cp -a --no-preserve=ownership $package/$top $root/
    done
done
# a copy out of the store is read-only, as the store is
chmod -R u+w $root

# ---- bunix's own configuration, over them -----------------------------------

# What the system on x86 has and this one has the same.
if [ -n "${same_as_x86:-}" ]; then
    (cd $shared_files && cp -a --no-preserve=ownership --parents $same_as_x86 $root/)
fi
# what differs yet
cp -a --no-preserve=ownership $bunix_files/. $root/
# a copy out of the store is read-only, as the store is
chmod -R u+w $root

# whose signature on an image's hash this system takes
for certificate in ${certificates:-}; do
    # a file in the store is <hash>-<name>
    name=$(basename $certificate)
    install -D -m 644 $certificate $root/usr/lib/verity.d/${name#*-}
done
[ -z "${variant:-}" ] || echo "VARIANT_ID=$variant" >> $root/usr/lib/os-release
# The release: what updates are compared with (sysupdate.d's %A), and
# what an extension image must have been built for (as
# elements/system/rootfs.bst).
if [ -n "${version:-}" ]; then
    printf 'IMAGE_VERSION=%s\nSYSEXT_LEVEL=%s\n' $version $version >> $root/usr/lib/os-release
fi

# the links of a UAPI.9 root; /lib64 only where the loader is asked for
# there
ln -s usr/bin $root/bin
ln -s usr/bin $root/sbin
ln -s usr/lib $root/lib
case $loader in
    /lib64/*) ln -s usr/lib/$triplet $root/lib64 ;;
esac
# /sysroot: where a root partition is mounted before the system on it is
# handed over to (images/initrd.nix), and where a machine's own partition
# is, if its command line names one (tools/boot-mac.sh)
mkdir -p $root/dev $root/proc $root/sys $root/run $root/tmp $root/var $root/root $root/home $root/sysroot
chmod 1777 $root/tmp
chmod 700 $root/root

# the kernel runs /init
ln -s usr/lib/systemd/systemd $root/init

# Neither the archive's list nor systemd's files of lines can carry a
# name with a space in it.
if find $root -name '* *' | grep .; then
    echo "image.sh: the names above have a space" >&2
    exit 1
fi

# ---- What systemd's tools make of it ----------------------------------------

# The accounts the packages ask for (usr/lib/sysusers.d).  Two that ask
# for one number, under two names: sysusers would give the second
# another, and say nothing.  (One name asked for twice is not that:
# system/usr/lib/sysusers.d/00-bunix-root.conf says what it is for.)
# (u!: an account that is locked, as polkit asks for its own)
names_and_ids=$(sed -n 's/^u!\?  *\([^ ]*\)  *\([0-9][0-9]*\).*/\2 \1/p' $root/usr/lib/sysusers.d/*.conf | sort -u)
same_id=$(echo "$names_and_ids" | cut -d' ' -f1 | uniq -d)
if [ -n "$same_id" ]; then
    echo "image.sh: two accounts ask for the id $same_id" >&2
    exit 1
fi
systemd-sysusers --root=$root
# The units of the preset, and no others; and then what was enabled moved
# from /etc into /usr.  What runs belongs to the image, and is updated
# with it; and a system on a disk starts with an /etc that is empty.
systemctl --root=$root preset-all
for entry in $root/etc/systemd/system/*; do
    name=$(basename $entry)
    if [ -d $entry ] && [ ! -L $entry ]; then
        mkdir -p $root/usr/lib/systemd/system/$name
        mv $entry/* $root/usr/lib/systemd/system/$name/
        rmdir $entry
    else
        mv $entry $root/usr/lib/systemd/system/
    fi
done
# udev's hardware database, compiled
systemd-hwdb --root=$root --usr update

# ---- What a disk's /etc starts from ------------------------------------------

# A system installed on a disk has /usr from an image, read-only, and an
# /etc of its own, which starts empty.  So what this image has for /etc
# is in /usr too (after elements/system/rootfs.bst), and systemd-tmpfiles
# puts in /etc what is missing there, file by file:
#   C   a copy, made only where there is none: what a person may change,
#       and keeps through an update
#   L   a link, as it is here
#   L+  for the certificates: a link into /usr, put back at every boot,
#       so that an update of /usr brings the new ones
# Not the accounts and the machine's id, which a machine makes at its
# first boot and keeps.  A system in memory has this too, and no use for
# it: its /etc is whole.
factory=$root/usr/share/factory/etc
mkdir -p $factory
cp -a $root/etc/. $factory/
rm -f $factory/passwd* $factory/group* $factory/shadow* $factory/gshadow* \
    $factory/.pwd.lock $factory/machine-id
(
    cd $factory
    find . ! -type d | LC_ALL=C sort | sed 's|^\./||' | while read -r file; do
        case $file in
            ssl/*) echo "L+ /etc/$file - - - - /usr/share/factory/etc/$file" ;;
            *)
                if [ -L "$file" ]; then
                    echo "L /etc/$file - - - - $(readlink "$file")"
                else
                    echo "C /etc/$file"
                fi ;;
        esac
    done
) > $root/usr/lib/tmpfiles.d/bunix-etc.conf

# ---- /usr as a partition -----------------------------------------------------

# What systemd-repart makes of a partition and its contents: a read-only
# file system (erofs; LZ4HC, which is read back several times faster than
# LZMA, and /usr is read at every start of a program), and beside it the
# hashes of its blocks (dm-verity), by which the kernel checks every block
# it reads.  One number stands for all of it, the root hash: a kernel told
# that number (usrhash=) runs this /usr and no other.
#
# The hash signed is a third partition, by which what is not told the
# hash knows the image is bunix's.  It is not made here: a signature is
# made of the hash alone, afterwards, by what has the key (tools/sign.sh).
#
# In the result, for what makes a version's files of them (update.sh):
#   usr-partition/usr.raw, usr-verity.raw    the two partitions' contents
#   usr-partition/usrhash                    the root hash
#   usr-partition/version                    what their labels and their
#                                            files' names are to say
#   usr-partition/os-release                 what the system says it is,
#                                            for what starts it (uki.sh)
# Only read from the tree: the archive below is the same with or without.
mkdir -p $out
if [ -n "${usr_partition:-}" ]; then
    mkdir -p usr.d tmp images $out/usr-partition
    # SplitName: each partition as a file of its own, images/x.<name>.raw.
    # CopyFiles=/usr/:/ : /usr's contents at the top of the partition,
    # which is mounted on /usr.  No validatefs: a build cannot store the
    # attribute it marks a file system with.
    printf '%s\n' '[Partition]' 'Type=usr' 'Format=erofs' 'Compression=lz4hc' \
        'CopyFiles=/usr/:/' 'Verity=data' 'VerityMatchKey=usr' 'Minimize=best' \
        'AddValidateFS=no' 'SplitName=usr' > usr.d/10-usr.conf
    printf '%s\n' '[Partition]' 'Type=usr-verity' 'Verity=hash' 'VerityMatchKey=usr' \
        'Minimize=best' 'SplitName=usr-verity' > usr.d/20-usr-verity.conf
    # --offline: without the loop devices a build does not have.  The disk
    # repart makes around the two is not wanted, only its parts.
    TMPDIR=/build/tmp systemd-repart --empty=create --size=auto --dry-run=no --offline=yes \
        --definitions=usr.d --copy-source=$root --split=yes \
        --seed=$(printf 'bunix usr %s' $version | sha256sum | head -c 32) --json=short \
        images/x.raw > repart.json
    cp images/x.usr.raw $out/usr-partition/usr.raw
    cp images/x.usr-verity.raw $out/usr-partition/usr-verity.raw
    sed -n 's/.*"roothash":"\([0-9a-f]*\)".*/\1/p' repart.json | head -n 1 > $out/usr-partition/usrhash
    [ -s $out/usr-partition/usrhash ]
    echo $version > $out/usr-partition/version
    cp $root/usr/lib/os-release $out/usr-partition/os-release
fi

# ---- The archive -------------------------------------------------------------

# The kernel's gen_init_cpio makes it from a list, one line an entry; a
# list can name a device, which a build is not allowed to create as a
# file.  Every file is root's.
cd $root
{
    # the console, for the first messages; systemd mounts the rest
    echo "nod /dev/console 600 0 0 c 5 1"
    # Sorted: find lists a directory in whatever order the disk has it, and
    # a directory sorts before what is in it.
    find . -mindepth 1 -type d -printf 'dir /%P %m 0 0\n' | LC_ALL=C sort
    find . -type f -printf "file /%P $root/%P %m 0 0\n" | LC_ALL=C sort
    find . -type l -printf 'slink /%P %l 777 0 0\n' | LC_ALL=C sort
} > /build/list
# -t: one time for every entry, as files in the store have
gen_init_cpio -t 1 /build/list | gzip -9 -n > $out/initramfs.cpio.gz
