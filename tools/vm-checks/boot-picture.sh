# The picture of a boot, drawn again when a GPU's driver takes the screen
# (src/boot-picture), on a bunix that was just started: run on it, as
# root, by
#
#   BUNIX_ARCHITECTURE=x86_64 BUNIX_CHECK_SCRIPT=tools/vm-checks/boot-picture.sh tools/boot-vm.sh disk check console=tty0 systemd.mask=console-shell@tty1.service
#
# systemd.mask=...: with no program at the console nothing writes text,
# and the picture stays on the screen to be looked at here.  The x86_64
# test machine has a screen, and a GPU whose driver is a module; the
# arm64 one has no screen, and passes with nothing checked.
#
# Checked here: first, that this is such a machine, with no text on its
# screen.  Then that the screen is the GPU's driver's and no longer the
# firmware's; that the driver shows something drawn through it, which is
# what a kernel that stops needs to draw its own screen on; and that what
# it shows has the picture in the middle, every row of it, dot for dot.
#
# NOT checked: the screen itself, and that of a kernel that stops now,
# which only a look shows (BUNIX_MONITOR, tools/test-machine.sh); that
# the middle is where systemd's stub drew the picture (the two were the
# same to the dot when looked at); and the black around it.
set -euo pipefail

fail() {
    echo "boot-picture.sh: FAILED: $*" >&2
    exit 1
}
screen=/sys/class/graphics/fb0
if [ ! -e $screen ]; then
    if [ "$(uname -m)" = x86_64 ]; then
        fail "no screen ($screen)"
    fi
    echo "this machine has no screen: nothing to check"
    exit 0
fi
# every device's driver loaded, and every rule run
udevadm settle

echo "the console has not written to the screen"
if dmesg | grep "fbcon: Taking over console" > /dev/null; then
    fail "the console has text on the screen: this is for a machine started with systemd.mask=console-shell@tty1.service"
fi

echo "the screen is the GPU's driver's"
driver=$(cat $screen/name)
case $driver in
    simpledrm*) fail "the screen is still the firmware's ($driver): no GPU's driver loaded" ;;
esac
echo "  $driver"
# what the program said of each screen it was run for
dmesg | grep "boot-picture:" || fail "boot-picture was not run: no line of its in dmesg (the rule: nix/base/boot-picture.rules)"

echo "the driver shows what was drawn through it"
# The kernel says of each part of a screen which picture in memory it
# shows ("fb=" and a number), or 0 for none.  A screen has several
# parts; with none of them showing one, a kernel that stops has nothing
# to draw on.
ls /sys/kernel/debug/dri/*/state > /dev/null 2>&1 \
    || fail "the kernel does not say what the screen shows (/sys/kernel/debug/dri/*/state)"
pictures_shown=$(cat /sys/kernel/debug/dri/*/state | sed -n 's/^[[:space:]]*fb=\([0-9]*\)$/\1/p' | sort -u)
[ -n "$pictures_shown" ] && [ "$pictures_shown" != 0 ] \
    || fail "the driver shows nothing drawn through it: dmesg has what boot-picture said"

echo "it has the picture in the middle, dot for dot"
picture=/usr/share/bunix/boot-picture.bmp
# a number of 4 bytes at a place in the picture's file
number_at() {
    od -An -tu4 -j "$1" -N 4 $picture | tr -d ' '
}
dots_start=$(number_at 10)
picture_width=$(number_at 18)
picture_height=$(number_at 22)
# The size of what is seen, as the program takes it: the first of the
# screen's modes, "U:1280x800p-0".  (The screen's memory may be larger.)
IFS=x read -r screen_width screen_height < <(sed -n '1s/^[A-Z]:\([0-9]*x[0-9]*\).*/\1/p' $screen/modes)
bytes_a_screen_row=$(cat $screen/stride)
left=$(((screen_width - picture_width) / 2))
top=$(((screen_height - picture_height) / 2))
# the picture's rows are kept bottom first, each a multiple of 4 bytes
bytes_a_picture_row=$(((picture_width * 3 + 3) / 4 * 4))

work=$(mktemp -d)
trap 'rm -r $work' EXIT
# Each row's dots as "blue green red", a line a dot: so the picture's
# file has them, and so this screen keeps them, with a fourth byte that
# is no colour.  od starts a line with a space, so the three bytes are
# cut's fields 2 to 4.
for row in $(seq 0 $((picture_height - 1))); do
    row_start_in_the_file=$((dots_start + (picture_height - 1 - row) * bytes_a_picture_row))
    row_start_on_the_screen=$(((top + row) * bytes_a_screen_row + left * 4))
    od -An -v -tx1 -w3 -j $row_start_in_the_file -N $((picture_width * 3)) $picture > $work/picture
    od -An -v -tx1 -w4 -j $row_start_on_the_screen -N $((picture_width * 4)) /dev/fb0 | cut -d' ' -f1-4 > $work/screen
    cmp -s $work/picture $work/screen \
        || fail "row $row of the picture is not on the screen where it is to be ($left dots from the left, $((top + row)) from the top)"
done

echo "boot-picture.sh: passed"
