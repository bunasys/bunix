# What a boot shows on the screen, on a bunix that was just started: run
# on it, as root, by
#
#   BUNIX_ARCHITECTURE=x86_64 BUNIX_CHECK_SCRIPT=tools/vm-checks/boot-screen.sh tools/boot-vm.sh disk check console=tty0
#
# console=tty0, last: the screen is then where systemd writes, as on a
# PC, and not the test machine's serial port.  The x86_64 test machine
# has a screen; the arm64 one has none, and only the first step is
# checked there.
#
# Checked here: a kernel that stops would say so with a QR code.  Then,
# of the picture a boot shows (docs/nix-usr-system.md, "What a boot
# shows"): the console waited for text before it took the screen, and no
# text was written before the console's own program started -- none of
# the kernel's, none of systemd's.
#
# NOT checked: the picture itself and the mark on the screen of a kernel
# that stops, which only a look at the screen shows (BUNIX_MONITOR,
# tools/test-machine.sh); a kernel stopping; and that the kernel image
# asks for a quiet boot by itself (tools/boot-vm.sh asks too).
set -euo pipefail

fail() {
    echo "boot-screen.sh: FAILED: $*" >&2
    exit 1
}

echo "a kernel that stops shows a QR code of what it last said"
panic_screen_setting=/sys/module/drm/parameters/panic_screen
[ -e $panic_screen_setting ] || fail "this kernel has no screen for when it stops (CONFIG_DRM_PANIC, nix/boot/linux/)"
panic_screen=$(cat $panic_screen_setting)
[ "$panic_screen" = qr_code ] || fail "a kernel that stops would show: $panic_screen"

if [ ! -e /sys/class/graphics/fb0 ]; then
    if [ "$(uname -m)" = x86_64 ]; then
        fail "no screen (/sys/class/graphics/fb0): the kernel did not take the firmware's"
    fi
    echo "this machine has no screen: no more to check"
    echo "boot-screen.sh: passed"
    exit 0
fi

echo "the console waited for text before it took the screen"
# the kernel's log since it started, each line with its time since then
log=$(dmesg)
[[ $log == *"fbcon: Deferring console take-over"* ]] \
    || fail "the console did not wait (CONFIG_FRAMEBUFFER_CONSOLE_DEFERRED_TAKEOVER, nix/boot/linux/), or the kernel's log has lost its first lines: this is for a machine just started"

echo "no text was written to the screen before the console's own program"
# tty1 is the screen's console, and this has it: root's shell, or the
# login prompt.  (The serial ports have their own: system-preset.)
console_unit=console-shell@tty1.service
# A program that was started again has the time of that start, not of
# the boot's.
restarts=$(systemctl show -p NRestarts --value $console_unit)
[ "$restarts" = 0 ] || fail "$console_unit has started $restarts times more since the boot: this is for a machine just started"
program_started_at=$(systemctl show -p ExecMainStartTimestampMonotonic --value $console_unit)
[[ $program_started_at =~ ^[1-9][0-9]*$ ]] || fail "$console_unit has not started"

# The console takes the screen at the first text written to it.  If that
# was not before the program started, the first text was the program's.
# The program may not have written yet: it is waited for.
taking_the_screen='s/^\[ *\([0-9]*\)\.\([0-9]*\)\] fbcon: Taking over console$/\1\2/p'
screen_taken_at=
for attempt in 1 2 3 4 5 6 7 8 9 10; do
    screen_taken_at=$(dmesg | sed -n "$taking_the_screen" | head -n 1)
    [ -z "$screen_taken_at" ] || break
    sleep 1
done
[ -n "$screen_taken_at" ] || fail "the console never took the screen, though $console_unit writes to it"

# Both times are in microseconds since the kernel started: the log's
# "[    6.123456]" without its dot, and systemd's as it is.  10#: a time
# under one second starts with 0, which bash would read as octal.
screen_taken_at=$((10#$screen_taken_at))
# the two clocks are not one: a tenth of a second is allowed between them
allowed_difference=100000
earliest_allowed=$((program_started_at - allowed_difference))
if [ "$screen_taken_at" -lt "$earliest_allowed" ]; then
    fail "text was on the screen $((screen_taken_at / 1000)) ms after the kernel started, before $console_unit ($((program_started_at / 1000)) ms): dmesg before 'fbcon: Taking over console' has the kernel's text, journalctl -b systemd's"
fi

echo "boot-screen.sh: passed"
