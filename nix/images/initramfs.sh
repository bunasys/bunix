# Packs the initramfs (initramfs.nix).  The kernel's gen_init_cpio makes
# the archive from a list of what goes in it, one line an entry:
#
#   dir <path> <mode> <uid> <gid>
#   file <path> <where to copy it from> <mode> <uid> <gid>
#   slink <path> <target> <mode> <uid> <gid>
#   nod <path> <mode> <uid> <gid> <type> <major> <minor>
#
# A list can name a device, which a build is not allowed to create as a
# file.
#
# $contents_packages is the store path of every package the system has
# (stage.nix).  The archive gets their files; it never names where they
# came from.
set -euo pipefail
cd /build

# ---- The few files that are the system's, not a package's ------------------

# The accounts: root, and those the packages ask for.  A package that
# needs one says so in a file of /usr/lib/sysusers.d, in systemd's format:
#
#   u <name> <id> "<description>" <home>
account='^u +([a-z_][a-z0-9_-]*) +([1-9][0-9]*) +"([^":]*)" +(/[^[:space:]:]*)$'
# systemd-sysusers is what reads those when a system has it.  This one
# does not yet, so they are read here, and only lines of that one shape:
# the id written out, and a group of the same name and id.
echo "root:x:0:0:root:/root:/bin/sh" > passwd
echo "root:x:0:" > group
for package in $contents_packages; do
    for declarations in $package/usr/lib/sysusers.d/*.conf; do
        [ -e $declarations ] || continue
        # `|| [ -n ... ]`: a last line that does not end in a newline
        while read -r line || [ -n "$line" ]; do
            case $line in ''|'#'*) continue ;; esac
            if ! [[ $line =~ $account ]]; then
                echo "initramfs.sh: $declarations: not an account this can make: $line" >&2
                exit 1
            fi
            name=${BASH_REMATCH[1]}
            id=${BASH_REMATCH[2]}
            description=${BASH_REMATCH[3]}
            home=${BASH_REMATCH[4]}
            echo "$name:x:$id:$id:$description:$home:/usr/bin/false" >> passwd
            echo "$name:x:$id:" >> group
        done < $declarations
    done
done
# By id: the packages come in the order of their store paths, which says
# nothing.
sort -t: -k3,3n -o passwd passwd
sort -t: -k3,3n -o group group
same_name=$(cut -d: -f1 passwd | sort | uniq -d)
if [ -n "$same_name" ]; then
    echo "initramfs.sh: the account $same_name is asked for twice" >&2
    exit 1
fi
same_id=$(cut -d: -f3 passwd | sort | uniq -d)
if [ -n "$same_id" ]; then
    echo "initramfs.sh: the id $same_id is asked for twice" >&2
    exit 1
fi
echo "127.0.0.1 localhost" > hosts
# where glibc looks up users and host names: the files above, then DNS
printf '%s\n' "passwd: files" "group: files" "hosts: files dns" > nsswitch.conf
printf '%s\n' 'NAME="bunix"' 'PRETTY_NAME="bunix (Buna Linux)"' 'ID=bunix' > os-release
system_files="passwd group hosts nsswitch.conf os-release"

# ---- What the packages have ------------------------------------------------

# Every directory, file and link of each package's usr/ and etc/, at the
# path it has in the system.  A file in the store is read-only, to
# everyone; in the system it is root's to change.
: > directories
: > files
: > links
for package in $contents_packages; do
    cd $package
    for top in usr etc; do
        [ -d $top ] || continue
        find $top -type d -printf '/%p\n' >> /build/directories
        find $top -type f -perm -u+x -printf "/%p $package/%p 755\n" >> /build/files
        find $top -type f ! -perm -u+x -printf "/%p $package/%p 644\n" >> /build/files
        find $top -type l -printf '/%p %l\n' >> /build/links
    done
    cd /build
done

# Two packages with the same file would make the system depend on which
# came last; so would a path that is a directory in one and a file in
# another.
cut -d' ' -f1 files links | sort > paths
in_two_packages=$(uniq -d paths)
file_and_directory=$(comm -12 <(uniq paths) <(sort -u directories))
if [ -n "$in_two_packages$file_and_directory" ]; then
    echo "$in_two_packages$file_and_directory" >&2
    echo "initramfs.sh: the paths above are in more than one package" >&2
    exit 1
fi

# ---- The list ----------------------------------------------------------------

# the directories every system has, whichever packages are in it
printf '%s\n' /dev /proc /sys /tmp /run /root /home /etc /usr \
    /var /var/lib /var/log /var/tmp >> directories

{
    # Sorted: find lists a directory in whatever order the disk has it.  A
    # directory sorts before what is in it, and each is listed once however
    # many packages have it.
    LC_ALL=C sort -u directories | while read -r directory; do
        echo "dir $directory 755 0 0"
    done

    # the console, for /init's first messages; /init mounts the rest
    echo "nod /dev/console 600 0 0 c 5 1"

    # the links of a UAPI.9 root; /lib64 only where the loader is asked for
    # there
    echo "slink /bin usr/bin 777 0 0"
    echo "slink /sbin usr/bin 777 0 0"
    echo "slink /lib usr/lib 777 0 0"
    case $loader in
        /lib64/*) echo "slink /lib64 usr/lib/$triplet 777 0 0" ;;
    esac

    echo "file /init $init 755 0 0"
    for file in $system_files; do
        echo "file /etc/$file /build/$file 644 0 0"
    done

    LC_ALL=C sort files | while read -r path from mode; do
        echo "file $path $from $mode 0 0"
    done
    LC_ALL=C sort links | while read -r path target; do
        echo "slink $path $target 777 0 0"
    done
} > list

# -t: one time for every entry, as files in the store have
gen_init_cpio -t 1 list | gzip -9 -n > $out/initramfs.cpio.gz
