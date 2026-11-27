#!/bin/sh
# Tests the desktop extension (nix/images/desktop.nix) on a test system
# in a virtual machine, from an Apple Silicon Mac:
#
#   tools/desktop-test.sh
#
# The machine is a test system's disk, as tools/boot-vm.sh starts one,
# with a screen, a keyboard and a sound card.  Then:
#
#   1. the extension, signed with the development key, is put where an
#      update puts it, and systemd-sysext merges it; the unit it brings
#      (the font cache) runs, the generic font names are the fonts bunix
#      means, in English and Arabic, and libinput's udev rules reach the
#      keyboard, which was there before them; and upower answers
#   2. the login screen comes up: greetd, upheld once merged, runs DMS's
#      greeter on tty1, in niri, which draws with OpenGL through Mesa's
#      llvmpipe; libinput finds the keyboard; niri takes a picture of the
#      screen, copied here to be looked at
#   3. a person logs in, typing their name and password on the machine's
#      keyboard: their session is niri with DMS, and a session bus; a
#      picture of the desktop is copied here too; and Qt has a UTF-8
#      locale (base.nix, c-utf8-locale)
#   4. sound: the card's volumes are set, WirePlumber gives the person's
#      PipeWire the card for its output, and a sound plays through it
#   5. the terminal and FUSE: Alacritty opens a window in the person's
#      session, pictured too; and the person mounts a FUSE file system
#      (libfuse's example) through fusermount3, and reads a file in it,
#      once with libfuse 3 and once with libfuse 2, as AppImages do
#   6. another console: Ctrl+Alt+F2, pressed on the keyboard while the
#      person's desktop has tty1, shows a login prompt on tty2, and the
#      person logs in there; Ctrl+Alt+F1 brings their desktop back
#   7. the browser, Hudhud: it opens a page of the test's in a window,
#      pictured; Ctrl+O shows GTK 4's file dialog; words typed in the
#      address bar go to Brave Search; and Shields blocked the page's
#      advertisement and let its image through.  Not tested: Shields on
#      a page of a web site (the machine has none to serve one), and that
#      Brave is listed once among the search engines
#
# What is not tested: a GPU's own driver.  The x86_64 machine's GPU is
# QEMU's standard VGA, and the arm64 one's virtio's, 2D only (QEMU on a
# Mac): Mesa draws with llvmpipe on both, which niri is told to take.
# Nor a Mac's sound card: the arm64 machine's is virtio's, the x86_64
# one's QEMU's Intel HD Audio, and what they play goes nowhere.
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
# the FUSE file systems step 5 mounts, which no image has
fuse_hello=$(build "$source/nix/desktop.nix" -A fuse-hello)
copy_built_file_to_machine "$disk/disk.raw" disk.raw
in_machine_directory "truncate -s +2G disk.raw"
copy_built_file "$desktop/desktop_*.raw" "$work/desktop.raw"
copy_built_file "$fuse_hello/usr/bin/fuse-hello" "$work/fuse-hello"
copy_built_file "$fuse_hello/usr/bin/fuse2-hello" "$work/fuse2-hello"

# The key that may log in, as boot-vm.sh gives it: a credential on the
# kernel's command line, which the firmware hands over (SMBIOS).
key_word="systemd.set_credential_binary=bunix.authorized_keys:$(base64 < "$public_key_file" | tr -d '\n')"
smbios_words=$(printf 'console=%s %s' "$console" "$key_word" | sed 's/,/,,/g')
# BUNIX_MONITOR: the keyboard of step 3 is typed on through QEMU's monitor
export BUNIX_MONITOR=1
# A sound card whose sound goes nowhere (an audio backend of "none"): on
# arm64 virtio's, which the kernel has built in, on x86_64 Intel HD
# Audio, whose modules the kernel has (boot/linux/)
case $architecture in
aarch64) sound_card="-device virtio-sound-pci,audiodev=silence" ;;
x86_64) sound_card="-device intel-hda -device hda-duplex,audiodev=silence" ;;
*) fail "no sound card for a machine of $architecture" ;;
esac
# shellcheck disable=SC2086
start_qemu $machine_on_real_processor $efi_firmware -audiodev none,id=silence $sound_card \
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
# upower, upheld once merged, answers on the system bus, with its
# settings, which are in /usr (desktop/upower.sh).  No battery: neither
# machine has one, and what it says of a Mac's is not tested.
if ! in_guest "timeout 60 sh -c 'until systemctl is-active -q upower.service; do sleep 1; done'"; then
    in_guest "systemctl status --no-pager upower.service; journalctl -b --no-pager -u upower.service" > "$work/upower.log" 2>&1 || true
    fail "upower did not start; see $work/upower.log"
fi
in_guest "upower --dump" > "$work/upower.log" 2>&1 || fail "upower does not answer; see $work/upower.log"
grep -q "critical-action: *PowerOff" "$work/upower.log" \
    || fail "upower would not power off at an empty battery; see $work/upower.log"
in_guest "journalctl -b --no-pager -u upower.service" > "$work/upower-journal.log" 2>&1 || true
if grep -q "failed to load config file" "$work/upower-journal.log"; then
    fail "upower did not find its settings; see $work/upower-journal.log"
fi
echo "  upower answers, with its settings"

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
# Qt says so when the locale it is given (systemd's C.UTF-8) is not on
# the system, and falls back to ASCII
save_login_log
if grep -q "Detected locale" "$work/login.log"; then
    # what DMS's Quickshell was given, and what glibc makes of it
    locale_of_dms="tr '\0' '\n' < /proc/\$(pgrep -u sara -x 'qs|quickshell' | head -n 1)/environ | grep -E '^(LANG|LC_)'"
    in_guest "$locale_of_dms; locale charmap" > "$work/locale.log" 2>&1 || true
    fail "Qt found no UTF-8 locale; see $work/login.log, and its locale: $work/locale.log"
fi
echo "  Qt has the C.UTF-8 locale"

echo "4. sound"
in_guest "systemctl is-active -q alsa-restore.service && amixer -c 0 scontrols" > "$work/sound.log" 2>&1 \
    || fail "the sound card's volumes were not set (alsa-restore.service); see $work/sound.log"
echo "  the card's volumes are set"
# As sara, in their session: their PipeWire, which WirePlumber gives the card
# a moment after both start; and a sound, through ALSA's default device,
# which is PipeWire
as_sara="runuser -u sara -- env XDG_RUNTIME_DIR=/run/user/\$(id -u sara)"
in_guest "timeout 30 sh -c 'until $as_sara wpctl inspect @DEFAULT_AUDIO_SINK@; do sleep 1; done'" \
    >> "$work/sound.log" 2>&1 \
    || fail_with_login_log "WirePlumber gave PipeWire no output; see $work/sound.log"
# the card's, and not one PipeWire would make of nothing
grep -q 'node.name = "alsa_output\.' "$work/sound.log" \
    || fail "PipeWire's output is not the sound card; see $work/sound.log"
echo "  PipeWire has the card for its output"
in_guest "$as_sara aplay /usr/share/sounds/alsa/Front_Center.wav" >> "$work/sound.log" 2>&1 \
    || fail_with_login_log "no sound played through PipeWire; see $work/sound.log"
echo "  a sound played through PipeWire"

echo "5. the terminal, and FUSE"
# Alacritty in sara's session, on niri's Wayland socket, left open for a
# picture: started apart from this ssh (setsid), which would otherwise
# wait for it.  The file it makes says it ran its command.
sara_runtime=/run/user/$(in_guest "id -u sara")
wayland_display=$(in_guest "ls $sara_runtime | grep -x 'wayland-[0-9]*' | head -n 1")
[ -n "$wayland_display" ] || fail_with_login_log "sara's niri has no Wayland socket in $sara_runtime"
in_guest "setsid -f $as_sara WAYLAND_DISPLAY=$wayland_display \
    alacritty -e sh -c 'touch $sara_runtime/alacritty-ran; exec sleep 120' > /run/desktop-test/alacritty.log 2>&1" \
    || fail "could not start Alacritty as sara"
in_guest "timeout 30 sh -c 'until [ -e $sara_runtime/alacritty-ran ]; do sleep 1; done'" \
    || { in_guest "cat /run/desktop-test/alacritty.log" > "$work/alacritty.log" 2>&1 || true
         fail "Alacritty did not run its command; see $work/alacritty.log"; }
# its window, which niri lists once Alacritty has drawn into it
alacritty_window_shown() {
    in_guest "NIRI_SOCKET=$sara_socket niri msg windows" > "$work/windows.log" 2>&1 || true
    grep -q 'App ID: "Alacritty"' "$work/windows.log"
}
deadline=$(($(date +%s) + 30))
until alacritty_window_shown; do
    if [ "$(date +%s)" -ge "$deadline" ]; then
        in_guest "cat /run/desktop-test/alacritty.log" > "$work/alacritty.log" 2>&1 || true
        fail "niri shows no window of Alacritty's; see $work/windows.log and $work/alacritty.log"
    fi
    sleep 2
done
echo "  Alacritty opened a window"
sleep $qs_draws_its_first_frame
take_picture sara "$sara_socket" "$work/terminal.png"
echo "  the terminal: $work/terminal.png"
in_guest "pkill -u sara -x alacritty" || true

# fusermount3 set-user-id, as the extension's file system says, and
# libfuse 2 with fusermount by its old name
in_guest "stat -c %A /usr/bin/fusermount3; readlink /usr/bin/fusermount; ls /usr/lib/*/libfuse.so.2" \
    > "$work/fuse.log" 2>&1 || true
grep -q '^-rwsr-xr-x$' "$work/fuse.log" || fail "fusermount3 is not set-user-id; see $work/fuse.log"
grep -q '^fusermount3$' "$work/fuse.log" || fail "fusermount is not fusermount3; see $work/fuse.log"
grep -q 'libfuse\.so\.2$' "$work/fuse.log" || fail "libfuse 2 is not there; see $work/fuse.log"
# libfuse's example, mounted and read by sara, who is not root: with
# libfuse 3, and with libfuse 2, which runs fusermount3 by its old name
for program in fuse-hello fuse2-hello; do
    in_guest "cat > /run/desktop-test/$program && chmod 755 /run/desktop-test/$program" < "$work/$program"
    in_guest "$as_sara sh -c 'mkdir -p /tmp/$program && /run/desktop-test/$program /tmp/$program &&
        cat /tmp/$program/hello; fusermount3 -u /tmp/$program'" > "$work/$program.log" 2>&1 \
        || fail "sara could not mount a FUSE file system with $program; see $work/$program.log"
    grep -q '^Hello World!$' "$work/$program.log" \
        || fail "$program's file system said not what it has; see $work/$program.log"
done
echo "  sara mounted FUSE file systems with libfuse 3 and 2, and read them"

echo "6. another console"
# Pressed on the machine's keyboard, as type_on_keyboard types
press_on_keyboard() {
    printf 'sendkey %s\n' "$1" | in_machine_directory "python3 monitor.py" \
        || fail "could not press $1 on the machine's keyboard (is python3 where QEMU runs?)"
}
# What tty2 has on its screen (/dev/vcs2), and which console is shown:
# for the prompts that come and go, not a time to wait out
tty2_shows() {
    in_guest "cat /sys/class/tty/tty0/active; cat /dev/vcs2" > "$work/tty2.log" 2>&1 || true
    tty2_is_shown=no
    grep -q '^tty2$' "$work/tty2.log" && tty2_is_shown=yes
    has_the_text=no
    grep -q -F "$1" "$work/tty2.log" && has_the_text=yes
    [ $tty2_is_shown = yes ] && [ $has_the_text = yes ]
}
# wait_for_tty2_to_show <text> <what is wrong if it does not>
wait_for_tty2_to_show() {
    deadline=$(($(date +%s) + 30))
    until tty2_shows "$1"; do
        [ "$(date +%s)" -lt "$deadline" ] || fail "$2; see $work/tty2.log"
        sleep 2
    done
}
# niri hands the screen over when it is asked to, and logind then starts
# what the console has (system/usr/lib/systemd/system/autovt@.service).
# sara has a password, so it asks for a login (usr/lib/bunix/console-shell).
press_on_keyboard ctrl-alt-f2
wait_for_tty2_to_show "login:" "Ctrl+Alt+F2 shows no login prompt on tty2"
type_on_keyboard sara
wait_for_tty2_to_show "Password:" "login on tty2 did not ask for sara's password"
type_on_keyboard secret
sara_has_a_session_on_tty2() {
    in_guest "loginctl list-sessions --no-legend" > "$work/sessions.log" 2>&1 || true
    grep -q " sara .* tty2 " "$work/sessions.log"
}
deadline=$(($(date +%s) + 20))
until sara_has_a_session_on_tty2; do
    [ "$(date +%s)" -lt "$deadline" ] || fail "sara could not log in on tty2; see $work/sessions.log"
    sleep 2
done
echo "  Ctrl+Alt+F2 shows a login prompt on tty2, and sara logged in there"
# and Ctrl+Alt+F1 the desktop again, which kept running
press_on_keyboard ctrl-alt-f1
desktop_is_back() {
    in_guest "cat /sys/class/tty/tty0/active; systemctl is-active greetd.service" > "$work/tty1.log" 2>&1 || true
    tty1_is_shown=no
    grep -q '^tty1$' "$work/tty1.log" && tty1_is_shown=yes
    greetd_runs=no
    grep -q '^active$' "$work/tty1.log" && greetd_runs=yes
    [ $tty1_is_shown = yes ] && [ $greetd_runs = yes ]
}
deadline=$(($(date +%s) + 20))
until desktop_is_back; do
    [ "$(date +%s)" -lt "$deadline" ] || fail "Ctrl+Alt+F1 did not bring the desktop back; see $work/tty1.log"
    sleep 2
done
in_guest "NIRI_SOCKET=$sara_socket niri msg outputs" > "$work/outputs.log" 2>&1 \
    || fail "sara's niri does not answer after the switch back; see $work/outputs.log"
echo "  Ctrl+Alt+F1 brings sara's desktop back"

echo "7. the browser, Hudhud"
# A page of the test's, with an advertisement's script on it and an
# image from an address no list has.  The machine has no network: the
# two differ in whether Hudhud asks for them at all.  Shields stops the
# script before it is a request (shields_url_loader_factory.cc), so the
# network log has the image's address and not the script's.
advertisement=https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js
not_an_advertisement=https://example.org/hudhud-test.png
printf '%s\n' '<!doctype html><title>Hudhud test</title>' \
    "<script src=\"$advertisement\"></script>" "<img src=\"$not_an_advertisement\">" \
    | in_guest "cat > /run/desktop-test/page.html && chmod 644 /run/desktop-test/page.html"
printf '%s\n' '<!doctype html><title>Hudhud start</title>' \
    | in_guest "cat > /run/desktop-test/start.html && chmod 644 /run/desktop-test/start.html"
# Hudhud starts on a page of nothing: Shields reads its engine when the
# first page's requests are set up, and lets them through until it has
# it.  The test's page comes after, through the debugging port.
#   Its own profile, which remote debugging takes (Chromium refuses it in
# the default one); the port answers on the machine only.  Its defaults
# are built in, the same whatever the profile.  The network log's flag has Hudhud show a bar that warns of it, in the
# pictures.  On sara's session bus, as anything sara starts in their
# session is.
debugging_port=9222
in_guest "setsid -f $as_sara WAYLAND_DISPLAY=$wayland_display \
    DBUS_SESSION_BUS_ADDRESS=unix:path=$sara_runtime/bus \
    hudhud --user-data-dir=/tmp/hudhud-test --remote-debugging-port=$debugging_port \
        --log-net-log=/tmp/hudhud-net.json file:///run/desktop-test/start.html \
        > /run/desktop-test/hudhud.log 2>&1" \
    || fail "could not start Hudhud as sara"
save_hudhud_log() {
    in_guest "cat /run/desktop-test/hudhud.log" > "$work/hudhud.log" 2>&1 || true
}
# wait_until <what is wrong if it never is> <command>: a minute, at most
wait_until() {
    failure=$1
    shift
    deadline=$(($(date +%s) + 60))
    until "$@"; do
        if [ "$(date +%s)" -ge "$deadline" ]; then
            save_hudhud_log
            fail "$failure; see $work/hudhud.log"
        fi
        sleep 2
    done
}
# A window with this title, or part of it: Hudhud's, or a dialog of its
# (GTK's, with GTK's app id, so the app id is not asked)
niri_shows_window() {
    in_guest "NIRI_SOCKET=$sara_socket niri msg windows" > "$work/windows.log" 2>&1 || true
    grep -q "^  Title: \".*$1" "$work/windows.log"
}
wait_until "niri shows no window of Hudhud's (windows: $work/windows.log)" niri_shows_window "Hudhud start"
shields_reads_its_engine=5
sleep $shields_reads_its_engine
in_guest "curl -s -X PUT 'http://127.0.0.1:$debugging_port/json/new?file:///run/desktop-test/page.html'" > /dev/null \
    || fail "Hudhud's debugging port did not open the test's page"
wait_until "Hudhud did not show the test's page (windows: $work/windows.log)" niri_shows_window "Hudhud test"
echo "  Hudhud opened a window, with the test's page"
sleep $qs_draws_its_first_frame
take_picture sara "$sara_socket" "$work/browser.png"
echo "  the browser: $work/browser.png"

# A file dialog: GTK 4's, whose settings are GSettings schemas the
# extension compiles.  GLib stops a program that asks for a schema it
# does not have: the dialog is shown, or Hudhud is gone.
press_on_keyboard ctrl-o
wait_until "Ctrl+O in Hudhud shows no file dialog (windows: $work/windows.log)" niri_shows_window "Open File"
echo "  Ctrl+O shows GTK 4's file dialog"
sleep $qs_draws_its_first_frame
take_picture sara "$sara_socket" "$work/file-dialog.png"
echo "  the file dialog: $work/file-dialog.png"
press_on_keyboard esc

# The default search engine, as a person meets it: words typed in the
# address bar go to Brave Search.  The address Hudhud then shows is in
# its list of pages, from the debugging port; it cannot load it.
sleep 2
press_on_keyboard ctrl-l
type_on_keyboard hudhud
search="https://search.brave.com/search?q=hudhud"
searched_with_brave() {
    in_guest "curl -s http://127.0.0.1:$debugging_port/json/list" > "$work/hudhud-pages.json" 2>&1 || true
    grep -q -F "\"url\": \"$search" "$work/hudhud-pages.json"
}
wait_until "words typed in the address bar did not go to Brave Search (pages: $work/hudhud-pages.json)" \
    searched_with_brave
echo "  words in the address bar go to Brave Search"

# Hudhud ends as it does when closed, and its network log is whole then
in_guest "pkill -u sara -x hudhud" || true
hudhud_ended() {
    ! in_guest "pgrep -u sara -x hudhud" > /dev/null
}
wait_until "Hudhud did not end when told to" hudhud_ended
save_hudhud_log
if grep -q "Shields are off" "$work/hudhud.log"; then
    fail "Hudhud's Shields did not start; see $work/hudhud.log"
fi
if grep -q "Fontconfig error" "$work/hudhud.log"; then
    fail "Hudhud's fontconfig found no configuration (/etc/fonts); see $work/hudhud.log"
fi
if grep -q "Failed to connect to the bus" "$work/hudhud.log"; then
    fail "Hudhud is not on sara's session bus; see $work/hudhud.log"
fi
in_guest "cat /tmp/hudhud-net.json" > "$work/hudhud-net.json" 2>&1 \
    || fail "Hudhud wrote no network log"
grep -q -F "$not_an_advertisement" "$work/hudhud-net.json" \
    || fail "Hudhud did not ask for the page's image; see $work/hudhud-net.json"
if grep -q -F "$advertisement" "$work/hudhud-net.json"; then
    fail "Shields let the advertisement's script through; see $work/hudhud-net.json"
fi
echo "  Shields blocked the advertisement, and let the image through"

in_guest systemctl poweroff || true
wait "$qemu" || true
echo "desktop-test.sh: passed"
