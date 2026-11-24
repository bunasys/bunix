#!/bin/sh
# Tests the desktop extension (nix/images/desktop.nix) on a test system
# in a virtual machine, from an Apple Silicon Mac:
#
#   tools/desktop-test.sh
#
# The machine is a test system's disk, as tools/boot-vm.sh starts one,
# with a screen and a keyboard.  Then:
#
#   1. the extension, signed with the development key, is put where an
#      update puts it, and systemd-sysext merges it; the unit it brings
#      (the font cache) runs, the generic font names are the fonts bunix
#      means, in English and Arabic, and libinput's udev rules reach the
#      keyboard, which was there before them
#   2. the login screen comes up: greetd, upheld once merged, runs DMS's
#      greeter on tty1, in niri, which draws with OpenGL through Mesa's
#      llvmpipe; libinput finds the keyboard; niri takes a picture of the
#      screen, copied here to be looked at
#   3. a person logs in, typing their name and password on the machine's
#      keyboard: their session is niri with DMS, and a session bus; a
#      picture of the desktop is copied here too
#
# What is not tested: a GPU's own driver.  The x86_64 machine's GPU is
# QEMU's standard VGA, and the arm64 one's virtio's, 2D only (QEMU on a
# Mac): Mesa draws with llvmpipe on both, which niri is told to take.
# Nor what a person sees: the pictures are the screen as niri drew it,
# which only a look at them says is right.  Nor the greeter's picker of
# people, which only a click opens: the test has it ask for a name.
#
#   BUNIX_ARCHITECTURE, BUNIX_X86_BUILDER
#                      tools/test-machine.sh
#   BUNIX_SSH_KEY      the public key the test logs in with; default
#                      ~/.ssh/id_ed25519.pub
#   BUNIX_SSH_PORT     the port for the machine's SSH; default 2022
#
# Needs: what tools/boot-vm.sh needs, and python3 where QEMU runs (this
# Mac, or the x86_64 builder): it types on the machine's keyboard.
set -eu

public_key_file=${BUNIX_SSH_KEY:-$HOME/.ssh/id_ed25519.pub}
if [ ! -f "$public_key_file" ]; then
    echo "desktop-test.sh: no public key in $public_key_file to log in with" >&2
    exit 1
fi
ssh_port=${BUNIX_SSH_PORT:-2022}
# A machine that is not this test's, on the port, would answer for it.
if nc -z 127.0.0.1 "$ssh_port" 2> /dev/null; then
    echo "desktop-test.sh: port $ssh_port is taken; end what has it, or set BUNIX_SSH_PORT" >&2
    exit 1
fi
tool=desktop-test.sh
. "$(dirname "$0")/test-machine.sh"

fail() {
    echo "desktop-test.sh: FAILED: $*" >&2
    echo "the machine's console is in $work/console.log" >&2
    exit 1
}
prepare_machine
version=$(release_version)

echo "building a test system's disk, and its desktop extension"
disk=$(build "$source/nix/images/disk.nix" --argstr espSize 512M \
    --argstr usrSlotSize 512M --argstr usrVeritySize 8M)
desktop=$(build "$source/nix/images/desktop.nix" -A image)
copy_built_file_to_machine "$disk/disk.raw" disk.raw
in_machine_directory "truncate -s +2G disk.raw"
copy_built_file "$desktop/desktop_*.raw" "$work/desktop.raw"

# The key that may log in, as boot-vm.sh gives it: a credential on the
# kernel's command line, which the firmware hands over (SMBIOS).
key_word="systemd.set_credential_binary=bunix.authorized_keys:$(base64 < "$public_key_file" | tr -d '\n')"
smbios_words=$(printf 'console=%s %s' "$console" "$key_word" | sed 's/,/,,/g')
# BUNIX_MONITOR: the keyboard of step 3 is typed on through QEMU's monitor
export BUNIX_MONITOR=1
# shellcheck disable=SC2086
start_qemu $machine_on_real_processor $efi_firmware \
    -drive "file=$machine_directory/disk.raw,format=raw,if=virtio" \
    -smbios "type=11,value=io.systemd.stub.kernel-cmdline-extra=$smbios_words"
trap 'kill $qemu 2> /dev/null || true' EXIT

in_guest() {
    ssh -p "$ssh_port" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=3 -o LogLevel=ERROR root@127.0.0.1 "$@"
}
deadline=$(($(date +%s) + 120))
until in_guest true 2> /dev/null; do
    if [ "$(date +%s)" -ge "$deadline" ] || ! kill -0 "$qemu" 2> /dev/null; then
        fail "the machine did not answer on SSH"
    fi
    sleep 2
done
# Only to wait until the machine has started: how it started is
# boot-vm.sh's to check, and what is tested here is what comes after.
in_guest systemctl is-system-running --wait > /dev/null 2>&1 || true

echo "1. the desktop extension is merged"
# where an update puts a version's extensions (sysupdate.d/), read-only
# as it leaves them
extension=/var/lib/bunix/extensions/desktop_$version.raw
in_guest "mkdir -p /var/lib/bunix/extensions && cat > $extension && chmod 0444 $extension" \
    < "$work/desktop.raw" || fail "could not put the extension on the machine"
in_guest "systemctl restart systemd-sysext.service" \
    || fail "systemd-sysext did not merge the extensions; see: journalctl -u systemd-sysext"
in_guest "systemd-sysext status" > "$work/sysext.log" 2>&1 || true
grep -q desktop "$work/sysext.log" || fail "the desktop extension is not merged; see $work/sysext.log"
in_guest "command -v niri" > /dev/null || fail "merged, but niri is not there"
# Upheld by multi-user.target, which systemd starts as soon as it knows
# the unit: after the merge, which has it read its units again.  The
# unit is active even when fc-cache fails (`-`: an upheld unit that
# fails is started again and again), so fc-cache's own status is asked.
in_guest "timeout 60 sh -c 'until systemctl is-active -q fontconfig-cache.service; do sleep 1; done'" \
    || fail "the font cache's unit did not start"
fc_cache_status=$(in_guest "systemctl show --property=ExecMainStatus --value fontconfig-cache.service")
[ "$fc_cache_status" = 0 ] || fail "fc-cache failed (status $fc_cache_status); see: journalctl -u fontconfig-cache"
# The fonts the generic names are (files/fontconfig/58-bunix-fonts.conf),
# as every program's Fontconfig finds them: for text in no language, in
# Arabic (lang=ar), and for an Arabic letter (alef, U+0627) in a page
# whose font has none.
expect_font() {
    found=$(in_guest "fc-match -f '%{family[0]}' '$1'") || fail "fc-match could not match $1"
    [ "$found" = "$2" ] || fail "$1 is $found, and was to be $2"
}
expect_font sans-serif "Noto Sans"
expect_font serif "Noto Serif"
expect_font monospace "Noto Sans Mono"
expect_font emoji "Noto Color Emoji"
expect_font sans-serif:lang=ar "Noto Sans Arabic"
expect_font serif:lang=ar "Noto Naskh Arabic"
expect_font sans-serif:charset=627 "Noto Sans Arabic"
expect_font serif:charset=627 "Noto Naskh Arabic"
expect_font monospace:lang=ar "Kawkab Mono"
expect_font monospace:charset=627 "Kawkab Mono"
# The keyboard was there before libinput's rules: what the merge does to
# udev (systemd-sysext.service.d/bunix.conf) gives it what they set.
in_guest "udevadm settle && udevadm info --query=property /dev/input/event*" > "$work/input.log" 2>&1 || true
grep -q "^LIBINPUT_DEVICE_GROUP=" "$work/input.log" \
    || fail "libinput's udev rules did not reach the input devices; see $work/input.log"
echo "  merged; niri is there, the font cache was made with the Noto and Arabic fonts, and libinput's rules reached the keyboard"

echo "2. the login screen comes up"
# The services the login screen needs, upheld once merged: the list of
# people (accountsservice) and greetd, which runs the greeter on tty1
for unit in accounts-daemon.service greetd.service; do
    if ! in_guest "timeout 60 sh -c 'until systemctl is-active -q $unit; do sleep 1; done'"; then
        in_guest "systemctl status --no-pager $unit; journalctl -b --no-pager -u $unit" > "$work/$unit.log" 2>&1 || true
        fail "$unit did not start; see $work/$unit.log"
    fi
done
# A person to log in as, and greetd started again with the test's own
# configuration: the extension's (/usr/share/greetd), with three
# variables more for the greeter's command:
#   BUNIX_NIRI_SOFTWARE_RENDERING=1   niri draws with llvmpipe (as the
#                                     person's own niri, through their
#                                     systemd's environment)
#   RUST_LOG                          niri's renderer line in its log
#   DMS_GREET_REMEMBER_LAST_USER=false
#                                     the greeter asks for a name: one that
#                                     remembers shows a picker of people,
#                                     which only a click opens
in_guest "useradd --create-home sara && echo sara:secret | chpasswd" \
    || fail "could not make a person to log in as"
in_guest "mkdir -p /run/desktop-test /run/systemd/system/greetd.service.d /etc/systemd/user.conf.d
    sed 's|^command = \"|command = \"env BUNIX_NIRI_SOFTWARE_RENDERING=1 RUST_LOG=niri=info,smithay::backend::renderer::gles=info DMS_GREET_REMEMBER_LAST_USER=false |' \
        /usr/share/greetd/config.toml > /run/desktop-test/greetd.toml
    grep -q '^command = \"env BUNIX_NIRI_SOFTWARE_RENDERING=1 ' /run/desktop-test/greetd.toml
    printf '[Service]\nExecStart=\nExecStart=/usr/bin/greetd --config /run/desktop-test/greetd.toml\n' \
        > /run/systemd/system/greetd.service.d/desktop-test.conf
    printf '[Manager]\nDefaultEnvironment=BUNIX_NIRI_SOFTWARE_RENDERING=1\n' \
        > /etc/systemd/user.conf.d/desktop-test.conf
    systemctl daemon-reload && systemctl restart greetd.service" \
    || fail "could not start greetd again with the test's configuration (has /usr/share/greetd/config.toml a command line still?)"
# What greetd, the greeter and sara's session said: kept here, after a
# failure as after a pass
save_login_log() {
    in_guest "journalctl -b --no-pager -u greetd; journalctl -b --no-pager _UID=\$(id -u greeter); journalctl -b --no-pager _UID=\$(id -u sara); ls -l /dev/dri /dev/input; cat /sys/class/drm/*/status" \
        > "$work/login.log" 2>&1 || true
}
fail_with_login_log() {
    save_login_log
    fail "$* (greetd's, the greeter's and sara's log: $work/login.log)"
}
# The socket niri listens on (NIRI_SOCKET), once whom it runs as has it
# and the interface on it (Quickshell's qs, the greeter's or DMS's): in
# their runtime directory, the newest, should a niri before it have left
# one
wait_for_shell_of() {
    user=$1
    failure=$2
    socket=
    deadline=$(($(date +%s) + 90))
    until [ -n "$socket" ] && in_guest "pgrep -u $user -x 'qs|quickshell'" > /dev/null; do
        if [ "$(date +%s)" -ge "$deadline" ]; then
            fail_with_login_log "$failure"
        fi
        sleep 2
        socket=$(in_guest "ls -t /run/user/\$(id -u $user)/niri.*.sock 2> /dev/null | head -n 1" || true)
    done
    echo "$socket"
}
greeter_socket=$(wait_for_shell_of greeter "the login screen did not come up: no niri, or no Quickshell, as the greeter user") \
    || exit 1
in_guest "NIRI_SOCKET=$greeter_socket niri msg outputs" > "$work/outputs.log" 2>&1 \
    || fail_with_login_log "the greeter's niri does not answer; see $work/outputs.log"
grep -q "^Output" "$work/outputs.log" || fail_with_login_log "the greeter's niri has no screen"
sed -n 's/^Output /  screen: /p' "$work/outputs.log"
save_login_log
renderer=$(grep -o "GL Renderer: .*" "$work/login.log" | head -n 1 || true)
case $renderer in
    *llvmpipe*) echo "  $renderer" ;;
    *) fail "the greeter's niri did not draw with llvmpipe (${renderer:-no renderer in its log}); see $work/login.log" ;;
esac
# what libinput makes of the machine's input devices, as niri sees them
in_guest "libinput list-devices" > "$work/libinput.log" 2>&1 || true
grep -q "^Capabilities: *keyboard" "$work/libinput.log" \
    || fail_with_login_log "libinput finds no keyboard; see $work/libinput.log"
echo "  libinput finds the keyboard"

# A picture of a screen, as niri drew it: written where its user can
# write, and copied here
take_picture() {
    user=$1
    socket=$2
    copy=$3
    picture=/run/user/$(in_guest "id -u $user")/desktop-test.png
    in_guest "NIRI_SOCKET=$socket niri msg action screenshot-screen --path $picture" > /dev/null \
        || fail_with_login_log "niri did not take a picture of its screen"
    in_guest "timeout 10 sh -c 'until [ -s $picture ]; do sleep 1; done'; cat $picture" > "$copy" \
        || fail_with_login_log "niri wrote no picture of its screen"
    # a PNG file starts with these eight bytes
    [ "$(head -c 8 "$copy" | od -An -tx1 | tr -d ' \n')" = 89504e470d0a1a0a ] \
        || fail "what niri wrote is not a picture"
}
# Quickshell has started, and draws its first frame some seconds after:
# no sign of that reaches outside, so the test waits
qs_draws_its_first_frame=10
sleep $qs_draws_its_first_frame
take_picture greeter "$greeter_socket" "$work/login-screen.png"
echo "  the login screen: $work/login-screen.png"

echo "3. a person logs in, and DMS comes up"
# Typed on the machine's keyboard, through QEMU's monitor
# (test-machine.sh, BUNIX_MONITOR), which python3 talks to where QEMU
# runs: the name, then the password
cat > "$work/monitor.py" <<'PYTHON'
# Each line of the standard input to QEMU's monitor, a moment apart
import socket, sys, time
monitor = socket.socket(socket.AF_UNIX)
monitor.connect("monitor")
for line in sys.stdin:
    monitor.sendall(line.encode())
    time.sleep(0.15)
monitor.close()
PYTHON
send_to_machine monitor.py
type_on_keyboard() {
    keys=$(printf '%s' "$1" | fold -w 1 | sed 's/^/sendkey /')
    printf '%s\nsendkey ret\n' "$keys" | in_machine_directory "python3 monitor.py" \
        || fail "could not type on the machine's keyboard (is python3 where QEMU runs?)"
}
type_on_keyboard sara
# the greeter asks greetd about the name before it shows the password's
# field, which takes it a moment
greeter_shows_the_password_field=3
sleep $greeter_shows_the_password_field
type_on_keyboard secret
# The session greetd starts (niri-session, niri.service) as sara, and DMS
# in it (dms.service, wanted by niri.service)
sara_socket=$(wait_for_shell_of sara "sara's session did not come up: no niri, or no DMS's Quickshell") \
    || exit 1
in_guest "loginctl list-sessions --no-legend" > "$work/sessions.log" 2>&1 || true
grep -q " sara " "$work/sessions.log" || fail "sara has no logind session; see $work/sessions.log"
# the session bus, which the person's own services talk over
in_guest "test -S /run/user/\$(id -u sara)/bus" \
    || fail "sara's session has no session bus (dbus-user-session)"
echo "  sara is logged in, with DMS and a session bus"
sleep $qs_draws_its_first_frame
take_picture sara "$sara_socket" "$work/desktop.png"
echo "  the desktop: $work/desktop.png"

in_guest systemctl poweroff || true
wait "$qemu" || true
echo "desktop-test.sh: passed"
