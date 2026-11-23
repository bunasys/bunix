#!/bin/sh
# Makes what an Apple Silicon Mac is told to start, so that it starts
# bunix from its own disk with no other computer: aura's first stage,
# with the id of the Mac's ESP written into it.  bunix-install prints the
# id when it has finished on such a Mac's disk.
#
#   tools/mac-stage1.sh <id of the ESP>        makes the files
#   tools/mac-stage1.sh <id of the ESP> try    and starts the Mac with them
#                                              now, over the cable
#   tools/mac-stage1.sh <id of the ESP> put root@<the Mac's address>
#                                              (or whatever else ssh
#                                              takes for a destination)
#                                              and puts them on that ESP,
#                                              where the Mac's recovery
#                                              system can read them
#
# The chain (docs/nix-usr-system.md, "A Mac starts from its disk"):
#
#   the Mac's own firmware
#     -> aura's first stage     which the Mac is told of once, in its
#                               recovery system; made here
#     -> aurora/stage2.bin      on the ESP, put there by bunix-install:
#                               aura again, the Mac's device tree, U-Boot
#     -> systemd-boot           on the ESP, as on any machine
#
# The files, in a directory this prints:
#
#   aura-stage1.bin    the first stage, for this one ESP
#   aura.bin           the first stage for no ESP, which waits for another
#                      computer on USB as the Mac does for
#                      tools/boot-mac.sh: to go back to
#   enroll-stage1.sh   aura's own script that tells the Mac to start one
#                      of them, after checking that it may; run in the
#                      Mac's recovery system
#   enroll.sh          runs it for aura-stage1.bin, and way-back.sh for
#   way-back.sh        aura.bin: the recovery system has no way to paste
#                      the files' checksums, so these have them written in
#
# The Mac is told to start it in place of what its boot container starts
# now: the small container beside macOS that a second system starts from
# (docs/nix-usr-system.md, "On a Mac", says how a Mac gets one).  A Mac
# without one has nowhere to be told.
#
# `put` is for a Mac that runs bunix from memory (tools/boot-mac.sh) and
# is on the network, as it is when bunix-install has just finished: root
# there mounts the ESP and takes the files, into bunix-enroll/.  Without
# it they are carried to the Mac on a USB stick formatted FAT.  The
# files are not made by bunix-install itself: aura's tool that writes
# the id is Python, which the system on the Mac does not have.
#
# `try` is for a Mac that waits for this one as for tools/boot-mac.sh.
# The first stage is put into its memory, and goes on from there as it
# would from the disk: nothing on the Mac changes, and the next start is
# the old one.  What it shows is whether the rest of the chain is in
# place before the Mac is told to depend on it.
#
#   BUNIX_STAGE1_DIRECTORY   where the files are made; default
#                            bunix-mac-stage1 in $TMPDIR.  Made anew by
#                            every run.
#
# Needs: limactl with the bunix-builder VM, and python3.  For `put`,
# root's login on the Mac over SSH, which a system in memory gives the
# key it was started with (tools/boot-mac.sh).  For `try`,
# aura's tools need two Python modules, which are installed into a
# directory of their own, from the network, the first time.
set -eu

usage="usage: mac-stage1.sh <id of the ESP, as bunix-install prints it> [try | put root@<the Mac's address>]"
esp_id=${1:?$usage}
try=no
put_to=
case ${2:-} in
    "") ;;
    try) try=yes ;;
    put) put_to=${3:?$usage} ;;
    *) echo "$usage" >&2; exit 1 ;;
esac
# aura's tool takes the id in small letters only, as Linux prints it
esp_id=$(printf %s "$esp_id" | tr '[:upper:]' '[:lower:]')

# No pipe after nix-build: a failed build has to stop this script.
aura=$(limactl shell bunix-builder nix-build /bunix/nix/boot.nix -A aura --no-out-link)

stage1=${BUNIX_STAGE1_DIRECTORY:-${TMPDIR:-/tmp}/bunix-mac-stage1}
# A copy out of the store is read-only, as the store is.
[ ! -d "$stage1" ] || chmod -R u+w "$stage1"
rm -rf "$stage1"
mkdir -p "$stage1"
limactl copy -r "bunix-builder:$aura/usr/lib/aura" "$stage1/aura"
chmod -R u+w "$stage1/aura"

# The tool refuses an id that is not one, and an image that already has
# an ESP written into it.  The path is where bunix-install puts the
# second stage on the ESP.
python3 -I "$stage1/aura/tools/fill_stage1_config.py" \
    --input "$stage1/aura/aura.bin" --output "$stage1/aura-stage1.bin" \
    --esp-partuuid "$esp_id" --stage2-path aurora/stage2.bin
cp "$stage1/aura/aura.bin" "$stage1/aura/tools/enroll-stage1.sh" "$stage1/"

if [ $try = yes ]; then
    # Asked whether the modules load, not whether the directory is there:
    # an install that failed half-way leaves the directory.  (As
    # tools/boot-mac.sh; beside $stage1, which every run makes anew.)
    python=$stage1-python/bin/python
    if ! "$python" -c 'import serial, construct' 2> /dev/null; then
        rm -rf "$stage1-python"
        python3 -m venv "$stage1-python"
        "$python" -m pip install --quiet pyserial==3.5 construct==2.10.70
    fi
    # The waiting boot loader is two serial ports, named after the Mac's
    # serial number and ending in 1 and 3; the first is the one to talk
    # to.  With more than one candidate, the choice is the caller's.
    if [ -z "${AURADEVICE:-}" ]; then
        candidates=$(ls /dev/cu.usbmodem*1 2> /dev/null || true)
        case $candidates in
            "") echo "mac-stage1.sh: no boot loader is waiting on USB (no /dev/cu.usbmodem...1)" >&2; exit 1 ;;
            *"
"*) echo "mac-stage1.sh: more than one candidate; name one in AURADEVICE:" >&2; echo "$candidates" >&2; exit 1 ;;
        esac
        AURADEVICE=$candidates
    fi
    export AURADEVICE
    # --stub: the few instructions that start aura, assembled when aura
    #   was built; this Mac has no assembler for them.
    # --raw: the image as the Mac itself would be given it.
    # --vector-only: the tool does not wait for the image to answer on
    #   USB: this one goes straight on to the disk.
    "$python" "$stage1/aura/proxyclient/tools/chainload.py" \
        --stub "$stage1/aura/chainload-stub.bin" --raw --vector-only "$stage1/aura-stage1.bin"
    echo "mac-stage1.sh: look at the Mac's screen"
    exit 0
fi

new=$(md5 -q "$stage1/aura-stage1.bin")
way_back=$(md5 -q "$stage1/aura.bin")

# enroll.sh and way-back.sh: aura's script with the two files and their
# checksums named, so that what is typed in the recovery system is short.
# Each names the other file as the one to go back to, which aura's script
# insists is there.  For the recovery system's shell: bash 3.2, and no
# dirname.
# enrolling_script <its name> <the file to start> <its checksum>
#     <the file to keep> <its checksum>
enrolling_script() {
    name=$1
    to_start=$2
    its_md5=$3
    to_keep=$4
    keeps_md5=$5
    cat > "$stage1/$name" <<END
#!/bin/bash
# Made by bunix's tools/mac-stage1.sh for the ESP $esp_id.
#   bash $name [--check] <the boot container's name under /Volumes>
# To where this file is, so that it can be run by its path: the files it
# names are beside it.
case \$0 in */*) cd "\${0%/*}" || exit 1 ;; esac
exec bash enroll-stage1.sh --raw --keep $to_keep $keeps_md5 "\$@" $to_start $its_md5
END
}
enrolling_script enroll.sh aura-stage1.bin "$new" aura.bin "$way_back"
enrolling_script way-back.sh aura.bin "$way_back" aura-stage1.bin "$new"

if [ -n "$put_to" ]; then
    # Packed into a file first: a tar that failed would otherwise send
    # half an archive, or none, and nothing here would notice.
    # (COPYFILE_DISABLE, --no-xattrs: not what macOS notes about a file,
    # which its tar sends as files of their own.)
    COPYFILE_DISABLE=1 tar -C "$stage1" --no-xattrs -cf "$stage1/for-the-esp.tar" \
        aura-stage1.bin aura.bin enroll-stage1.sh enroll.sh way-back.sh
    # A system in memory has a new host key at every boot, so the key is
    # not asked about.  What is sent is no secret, and the checksum
    # printed below is for comparing with what the Mac says it has.
    #
    # On the Mac the ESP is mounted in a directory of its own that
    # nothing here ever removes, and is unmounted however this ends: a
    # run that failed half-way leaves nothing for the next to trip over.
    # Nothing on the ESP is deleted, the log of an earlier enrolment
    # (aura's script writes it beside the files) included.  The files
    # are not given their owner or mode: FAT keeps neither.
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
        -o ConnectTimeout=10 "$put_to" "
            set -eu
            mkdir -p /run/bunix-esp
            ! mountpoint -q /run/bunix-esp || umount /run/bunix-esp
            mount PARTUUID=$esp_id /run/bunix-esp
            trap 'umount /run/bunix-esp' EXIT
            mkdir -p /run/bunix-esp/bunix-enroll
            tar -xf - --no-same-owner --no-same-permissions -C /run/bunix-esp/bunix-enroll
            sync
        " < "$stage1/for-the-esp.tar"
    first_step="The files are on the Mac's ESP, in bunix-enroll/."
    what_to_mount="bunix's ESP: of the type EFI, and the one the installer
     was told of or made (a Mac may have another system's as well)"
    their_directory="/Volumes/<the name it is mounted by>/bunix-enroll"
else
    first_step="Copy the five files to a USB stick formatted FAT.  (Or have them
     put on the Mac's ESP while it runs bunix from memory:
     tools/mac-stage1.sh $esp_id put root@<its address>.)"
    what_to_mount="the stick, if it is not mounted already"
    their_directory="/Volumes/<the name it is mounted by>"
fi

cat <<END

In $stage1:
  aura-stage1.bin    starts bunix from the ESP $esp_id
                     (MD5 $new)
  aura.bin           the way back: waits for another computer on USB
                     (MD5 $way_back)
  enroll-stage1.sh, enroll.sh, way-back.sh

To have the Mac start aura-stage1.bin:
  1. $first_step
  2. In macOS, System Settings > General > Startup Disk: choose the boot
     container, the small volume a second system starts from (the one
     the Asahi installer made).  NOT Macintosh HD: the Mac's recovery
     system changes what the chosen startup disk starts.
  3. Shut the Mac down.  Hold its power button until "Loading startup
     options", choose Options, and log in.
  4. Utilities > Terminal.  Mount $what_to_mount:
       diskutil list
       diskutil mount <its name there, as disk0s5>
  5. Check, then do.  <volume> is the boot container's name under
     /Volumes, in quotes if it has a space:
       bash $their_directory/enroll.sh --check <volume>
       bash $their_directory/enroll.sh <volume>
     Each prints the MD5 of aura-stage1.bin as it found it: it is the
     one above.

If the script says the recovery system is not paired with the volume,
step 2 was not done.  If it asks for "bputil -nc" to be run first, stop
unless <volume> is the boot container: that command lowers the security
of the volume it names, which must never be macOS's own.

What the Mac starts now stays what it starts until step 5's second line
has succeeded.  From then on it no longer waits for tools/boot-mac.sh.
To go back to waiting, the same steps with the other script:
       bash $their_directory/way-back.sh <volume>
aura.bin has not been tried as what a Mac starts by itself: until now
the one waiting was Asahi's m1n1, and aura was loaded by it.
END
