# Makes the image of images/system.nix: the root of the system as a tree,
# and then that tree as an archive.
#
# $contents_packages is the store path of every package the system has
# (stage.nix).  The archive gets their files; it never names where they
# came from.
set -euo pipefail
cd /build
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
    echo "system.sh: the paths above are in more than one package" >&2
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

# What the system on x86 has and this one has the same; what is not
# listed is not here.  machine-id is empty: the machine has a new id at
# every boot, unless its command line gives it one, and systemd does not
# take the boot for a first one.
same_as_x86="
    etc/hostname
    etc/hosts
    etc/nsswitch.conf
    etc/shells
    etc/machine-id
    etc/os-release
    etc/resolv.conf
    etc/iwd/main.conf
    usr/lib/os-release
    usr/lib/systemd/network/20-wired.network
    usr/lib/systemd/network/25-wireless.network
    usr/lib/systemd/resolved.conf.d/bunix.conf
    usr/lib/systemd/timesyncd.conf.d/bunix.conf
    usr/lib/systemd/system/console-shell@.service
    usr/lib/systemd/system/systemd-sysusers.service.d/bunix.conf
"
(cd $shared_files && cp -a --no-preserve=ownership --parents $same_as_x86 $root/)
# what differs yet
cp -a --no-preserve=ownership $bunix_files/. $root/
# a copy out of the store is read-only, as the store is
chmod -R u+w $root
# root has no password and is not locked: sshd, without PAM, lets no key
# in for an account that is, and sysusers would make it so
chmod 600 $root/etc/shadow
install -m 755 $usb_link $root/usr/lib/bunix/usb-link

# the links of a UAPI.9 root; /lib64 only where the loader is asked for
# there
ln -s usr/bin $root/bin
ln -s usr/bin $root/sbin
ln -s usr/lib $root/lib
case $loader in
    /lib64/*) ln -s usr/lib/$triplet $root/lib64 ;;
esac
# /sysroot: where a machine's own partition is mounted, if its command
# line names one (tools/boot-mac.sh)
mkdir -p $root/dev $root/proc $root/sys $root/run $root/tmp $root/var $root/root $root/home $root/sysroot
chmod 1777 $root/tmp
chmod 700 $root/root

# the kernel runs /init
ln -s usr/lib/systemd/systemd $root/init

# ---- What systemd's tools make of it ----------------------------------------

# The accounts the packages ask for (usr/lib/sysusers.d).  Two that ask
# for one number, under two names: sysusers would give the second
# another, and say nothing.  (One name asked for twice is the first
# asking's, which is how root's shell is said here.)
names_and_ids=$(sed -n 's/^u  *\([^ ]*\)  *\([0-9][0-9]*\).*/\2 \1/p' $root/usr/lib/sysusers.d/*.conf | sort -u)
same_id=$(echo "$names_and_ids" | cut -d' ' -f1 | uniq -d)
if [ -n "$same_id" ]; then
    echo "system.sh: two accounts ask for the id $same_id" >&2
    exit 1
fi
# sysusers writes the day into /etc/shadow, as when a password was last
# changed: a fixed day, for an image that is the same whenever it is made
# (not day 0, which means the password has to be changed).
SOURCE_DATE_EPOCH=1728000000 systemd-sysusers --root=$root
# the units of the preset, and no others
systemctl --root=$root preset-all
# udev's hardware database, compiled
systemd-hwdb --root=$root --usr update

# ---- The archive -------------------------------------------------------------

# The kernel's gen_init_cpio makes it from a list, one line an entry; a
# list can name a device, which a build is not allowed to create as a
# file.  Every file is root's.
if find $root -name '* *' | grep .; then
    echo "system.sh: the list cannot carry the names above, which have a space" >&2
    exit 1
fi
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
mkdir -p $out
# -t: one time for every entry, as files in the store have
gen_init_cpio -t 1 /build/list | gzip -9 -n > $out/initramfs.cpio.gz
