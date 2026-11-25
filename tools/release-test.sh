#!/bin/sh
# Tests that a machine takes a release as tools/publish.sh put it
# together, before it is uploaded, in a virtual machine, from an Apple
# Silicon Mac:
#
#   tools/release-test.sh out/updates/0.5.2 0.5.1
#   BUNIX_ARCHITECTURE=x86_64 tools/release-test.sh out/updates/0.5.2 0.5.1
#
# once for each architecture the release is of: the machine is the Mac's
# own, or one on the x86_64 builder (tools/test-machine.sh).
#
# The first is the release's directory; the second the version machines
# run now.  A disk of that version is built and started, the Mac serves
# the directory, and the machine is told to look there, and to ask for
# the devtools and desktop extensions.  Nothing else is changed on it:
# the list of files is taken by the certificate the system comes with,
# and each image by the signature in it, as from where releases are.
# Then:
#
#   1. the installed version starts
#   2. it updates to the release, its person having asked for the
#      devtools and desktop extensions: of all the directory's files it
#      takes its own architecture's
#   3. the machine restarts into the release, and marks it good; the
#      extensions are laid over /usr, devtools' programs run, and the
#      desktop's login screen is started
#
# The installed system is this working tree's, under the older version's
# number: NOT the files that version was published with.  What
# tools/update-test.sh shows -- refusals, and going back from a version
# that does not start -- is not repeated here.
#
#   BUNIX_LIST_CERTIFICATE
#                    for a directory made with BUNIX_SIGNED_BY=development:
#                    the certificate of the key its list was signed with,
#                    which the machine is told to take, in /etc
#   BUNIX_ARCHITECTURE, BUNIX_X86_BUILDER
#                    tools/test-machine.sh
#   BUNIX_SSH_KEY    the public key the test logs in with; default
#                    ~/.ssh/id_ed25519.pub
#   BUNIX_SSH_PORT   the Mac's port for the machine's SSH; default 2022
#   BUNIX_HTTP_PORT  the Mac's port the files are served on; default 8643
#
# Needs: what tools/boot-vm.sh needs, and python3 (the server).
set -eu

usage="usage: tools/release-test.sh <release directory> <installed version>"
release=${1:?$usage}
installed=${2:?$usage}
ssh_port=${BUNIX_SSH_PORT:-2022}
http_port=${BUNIX_HTTP_PORT:-8643}
public_key_file=${BUNIX_SSH_KEY:-$HOME/.ssh/id_ed25519.pub}
if [ ! -f "$public_key_file" ]; then
    echo "release-test.sh: no public key in $public_key_file to log in with" >&2
    exit 1
fi
for file in SHA256SUMS SHA256SUMS.gpg; do
    if [ ! -s "$release/$file" ]; then
        echo "release-test.sh: no $file in $release" >&2
        exit 1
    fi
done
# sysupdate takes a list without a day as one that is good for ever
if ! grep -q '  BEST-BEFORE-20' "$release/SHA256SUMS"; then
    echo "release-test.sh: the list in $release does not say until when it is good" >&2
    exit 1
fi

tool=release-test.sh
. "$(dirname "$0")/test-machine.sh"
# the version, of the name of the kernel image this machine will take
kernel_image=$(cd "$release" && echo bunix_*."$architecture_in_file_names".efi)
if [ ! -f "$release/$kernel_image" ]; then
    echo "release-test.sh: not one $architecture_in_file_names kernel image in $release, for this test's machine" >&2
    exit 1
fi
version=${kernel_image#bunix_}
version=${version%."$architecture_in_file_names".efi}

fail() {
    echo "release-test.sh: FAILED: $*" >&2
    echo "the machine's console is in $work/console.log" >&2
    exit 1
}
# However this script ends, nothing of it stays behind, holding a port.
server=
qemu=
clean_up() {
    kill $server $qemu 2> /dev/null || true
    # waited for, so that the shell does not report them as ended
    wait 2> /dev/null || true
}
trap clean_up EXIT

# A machine of another test still running has the SSH port, and would
# answer in place of this one's, and be updated in its stead.
for port in $ssh_port $http_port; do
    if nc -z 127.0.0.1 "$port" 2> /dev/null; then
        echo "release-test.sh: port $port of this Mac is in use" >&2
        exit 1
    fi
done

prepare_machine

# ---- The machine, and what it is served ----------------------------------------

# Small slots: less to build and copy (as tools/boot-vm.sh).  No pipe
# after nix-build: a failed build has to stop this script.
echo "building $installed (the disk)"
disk=$(build "$source/nix/images/disk.nix" --argstr version "$installed" \
    --argstr espSize 512M --argstr usrSlotSize 512M --argstr usrVeritySize 8M)
copy_built_file_to_machine "$disk/disk.raw" disk.raw
# with room after its partitions for the root partition the first boot
# makes
in_machine_directory "truncate -s +2G disk.raw"

python3 -m http.server "$http_port" --bind 127.0.0.1 --directory "$release" \
    > "$work/server.log" 2>&1 &
server=$!

# One run of QEMU is one start of the machine: it ends when the machine
# restarts or powers off (-no-reboot), and the disk is the same file for
# the next.  As tools/update-test.sh starts it, with the key to log in
# with handed over the way a machine's firmware does.
key_word="systemd.set_credential_binary=bunix.authorized_keys:$(base64 < "$public_key_file" | tr -d '\n')"
# QEMU reads a single comma as the end of the value
smbios_words=$(printf %s "console=$console quiet $key_word" | sed 's/,/,,/g')
start_machine() {
    # shellcheck disable=SC2086  # QEMU's words are several each
    start_qemu $machine_on_real_processor $efi_firmware \
        -drive "file=$machine_directory/disk.raw,format=raw,if=virtio" \
        -smbios "type=11,value=io.systemd.stub.kernel-cmdline-extra=$smbios_words"
}
in_guest() {
    ssh -p "$ssh_port" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=3 -o LogLevel=ERROR root@127.0.0.1 "$@"
}
# Waits until systemd has started everything, and says which version runs.
start_and_expect() {
    expected=$1
    start_machine
    deadline=$(($(date +%s) + 90))
    until in_guest true 2> /dev/null; do
        machine_is_gone=no
        kill -0 $qemu 2> /dev/null || machine_is_gone=yes
        if [ $machine_is_gone = yes ] || [ "$(date +%s)" -ge $deadline ]; then
            fail "the machine did not answer on SSH; $expected was to start"
        fi
        sleep 2
    done
    # A QEMU that could not have its port ends at once, and what answers
    # is then whatever machine has the port.
    kill -0 $qemu 2> /dev/null || fail "QEMU ended, and another machine answers on port $ssh_port"
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

# ---- The test ------------------------------------------------------------------

echo "1. $installed starts"
start_and_expect "$installed"

echo "2. $installed updates to $version"
# What a machine is told, in /etc, in place of the files in /usr of the
# same names: where the updates are.  (Path=https: the line that says
# where from; the one that says where to has a Path= too.)
in_guest "mkdir -p /etc/sysupdate.d && cd /usr/lib/sysupdate.d && for file in *.transfer; do
    sed -e 's#^Path=https.*#Path=http://10.0.2.2:$http_port/#' \$file > /etc/sysupdate.d/\$file
done" || fail "could not tell the machine where the updates are"
if [ -n "${BUNIX_LIST_CERTIFICATE:-}" ]; then
    in_guest "mkdir -p /etc/systemd && cat > /etc/systemd/import-pubring.pgp" < "$BUNIX_LIST_CERTIFICATE" \
        || fail "could not tell the machine whose lists to take"
fi
in_guest "for feature in devtools desktop; do
        mkdir -p /etc/sysupdate.d/\$feature.feature.d &&
        printf '[Feature]\nEnabled=true\n' > /etc/sysupdate.d/\$feature.feature.d/enable.conf || exit 1
    done" \
    || fail "could not ask for the devtools and desktop extensions"
in_guest /usr/lib/systemd/systemd-sysupdate update > "$work/update.log" 2>&1 \
    || fail "the update did not go through; see $work/update.log"
on_disk=$(in_guest "ls /boot/EFI/Linux /var/lib/bunix/extensions; lsblk -n -o PARTLABEL") \
    || fail "could not look at the machine's disk"
for written in "bunix_$version+3-0.efi" "devtools_$version.raw" "desktop_$version.raw" "bunix_$version"; do
    echo "$on_disk" | grep -q -x -F "$written" \
        || fail "the update wrote no $written; see $work/update.log"
done

echo "3. restart into $version"
stop_machine reboot
start_and_expect "$version"
in_guest systemctl is-active --quiet systemd-bless-boot.service \
    || fail "the boot of $version was not marked good"
in_guest "ls /boot/EFI/Linux/bunix_$version.efi" > /dev/null \
    || fail "$version still has tries in its name"
in_guest "git --version && gdb --version && strace -V && file --version && bsdtar --version && nix --version && node --version" \
    > "$work/devtools.log" 2>&1 \
    || fail "the devtools extension's programs do not all run; see $work/devtools.log"
echo "  marked good; the devtools extension of $version is merged, and its programs run"
in_guest "test -e /usr/lib/extension-release.d/extension-release.desktop &&
    timeout 60 sh -c 'until systemctl is-active -q greetd.service; do sleep 1; done'" \
    || fail "the desktop extension of $version is not merged, or its login screen did not start"
echo "  the desktop extension of $version is merged, and its login screen started"

stop_machine poweroff
echo "release-test.sh: passed"
