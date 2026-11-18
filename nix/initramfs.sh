# Packs the initramfs (initramfs.nix).  The kernel's gen_init_cpio makes
# the archive from a list of what goes in it, one line an entry; a list
# can name a device, which a build is not allowed to create as a file.
set -eu

# /init, with the shell that runs it and the PATH it starts with
path=""
for package in $contents; do
    path=$path${path:+:}$package/bin
done
{
    echo "#!$shell/bin/bash"
    echo "export PATH=$path"
    cat $init
} > init

# The closure-* files have each store path the contents need, and the
# derivation each was built from, which is not a part of the system.
store_paths=$(cat closure-* | grep '^/nix/store/' | grep -v '\.drv$' | sort -u)

{
    echo "dir /dev 755 0 0"
    # the console, for /init's first messages; the kernel fills in the rest
    echo "nod /dev/console 600 0 0 c 5 1"
    for directory in /proc /sys /tmp /etc /nix /nix/store; do
        echo "dir $directory 755 0 0"
    done
    echo "file /init $PWD/init 755 0 0"

    # every directory, file and link of every store path, where it is here
    for store_path in $store_paths; do
        find $store_path -type d -printf 'dir %p %m 0 0\n'
        find $store_path -type f -printf 'file %p %p %m 0 0\n'
        find $store_path -type l -printf 'slink %p %l 777 0 0\n'
    done
} > list

# -t: one time for every entry, as files in the store have
gen_init_cpio -t 1 list | gzip -9 -n > $out
