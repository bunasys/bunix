# Makes an extension's file system and the hashes of its blocks
# (images/extension.nix, `parts`).
#
#   $contents_packages   the store path of every package the extension
#                        brings, and of all they need to run (stage.nix)
#   $system_image        the result of images/system.nix, for the list of
#                        what /usr has already (usr-paths)
#   $without             paths under usr/ to leave out: files, or
#                        directories with all they hold
#   $keep                paths under usr/ to keep of what is stripped
#   $links               names to add, each name=program, the name a path
#                        under usr/
#   $set_user_id         programs of usr/bin that run as root whoever
#                        starts them
#   $gsettings_schemas   yes for the one extension whose GSettings
#                        schemas are compiled
#   $extension, $version, $partition_architecture
set -euo pipefail
cd /build

# ---- The tree ----------------------------------------------------------------

# Only usr/: an extension is laid over /usr, and nothing else of it is
# looked at.
tree=/build/tree
mkdir -p $tree
# Two packages with the same file would make the extension depend on
# which came last (as images/image.sh, which checks the system's
# packages; not all of these are among them).
for package in $contents_packages; do
    [ ! -d $package/usr ] || (cd $package && find usr ! -type d) >> /build/files
done
in_two_packages=$(sort files | uniq -d)
if [ -n "$in_two_packages" ]; then
    echo "$in_two_packages" >&2
    echo "extension-parts.sh: the paths above are in more than one package" >&2
    exit 1
fi
for package in $contents_packages; do
    # --no-preserve=ownership: a build is one user, and cannot give a
    # file to the store's
    [ ! -d $package/usr ] || cp -a --no-preserve=ownership $package/usr $tree/
done
# a copy out of the store is read-only, as the store is
chmod -R u+w $tree

# Paths the system has stay the system's: most of what these packages
# need to run is there already, and of the same build.
cd $tree
while read -r path; do
    rm -f "./$path"
done < $system_image/usr-paths

# Documentation and translations; and what is for building software
# against the extension's own packages: headers, static libraries, and
# what tells a build where they are.  An extension that is for building
# software says which of these it keeps ($keep: the compiler's own), and
# they are set aside while the rest goes.
cd $tree/usr
mkdir /build/kept
for path in $keep; do
    [ -e "$path" ] || { echo "extension-parts.sh: nothing to keep at usr/$path" >&2; exit 1; }
    mkdir -p "/build/kept/$(dirname "$path")"
    mv "$path" "/build/kept/$path"
done
rm -rf include lib/*/pkgconfig lib/*/cmake share/pkgconfig share/aclocal \
       share/man share/info share/doc share/locale share/bash-completion share/zsh
find lib -maxdepth 2 -name '*.a' -delete
# and back, now that the rest is gone
cp -a /build/kept/. .
# and what the extension's own list says.  A path that is not there is a
# mistake in the list, or a package that moved what the list names: what
# it meant to leave out would be back without a word.
for path in $without; do
    [ -e "./$path" ] || [ -L "./$path" ] || { echo "extension-parts.sh: usr/$path is not there to leave out" >&2; exit 1; }
    rm -rf "./$path"
done
find . -type d -empty -delete
# Names it adds, each for a program that is there: a name the extension
# or the system has already, or one for a program that is not there, is
# a mistake in the list.
for link in $links; do
    name=${link%%=*}
    program=${link#*=}
    if [ -e "$name" ] || [ -L "$name" ] || grep -q -x -F "usr/$name" $system_image/usr-paths; then
        echo "extension-parts.sh: usr/$name is there already, and cannot be a new name" >&2
        exit 1
    fi
    ln -s "$program" "$name"
    [ -e "$name" ] || { echo "extension-parts.sh: usr/$name would be a name for $program, which is not there" >&2; exit 1; }
done

# The GSettings schemas the extension brings, compiled: GLib reads only
# the compiled file, and stops a program that asks for a schema not in it
# (GTK 4's file dialog does).  One compiled file hides any other in the
# merged /usr: so one extension has schemas, the one that says so
# ($gsettings_schemas), and the system none.
schemas=$tree/usr/share/glib-2.0/schemas
extension_has_schemas=no
if compgen -G "$schemas/*.gschema.xml" > /dev/null; then
    extension_has_schemas=yes
fi
system_has_schemas=no
if grep -q -E '^usr/share/glib-2\.0/schemas/.*\.(gschema\.xml|gschema\.override|compiled)$' $system_image/usr-paths; then
    system_has_schemas=yes
fi
if [ $extension_has_schemas = yes ]; then
    if [ "$gsettings_schemas" != yes ]; then
        echo "extension-parts.sh: $extension has GSettings schemas, and does not say so (gsettings_schemas)" >&2
        exit 1
    fi
    if [ $system_has_schemas = yes ]; then
        echo "extension-parts.sh: the system has GSettings schemas, which the extension's compiled file would hide" >&2
        exit 1
    fi
    glib-compile-schemas --strict $schemas
fi

# Every system service the extension brings is started by something: a
# target that upholds it (one Upholds= line a service), a socket of its
# own, or a udev rule of the extension's that asks for it when a device
# shows (SYSTEMD_WANTS, not in a comment: speakersafetyd's).  The .wants
# links an extension could carry are read before it is merged, so a
# service started by none of these would never start (docs/desktop.md,
# "Units in an extension").  A template (name@.service) is started by
# name, by what needs it; a link to /dev/null is a unit masked, which
# nothing is to start.  User services are not checked: a person's systemd
# starts after the merge, and reads their .wants links.
units=$tree/usr/lib/systemd/system
# the extension's udev rules, without their comments (upstream's
# speakersafetyd rule has lines for Macs it does not start on yet)
cat "$tree"/usr/lib/udev/rules.d/*.rules 2> /dev/null | grep -v '^[[:space:]]*#' > /build/udev-rules || true
for unit in "$units"/*.service; do
    [ -e "$unit" ] || continue
    service=${unit##*/}
    case $service in *@.service) continue ;; esac
    [ "$(readlink "$unit")" != /dev/null ] || continue
    # upheld by a target
    grep -q -x -h "Upholds=$service" "$units"/*.target.d/*.conf 2> /dev/null && continue
    # started by its socket
    [ -e "$units/${service%.service}.socket" ] && continue
    # asked for by a udev rule
    grep -q -F "SYSTEMD_WANTS}=\"$service\"" /build/udev-rules && continue
    echo "extension-parts.sh: nothing starts the system service $service: no target upholds it, it has no socket, and no udev rule asks for it" >&2
    exit 1
done

# sysext merges this only into the version it was built for (SYSEXT_LEVEL
# in the system's os-release, images/image.sh), on the architecture it is
# of.
mkdir -p $tree/usr/lib/extension-release.d
# EXTENSION_RELOAD_MANAGER: systemd reads its units again after a merge:
# an extension may bring some (Nix's daemon).
printf 'ID=bunix\nSYSEXT_LEVEL=%s\nARCHITECTURE=%s\nEXTENSION_RELOAD_MANAGER=1\n' \
    $version $partition_architecture \
    > $tree/usr/lib/extension-release.d/extension-release.$extension
cd /build
du -sh $tree/usr

# ---- The file system, and its hashes -------------------------------------------

# As /usr's own (images/image.sh, "/usr as a partition"): erofs of a tar
# file, where every file is root's and of the time files in the store
# have; and repart for the hashes, without the loop devices a build does
# not have.  LZ4HC, where x86's extensions are LZMA: these programs are
# read at every start, as /usr's are, and the image is a few megabytes
# larger for it.  The signature is made of the root hash alone,
# afterwards (images/extension.sh).
# Set-user-id programs, as images/image.sh has /usr's (its "/usr as a
# partition"): a build cannot chmod them so, and they go into the tar
# file after the rest, with their mode.  Each is a program of usr/bin.
set_user_id_mode=4755
for program in $set_user_id; do
    case $program in
        usr/bin/*) is_in_usr_bin=yes ;;
        *) is_in_usr_bin=no ;;
    esac
    is_a_file=no
    if [ -f $tree/$program ] && [ ! -L $tree/$program ]; then
        is_a_file=yes
    fi
    if [ $is_in_usr_bin = no ] || [ $is_a_file = no ]; then
        echo "extension-parts.sh: set_user_id names $program, which is not a program in usr/bin" >&2
        exit 1
    fi
done
mkdir -p root.d tmp images $out
to_root_tar() {
    tar -C $tree --sort=name --owner=0 --group=0 --numeric-owner --mtime=@1 "$@"
}
programs=
without_programs=
for program in $set_user_id; do
    programs="$programs ./$program"
    without_programs="$without_programs --exclude=./$program"
done
to_root_tar --anchored $without_programs -cf root.tar .
if [ -n "$programs" ]; then
    to_root_tar --mode=$set_user_id_mode -rf root.tar $programs
fi
# one line a program, and the s in it: a list that tar did not take as
# meant would otherwise be found out on a running system, or not
for program in $programs; do
    if ! tar -tvf root.tar $program | grep -q '^-rwsr-xr-x '; then
        echo "extension-parts.sh: $program is not set-user-id in root.tar" >&2
        exit 1
    fi
done
digits=$(printf 'bunix %s file system %s' $extension $version | sha256sum | head -c 32)
file_system_id=${digits:0:8}-${digits:8:4}-${digits:12:4}-${digits:16:4}-${digits:20:12}
mkfs.erofs --quiet -zlz4hc -U $file_system_id --tar=f root.erofs root.tar
printf '%s\n' '[Partition]' 'Type=root' 'CopyBlocks=/build/root.erofs' \
    'Verity=data' 'VerityMatchKey=root' 'SplitName=root' > root.d/10-root.conf
printf '%s\n' '[Partition]' 'Type=root-verity' 'Verity=hash' 'VerityMatchKey=root' \
    'Minimize=best' 'SplitName=root-verity' > root.d/20-root-verity.conf
TMPDIR=/build/tmp systemd-repart --empty=create --size=auto --dry-run=no --offline=yes \
    --definitions=root.d --split=yes \
    --seed=$(printf 'bunix %s %s' $extension $version | sha256sum | head -c 32) --json=short \
    images/x.raw > repart.json
cp images/x.root.raw $out/root.raw
cp images/x.root-verity.raw $out/root-verity.raw
sed -n 's/.*"roothash":"\([0-9a-f]*\)".*/\1/p' repart.json | head -n 1 > $out/roothash
[ -s $out/roothash ]
