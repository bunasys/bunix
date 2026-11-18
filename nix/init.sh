# /init: the first program the kernel starts, and so far the whole of
# bunix's init system.  initramfs.sh puts the shell's path on the first
# line and the contents' on PATH.
#
# `demo` on the kernel's command line: say what booted and power off,
# for a boot that nobody is watching.

mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t tmpfs tmp /tmp

echo
echo "=== bunix booted ==="
echo "kernel:     $(uname -srm)"
echo "page size:  $(getconf PAGESIZE)"
echo "init:       pid $$, bash $BASH_VERSION"
echo "store:      $(ls /nix/store | wc -l) packages"

for word in $(cat /proc/cmdline); do
    if [ $word = demo ]; then
        echo "=== powering off ==="
        # the kernel's own power-off, asked for through sysrq: there is no
        # init system yet to shut down
        echo o > /proc/sysrq-trigger
        sleep 60
    fi
done

# a shell that owns the console, so that Ctrl-C reaches what it runs
exec setsid -c bash -i
