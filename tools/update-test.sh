#!/bin/sh
# Tests that a bunix on a disk updates itself, and goes back from an update
# that does not start (docs/updates.md, step 2), in a virtual machine on an
# Apple Silicon Mac:
#
#   tools/update-test.sh
#
# Three versions are built: the release's (nix/release.nix), which is
# installed on the disk; a next one, which is the same system under a later
# version; and a broken one, later still, whose kernel image names a /usr
# that is not the one published with it, so it cannot start.  The Mac serves
# their files, and the machine is told to look there.  Then:
#
#   1. the installed version refuses the next one while its list of files
#      is not signed; told not to ask, it updates: the next /usr goes into
#      the empty slot, its kernel image beside the old one, with three tries
#   2. the machine restarts into the next version, from the second slot,
#      and marks it good once all of it has started
#   3. it updates to the broken one, over the first slot
#   4. the broken one is started three times, and does not come up
#   5. the fourth start is the next version again, and the broken one is
#      marked bad
#
# NOT tested here: an update whose list of files is signed by the release
# key.  The system has nothing yet that checks an OpenPGP signature (sqv,
# as x86 has), so it refuses every update, which step 1 sees, and is then
# told not to ask (Verify=no).
#
#   BUNIX_SSH_KEY    the public key the test logs in with; default
#                    ~/.ssh/id_ed25519.pub
#   BUNIX_SSH_PORT   the Mac's port for the machine's SSH; default 2022
#   BUNIX_HTTP_PORT  the Mac's port the files are served on; default 8643
#
# Needs: what tools/boot-vm.sh needs, and python3 (the server).
set -eu

ssh_port=${BUNIX_SSH_PORT:-2022}
http_port=${BUNIX_HTTP_PORT:-8643}
public_key_file=${BUNIX_SSH_KEY:-$HOME/.ssh/id_ed25519.pub}
if [ ! -f "$public_key_file" ]; then
    echo "update-test.sh: no public key in $public_key_file to log in with" >&2
    exit 1
fi

# nix-build prints the store path of what it built, and nothing else, on
# its standard output.  No pipe after it: a failed build has to stop this
# script.
build() {
    limactl shell bunix-builder nix-build "$@" --no-out-link
}
fail() {
    echo "update-test.sh: FAILED: $*" >&2
    echo "the machine's console is in $work/console.log" >&2
    exit 1
}

# A machine of tools/boot-vm.sh still running has the SSH port, and would
# answer in place of this test's, and be updated in its stead.
for port in $ssh_port $http_port; do
    if nc -z 127.0.0.1 "$port" 2> /dev/null; then
        echo "update-test.sh: port $port of this Mac is in use" >&2
        exit 1
    fi
done

# the version, as Nix prints a string: in quotes
installed=$(limactl shell bunix-builder nix-instantiate --eval /bunix/nix/release.nix)
installed=${installed#\"}
installed=${installed%\"}
next=$installed.1
broken=$installed.2

work=${TMPDIR:-/tmp}/bunix-update-test
rm -rf "$work"
mkdir -p "$work/served/next" "$work/served/broken"

# ---- The three versions --------------------------------------------------------

# Small slots: less to build and copy (as tools/boot-vm.sh).
echo "building $installed (the disk), $next and $broken (updates)"
disk=$(build /bunix/nix/images/disk.nix --argstr espSize 512M \
    --argstr usrSlotSize 512M --argstr usrVeritySize 8M)
next_update=$(build /bunix/nix/images/update.nix --argstr version "$next")
broken_update=$(build /bunix/nix/images/update.nix --argstr version "$broken")
# The kernel image of another system of the broken version: one for
# release, whose /usr differs (it takes fewer certificates), and so its
# hash.  No partition will have the ids that image looks for.
stray_uki=$(build /bunix/nix/images/uki.nix --argstr version "$broken" --argstr signing release)

limactl copy "bunix-builder:$disk/disk.raw" "$work/disk.raw"
# copied out of the store, where nothing can be written; and with room
# after its partitions for the root partition the first boot makes
chmod u+w "$work/disk.raw"
truncate -s +2G "$work/disk.raw"

limactl copy -r "bunix-builder:$next_update/." "$work/served/next/"
limactl copy -r "bunix-builder:$broken_update/." "$work/served/broken/"
chmod -R u+w "$work/served"
broken_uki=$(basename "$work"/served/broken/*.efi)
rm "$work/served/broken/$broken_uki"
limactl copy "bunix-builder:$stray_uki/bunix_$broken.efi" "$work/served/broken/$broken_uki"

# The list a machine reads to learn what there is: each file and its hash.
for served in next broken; do
    (cd "$work/served/$served" && shasum -a 256 * > SHA256SUMS)
done

python3 -m http.server "$http_port" --bind 127.0.0.1 --directory "$work/served" \
    > "$work/server.log" 2>&1 &
server=$!
qemu=
# however this script ends, neither stays behind it, holding its port
trap 'kill $server $qemu 2> /dev/null || true' EXIT

# ---- The machine ---------------------------------------------------------------

# One run of QEMU is one start of the machine: it ends when the machine
# restarts or powers off (-no-reboot), and the disk is the same file for
# the next.  As tools/boot-vm.sh starts a disk: EFI firmware, and the
# words for the kernel handed over the way a machine's firmware does.
key_word="systemd.set_credential_binary=bunix.authorized_keys:$(base64 < "$public_key_file" | tr -d '\n')"
firmware=$(dirname "$(command -v qemu-system-aarch64)")/../share/qemu/edk2-aarch64-code.fd
start_machine() {
    # QEMU reads a single comma as the end of the value
    smbios_words=$(printf %s "console=ttyAMA0 quiet $key_word" | sed 's/,/,,/g')
    qemu-system-aarch64 -M virt -accel hvf -cpu host -smp 4 -m 4G \
        -netdev "user,id=net,hostfwd=tcp:127.0.0.1:$ssh_port-:22" -device virtio-net-pci,netdev=net \
        -nographic -no-reboot -bios "$firmware" \
        -drive "file=$work/disk.raw,format=raw,if=virtio" \
        -smbios "type=11,value=io.systemd.stub.kernel-cmdline-extra=$smbios_words" \
        < /dev/null >> "$work/console.log" 2>&1 &
    qemu=$!
}
in_guest() {
    ssh -p "$ssh_port" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=3 -o LogLevel=ERROR root@127.0.0.1 "$@"
}
# answers_within <seconds>: does the machine take a login in that time?
answers_within() {
    deadline=$(($(date +%s) + $1))
    until in_guest true 2> /dev/null; do
        machine_is_gone=no
        kill -0 $qemu 2> /dev/null || machine_is_gone=yes
        if [ $machine_is_gone = yes ] || [ "$(date +%s)" -ge $deadline ]; then
            return 1
        fi
        sleep 2
    done
}
# A start that is to work: waits until systemd has started everything, and
# says which version runs.
start_and_expect() {
    expected=$1
    start_machine
    answers_within 90 || fail "the machine did not answer on SSH; $expected was to start"
    state=$(in_guest systemctl is-system-running --wait || true)
    running=$(in_guest "sed -n 's/^IMAGE_VERSION=//p' /usr/lib/os-release")
    echo "  started: bunix $running, systemd $state"
    [ "$running" = "$expected" ] || fail "bunix $running started, not $expected"
    [ "$state" = running ] || fail "not all of bunix $running started: $state"
}
# stop_machine <reboot|poweroff>: ends this run of the machine, the way a
# person would.  After a reboot the next run is the machine restarted.
stop_machine() {
    in_guest systemctl "$1" || true
    deadline=$(($(date +%s) + 60))
    while kill -0 $qemu 2> /dev/null; do
        [ "$(date +%s)" -lt $deadline ] || fail "the machine was told to $1, and is still running"
        sleep 1
    done
}
# What a machine is told, in /etc, in place of the files in /usr of the
# same names: where the updates are.  (Path=https: the line that says
# where from; the one that says where to has a Path= too.)
look_for_updates_in() {
    in_guest "mkdir -p /etc/sysupdate.d && cd /usr/lib/sysupdate.d && for file in *.transfer; do
        sed -e 's#^Path=https.*#Path=http://10.0.2.2:$http_port/$1/#' \$file > /etc/sysupdate.d/\$file
    done"
}
# and (see the top) not to ask for the signature of the list of files
do_not_ask_for_signatures() {
    in_guest "sed -i -e 's#^\[Transfer\]#[Transfer]\nVerify=no#' /etc/sysupdate.d/*.transfer"
}
# try_update <name of its log>: to whatever is newest where the machine
# was last told to look
try_update() {
    in_guest /usr/lib/systemd/systemd-sysupdate update > "$work/update-$1.log" 2>&1
}
update() {
    try_update "$1" || fail "the update did not go through; see $work/update-$1.log"
}
# expect_kernel_image <file name> <what is wrong if it is not there>
expect_kernel_image() {
    kernel_images=$(in_guest ls /boot/EFI/Linux) || fail "could not list the machine's kernel images"
    echo "$kernel_images" | grep -q -x -F "$1" || fail "$2; there are:" $kernel_images
}

# ---- The test ------------------------------------------------------------------

echo "1. $installed updates to $next"
start_and_expect "$installed"
look_for_updates_in next
if try_update unsigned; then
    fail "an update whose list of files is not signed was taken"
fi
grep -q 'cannot verify' "$work/update-unsigned.log" \
    || fail "the update failed, but not for want of a signature; see $work/update-unsigned.log"
kernel_images=$(in_guest ls /boot/EFI/Linux) || fail "could not list the machine's kernel images"
case $kernel_images in
    *"$next"*) fail "a kernel image of $next was written before its list was checked" ;;
esac
echo "  refused while its list of files is unsigned"
do_not_ask_for_signatures
update next
expect_kernel_image "bunix_$next+3-0.efi" "no kernel image of $next with three tries"
in_guest lsblk -n -o PARTLABEL | grep -q -x -F "bunix_$next" \
    || fail "no /usr partition labelled bunix_$next"

echo "2. restart into $next"
stop_machine reboot
start_and_expect "$next"
# Marked good, and for the reason the system gives (no unit failed), not
# only because nothing asked: the tries are gone from its name.
in_guest systemctl is-active --quiet systemd-boot-check-no-failures.service \
    || fail "nothing checked that all of $next started before its boot was marked good"
in_guest systemctl is-active --quiet systemd-bless-boot.service \
    || fail "the boot of $next was not marked good"
expect_kernel_image "bunix_$next.efi" "$next still has tries in its name"

echo "3. $next updates to $broken, which cannot start"
look_for_updates_in broken
do_not_ask_for_signatures
update broken
expect_kernel_image "bunix_$broken+3-0.efi" "no kernel image of $broken with three tries"

echo "4. $broken is tried three times"
stop_machine reboot
for try in 1 2 3; do
    start_machine
    # A start that works answers in about 15 s; this one waits for a /usr
    # that is not there, with nobody to tell.
    if answers_within 45; then
        fail "a system started on try $try of $broken"
    fi
    echo "  try $try: did not come up"
    kill $qemu 2> /dev/null || true
    wait $qemu 2> /dev/null || true
done

echo "5. the machine goes back to $next"
start_and_expect "$next"
expect_kernel_image "bunix_$broken+0-3.efi" "$broken is not marked bad"

stop_machine poweroff
echo "update-test.sh: passed"
