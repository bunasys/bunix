# Packs the initramfs (initramfs.nix).  The kernel's gen_init_cpio makes
# the archive from a list of what goes in it, one line an entry; a list
# can name a device, which a build is not allowed to create as a file.
#
# $contents_packages is the store path of every package the system has
# (stage.nix).  The archive gets their files; it never names where they
# came from.
set -euo pipefail
cd /build

echo "root:x:0:0:root:/root:/bin/sh" > passwd
echo "root:x:0:" > group

# Every directory, file and link of each package's usr/ and etc/, at the
# path it has in the system.  ("dir <path> <mode> <uid> <gid>", "file <path>
# <from> <mode> <uid> <gid>", "slink <path> <target> <mode> <uid> <gid>".)
: > directories
: > others
for package in $contents_packages; do
    cd $package
    for top in usr etc; do
        [ -d $top ] || continue
        find $top -type d -printf 'dir /%p %m 0 0\n' >> /build/directories
        find $top -type f -printf "file /%p $package/%p %m 0 0\n" >> /build/others
        find $top -type l -printf 'slink /%p %l 777 0 0\n' >> /build/others
    done
    cd /build
done

# Two packages with the same file would make the system depend on which
# came last.
in_two_packages=$(cut -d' ' -f2 others | sort | uniq -d)
if [ -n "$in_two_packages" ]; then
    echo "$in_two_packages" >&2
    echo "initramfs.sh: the paths above are in more than one package" >&2
    exit 1
fi

{
    echo "dir /dev 755 0 0"
    # the console, for /init's first messages; /init mounts the rest
    echo "nod /dev/console 600 0 0 c 5 1"
    for directory in /proc /sys /tmp /run /var /root /etc /usr; do
        echo "dir $directory 755 0 0"
    done

    # the links of a UAPI.9 root; /lib64 only where the loader is asked for
    # there
    echo "slink /bin usr/bin 777 0 0"
    echo "slink /sbin usr/bin 777 0 0"
    echo "slink /lib usr/lib 777 0 0"
    case $loader in
        /lib64/*) echo "slink /lib64 usr/lib/$triplet 777 0 0" ;;
    esac

    echo "file /init $init 755 0 0"
    echo "file /etc/passwd /build/passwd 644 0 0"
    echo "file /etc/group /build/group 644 0 0"

    # Sorted: find lists a directory in whatever order the disk has it.  A
    # directory sorts before what is in it, and each is listed once however
    # many packages have it.
    LC_ALL=C sort -u directories | grep -v -x -e 'dir /etc 755 0 0' -e 'dir /usr 755 0 0'
    LC_ALL=C sort others
} > list

# -t: one time for every entry, as files in the store have
gen_init_cpio -t 1 list | gzip -9 -n > $out/initramfs.cpio.gz
