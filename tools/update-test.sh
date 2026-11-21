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
#   1. the installed version takes the list of files bunix 0.4.0 was
#      published with, as signed by the release key, by the certificate it
#      comes with (downloaded from where releases are); and not that list
#      with a byte changed
#   2. it refuses the next version while the list of its files is not
#      signed, is signed by a key the machine does not know, or was changed
#      after it was signed; and nothing of that version is written
#   3. with the list signed as it should be, it updates: the next /usr goes
#      into the empty slot, its kernel image beside the old one, with three
#      tries; and, the devtools extension having been asked for, that
#      version's extension with it
#   4. the machine restarts into the next version, from the second slot,
#      and marks it good once all of it has started.  The extension is
#      laid over /usr, and its programs run.  It is not, if what is in
#      its place is not signed, or signed as of another hash
#   5. it updates to the broken one, over the first slot
#   6. the broken one is started three times, and does not come up
#   7. the fourth start is the next version again, and the broken one is
#      marked bad; the next version's extension is merged, not the
#      broken one's
#
# The lists of steps 2 to 5 are signed here, with keys made for this run,
# and the machine is told which of them to take, in /etc, where an
# administrator would say it.  NOT tested: a list past the day it says it
# is good until.
#
#   BUNIX_EFI        `u-boot`: the machine is started by U-Boot, the EFI
#                    firmware a Mac is given (nix/boot.nix), here as built
#                    for this virtual machine, in place of the firmware
#                    that comes with QEMU; but for one start before step
#                    1, which puts the key on the disk (step 0).  What it
#                    shows: that U-Boot's EFI lets systemd-boot count the
#                    tries, which it does by renaming the kernel image.
#                    Slower: see start_machine.
#   BUNIX_SSH_KEY    the public key the test logs in with; default
#                    ~/.ssh/id_ed25519.pub
#   BUNIX_SSH_PORT   the Mac's port for the machine's SSH; default 2022
#   BUNIX_HTTP_PORT  the Mac's port the files are served on; default 8643
#
# Needs: what tools/boot-vm.sh needs, python3 (the server), gpg (the
# signatures), and the internet (step 1).
set -eu

case ${BUNIX_EFI:-} in
    "" | u-boot) ;;
    *) echo "update-test.sh: BUNIX_EFI is u-boot, or not set" >&2; exit 1 ;;
esac
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
# However this script ends, nothing of it stays behind: the server and the
# machine, holding their ports; gpg's agents; the keys.
server=
qemu=
signing_keys=
clean_up() {
    kill $server $qemu 2> /dev/null || true
    # waited for, so that the shell does not report them as ended
    wait 2> /dev/null || true
    [ -n "$signing_keys" ] || return 0
    for who in signer stranger; do
        gpgconf --homedir "$signing_keys/$who" --kill gpg-agent 2> /dev/null || true
    done
    rm -rf "$signing_keys"
}
trap clean_up EXIT

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
# The devtools extension of each: a machine that has asked for it takes a
# version only with its extension, as one update.
next_devtools=$(build /bunix/nix/images/devtools.nix -A image --argstr version "$next")
# and its file system alone, before anything was signed: what an
# extension nobody signed would be
next_devtools_parts=$(build /bunix/nix/images/devtools.nix -A parts --argstr version "$next")
broken_devtools=$(build /bunix/nix/images/devtools.nix -A image --argstr version "$broken")
# The kernel image of another system of the broken version: one for
# release, whose /usr differs (it takes fewer certificates), and so its
# hash.  No partition will have the ids that image looks for.
stray_uki=$(build /bunix/nix/images/uki.nix --argstr version "$broken" --argstr signing release)

if [ "${BUNIX_EFI:-}" = u-boot ]; then
    u_boot=$(build /bunix/nix/boot.nix -A u-boot-qemu)
    limactl copy "bunix-builder:$u_boot/usr/lib/u-boot/qemu/u-boot-nodtb.bin" "$work/u-boot.bin"
fi

limactl copy "bunix-builder:$disk/disk.raw" "$work/disk.raw"
# copied out of the store, where nothing can be written; and with room
# after its partitions for the root partition the first boot makes
chmod u+w "$work/disk.raw"
truncate -s +2G "$work/disk.raw"

limactl copy -r "bunix-builder:$next_update/." "$work/served/next/"
limactl copy -r "bunix-builder:$broken_update/." "$work/served/broken/"
limactl copy -r "bunix-builder:$next_devtools/." "$work/served/next/"
limactl copy "bunix-builder:$next_devtools_parts/root.raw" "$work/devtools-file-system.raw"
limactl copy -r "bunix-builder:$broken_devtools/." "$work/served/broken/"
chmod -R u+w "$work/served"
broken_uki=$(basename "$work"/served/broken/*.efi)
rm "$work/served/broken/$broken_uki"
limactl copy "bunix-builder:$stray_uki/bunix_$broken.efi" "$work/served/broken/$broken_uki"

# ---- The lists of files, and who signs them ------------------------------------

# Two keys, each in a directory of its own: the signer's, which the
# machine is told to take, and a stranger's.  (In /tmp: gpg talks to its
# agent through a socket there, whose path has to be short.)
#
# Made as of an hour ago, and what they sign as of a minute ago: a
# signature from the future is refused, and the machine's clock may be a
# little behind this Mac's.  gpg says at every use that its time is not
# the real one; that goes to a log.
signing_keys=$(mktemp -d /tmp/bunix-update-test.XXXXXX)
an_hour_ago=$(($(date +%s) - 3600))
for who in signer stranger; do
    mkdir -m 700 "$signing_keys/$who"
    gpg --homedir "$signing_keys/$who" --batch --quiet --passphrase '' \
        --faked-system-time $an_hour_ago \
        --quick-generate-key "bunix update test: $who" ed25519 sign never 2>> "$work/gpg.log" \
        || fail "gpg made no key for the $who; see $work/gpg.log"
done
# write_list <served directory>: the list a machine reads to learn what
# there is, each file and its hash.  Any signature it had is gone with the
# old list.
write_list() {
    (cd "$work/served/$1" && rm -f SHA256SUMS SHA256SUMS.gpg && shasum -a 256 * > SHA256SUMS)
}
# sign_list <who> <served directory>
sign_list() {
    rm -f "$work/served/$2/SHA256SUMS.gpg"
    a_minute_ago=$(($(date +%s) - 60))
    gpg --homedir "$signing_keys/$1" --batch --quiet --faked-system-time $a_minute_ago \
        --detach-sign --output "$work/served/$2/SHA256SUMS.gpg" "$work/served/$2/SHA256SUMS" \
        2>> "$work/gpg.log" \
        || fail "gpg did not sign the list of $2 as the $1; see $work/gpg.log"
}
write_list broken
sign_list signer broken

python3 -m http.server "$http_port" --bind 127.0.0.1 --directory "$work/served" \
    > "$work/server.log" 2>&1 &
server=$!

# ---- The machine ---------------------------------------------------------------

# One run of QEMU is one start of the machine: it ends when the machine
# restarts or powers off (-no-reboot), and the disk is the same file for
# the next.  As tools/boot-vm.sh starts a disk: EFI firmware, and the
# words for the kernel handed over the way a machine's firmware does.
#
# U-Boot is not handed QEMU's words for the kernel, and so not the key:
# it gets a machine that has the key on its disk (step 0, below).
# And it does not run on the Mac's own processor: the hypervisor stops at
# an instruction of U-Boot's it cannot carry out.  QEMU plays the
# processor instead (tcg), `max` being the one of its processors with the
# 16K pages this kernel is built for; a start takes about twice as long.
key_word="systemd.set_credential_binary=bunix.authorized_keys:$(base64 < "$public_key_file" | tr -d '\n')"
# QEMU reads a single comma as the end of the value
smbios_words=$(printf %s "console=ttyAMA0 quiet $key_word" | sed 's/,/,,/g')
qemus_firmware=$(dirname "$(command -v qemu-system-aarch64)")/../share/qemu/edk2-aarch64-code.fd
# step 0 changes it to u-boot
started_by=qemus-firmware
# qemu_machine <the processor, and the firmware with what it is handed>
qemu_machine() {
    qemu-system-aarch64 -M virt -smp 4 -m 4G "$@" \
        -netdev "user,id=net,hostfwd=tcp:127.0.0.1:$ssh_port-:22" -device virtio-net-pci,netdev=net \
        -nographic -no-reboot \
        -drive "file=$work/disk.raw,format=raw,if=virtio" \
        < /dev/null >> "$work/console.log" 2>&1 &
    qemu=$!
}
start_machine() {
    if [ $started_by = u-boot ]; then
        qemu_machine -accel tcg,thread=multi -cpu max -bios "$work/u-boot.bin"
        return
    fi
    qemu_machine -accel hvf -cpu host -bios "$qemus_firmware" \
        -smbios "type=11,value=io.systemd.stub.kernel-cmdline-extra=$smbios_words"
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
# take_lists_signed_by <who>: and whose signature on a list of files to
# take, as a certificate where systemd looks before it looks in /usr
take_lists_signed_by() {
    gpg --homedir "$signing_keys/$1" --export > "$work/$1.pgp"
    [ -s "$work/$1.pgp" ] || fail "gpg gave no certificate of the $1's key"
    in_guest "mkdir -p /etc/systemd && cat > /etc/systemd/import-pubring.pgp" < "$work/$1.pgp"
}
# try_update <name of its log>: to whatever is newest where the machine
# was last told to look
try_update() {
    in_guest /usr/lib/systemd/systemd-sysupdate update > "$work/update-$1.log" 2>&1
}
update() {
    try_update "$1" || fail "the update did not go through; see $work/update-$1.log"
}
# expect_refusal <name of the log> <what is wrong with the list of files>
#     <what the log is to say>
#
# Of $next: that the update fails, for that reason and not another (a
# server that is down fails it too), and that nothing of $next is on the
# disk.
expect_refusal() {
    if try_update "$1"; then
        fail "an update whose list of files $2 was taken"
    fi
    grep -q -F "$3" "$work/update-$1.log" \
        || fail "the update failed, but not because its list of files $2; see $work/update-$1.log"
    on_disk=$(in_guest 'ls /boot/EFI/Linux; lsblk -n -o PARTLABEL') || fail "could not look at the machine's disk"
    case $on_disk in
        *"$next"*) fail "something of $next was written, though its list of files $2" ;;
    esac
    echo "  refused: the list of files $2"
}
# expect_not_merged <name of the log> <what is wrong with the image that
#     is in the devtools extension's place>: that none of its programs is
# there after systemd was asked to merge what there is.
expect_not_merged() {
    in_guest "systemd-sysext refresh" > "$work/sysext-$1.log" 2>&1 || true
    if in_guest "command -v git" > /dev/null; then
        fail "an extension $2 was merged; see $work/sysext-$1.log"
    fi
    echo "  refused: an extension $2"
}
# expect_kernel_image <file name> <what is wrong if it is not there>
expect_kernel_image() {
    kernel_images=$(in_guest ls /boot/EFI/Linux) || fail "could not list the machine's kernel images"
    echo "$kernel_images" | grep -q -x -F "$1" || fail "$2; there are:" $kernel_images
}

# ---- The test ------------------------------------------------------------------

if [ "${BUNIX_EFI:-}" = u-boot ]; then
    echo "0. a first start by QEMU's firmware, to put the key on the disk; U-Boot from here on"
    start_and_expect "$installed"
    # root's home is on the disk, and sshd reads the key there as well
    in_guest "mkdir -p -m 700 /root/.ssh && cat > /root/.ssh/authorized_keys" < "$public_key_file"
    stop_machine poweroff
    started_by=u-boot
fi

echo "1. $installed takes what the release key signed"
start_and_expect "$installed"
# Asked of the system's gpg directly, as systemd asks it, with the
# certificate the system comes with: sysupdate could only be told to look
# at a release if it were of this architecture and later than this
# version.
in_guest "cd /tmp && for file in SHA256SUMS SHA256SUMS.gpg; do
    curl -sS -f -L -O https://github.com/bunasys/bunix/releases/download/v0.4.0/\$file || exit 1
done" || fail "could not download the list of files of bunix 0.4.0 and its signature"
check_published_list='gpg --keyring=/usr/lib/systemd/import-pubring.pgp --verify /tmp/SHA256SUMS.gpg - < /tmp/SHA256SUMS'
in_guest "$check_published_list" > "$work/release-key.log" 2>&1 \
    || fail "the list bunix 0.4.0 was published with was not taken; see $work/release-key.log"
in_guest "echo >> /tmp/SHA256SUMS"
if in_guest "$check_published_list" > "$work/release-key-changed.log" 2>&1; then
    fail "the list bunix 0.4.0 was published with was taken with a byte added"
fi
echo "  taken as published, refused with a byte added"

echo "2. $installed refuses $next while its list of files cannot be trusted"
look_for_updates_in next
take_lists_signed_by signer

write_list next
expect_refusal unsigned "is not signed" "cannot verify"

sign_list stranger next
expect_refusal stranger "is signed by a key the machine does not know" "Signature verification failed"

# any change will do: a line for a file that is not there
sign_list signer next
no_hash=$(printf '%064d' 0)
echo "$no_hash  added-after-signing" >> "$work/served/next/SHA256SUMS"
expect_refusal changed "was changed after it was signed" "Signature verification failed"

echo "3. $installed updates to $next"
# The machine's person asks for the devtools extension, as its feature
# file says how (system/usr/lib/sysupdate.d/devtools.feature).
in_guest "mkdir -p /etc/sysupdate.d/devtools.feature.d &&
    printf '[Feature]\nEnabled=true\n' > /etc/sysupdate.d/devtools.feature.d/enable.conf" \
    || fail "could not ask for the devtools extension"
write_list next
sign_list signer next
update next
in_guest "ls /var/lib/bunix/extensions/devtools_$next.raw" > /dev/null \
    || fail "the update did not bring the devtools extension of $next"
expect_kernel_image "bunix_$next+3-0.efi" "no kernel image of $next with three tries"
in_guest lsblk -n -o PARTLABEL | grep -q -x -F "bunix_$next" \
    || fail "no /usr partition labelled bunix_$next"

echo "4. restart into $next"
stop_machine reboot
start_and_expect "$next"
# Marked good, and for the reason the system gives (no unit failed), not
# only because nothing asked: the tries are gone from its name.
in_guest systemctl is-active --quiet systemd-boot-check-no-failures.service \
    || fail "nothing checked that all of $next started before its boot was marked good"
in_guest systemctl is-active --quiet systemd-bless-boot.service \
    || fail "the boot of $next was not marked good"
expect_kernel_image "bunix_$next.efi" "$next still has tries in its name"

# The extension came with the update, and the boot laid it over /usr:
# its programs are there, and Nix's daemon is listening.
in_guest "git --version && gdb --version && strace -V && file --version && bsdtar --version && nix --version" \
    > "$work/devtools.log" 2>&1 \
    || fail "the devtools extension's programs do not all run; see $work/devtools.log"
in_guest systemctl is-active --quiet nix-daemon.socket \
    || fail "nothing listens for Nix's daemon"
echo "  the devtools extension of $next is merged, and its programs run"
# What is in the extension's place is merged only if it is signed, and
# the signature is of what is there.  The image as it came is set aside
# for these, and put back after.
extension=/var/lib/bunix/extensions/devtools_$next.raw
in_guest "systemd-sysext unmerge > /dev/null 2>&1 && mv $extension /var/tmp/as-it-came.raw" \
    || fail "could not set the extension aside"
# Its file system alone: no hashes, no signature.  systemd would merge it
# if it were not told to take signed images only.
in_guest "cat > $extension" < "$work/devtools-file-system.raw" \
    || fail "could not put an unsigned extension in the place of the signed one"
expect_not_merged unsigned "that is not signed"
# The image as it came, but for the hash its signature says it is of:
# the first four digits, which come right after the name.
in_guest "set -e
    cp /var/tmp/as-it-came.raw $extension
    name_at=\$(grep -a -b -o '\"rootHash\":\"' $extension | head -n 1 | cut -d: -f1)
    [ -n \"\$name_at\" ]
    digits_at=\$((name_at + 12))    # past \"rootHash\":\"
    printf 0000 | dd of=$extension bs=1 seek=\$digits_at conv=notrunc status=none
    ! cmp -s $extension /var/tmp/as-it-came.raw" \
    || fail "could not change the hash the extension's signature is of"
expect_not_merged changed "whose signature is of another hash"
in_guest "mv /var/tmp/as-it-came.raw $extension && chmod 0444 $extension &&
    systemd-sysext refresh > /dev/null 2>&1 && command -v git > /dev/null" \
    || fail "the extension as it came is not merged again"

echo "5. $next updates to $broken, which cannot start"
look_for_updates_in broken
update broken
expect_kernel_image "bunix_$broken+3-0.efi" "no kernel image of $broken with three tries"

echo "6. $broken is tried three times"
stop_machine reboot
for try in 1 2 3; do
    start_machine
    # A start that works answers in about 15 s, or 30 by U-Boot; this
    # one waits for a /usr that is not there, with nobody to tell.
    if answers_within 45; then
        fail "a system started on try $try of $broken"
    fi
    echo "  try $try: did not come up"
    kill $qemu 2> /dev/null || true
    wait $qemu 2> /dev/null || true
done

echo "7. the machine goes back to $next"
start_and_expect "$next"
expect_kernel_image "bunix_$broken+0-3.efi" "$broken is not marked bad"
# $next has its own extension still, though $broken's is beside it and
# is the newer
in_guest "command -v git" > /dev/null \
    || fail "back on $next, its devtools extension is not merged"

stop_machine poweroff
echo "update-test.sh: passed"
