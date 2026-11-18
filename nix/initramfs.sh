# Packs the initramfs (initramfs.nix).  The kernel's gen_init_cpio makes
# the archive from a list of what goes in it, one line an entry; a list
# can name a device, which a build is not allowed to create as a file.
set -euo pipefail

# The few files of /etc.  PATH for /init: the contents' bin/, in order.
path=""
for package in $contents; do
    path=$path${path:+:}$package/bin
done
echo "export PATH=$path" > environment
echo "root:x:0:0:root:/root:/bin/sh" > passwd
echo "root:x:0:" > group

# The closure-* files have each store path the contents need, and the
# derivation each was built from, which is not a part of the system.
store_paths=$(cat closure-* | grep '^/nix/store/' | grep -v '\.drv$' | sort -u)

{
    echo "dir /dev 755 0 0"
    # the console, for /init's first messages; /init mounts the rest
    echo "nod /dev/console 600 0 0 c 5 1"
    for directory in /proc /sys /tmp /etc /root /bin /nix /nix/store; do
        echo "dir $directory 755 0 0"
    done
    echo "file /init $init 755 0 0"
    # where scripts, and programs that run a command line, expect a shell;
    # glibc's own scripts (ldd) ask for bash by that name
    echo "slink /bin/sh $shell/bin/bash 777 0 0"
    echo "slink /bin/bash $shell/bin/bash 777 0 0"
    for file in environment passwd group; do
        echo "file /etc/$file $PWD/$file 644 0 0"
    done

    # Every directory, file and link of every store path, where it is here.
    # Sorted: find lists a directory in whatever order the disk has it.
    for store_path in $store_paths; do
        find $store_path -type d -printf 'dir %p %m 0 0\n' | LC_ALL=C sort
        find $store_path -type f -printf 'file %p %p %m 0 0\n' | LC_ALL=C sort
        find $store_path -type l -printf 'slink %p %l 777 0 0\n' | LC_ALL=C sort
    done
} > list

# -t: one time for every entry, as files in the store have
gen_init_cpio -t 1 list | gzip -9 -n > $out
