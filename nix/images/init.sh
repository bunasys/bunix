#!/bin/sh
# /init: the first program the kernel starts, and so far the whole of
# bunix's init system.
#
# `demo` on the kernel's command line: say what booted and power off,
# for a boot that nobody is watching.
export PATH=/usr/bin

# The kernel keeps a file system of its devices, and mounts it itself only
# on a root that is a disk.  Before this, /dev has the console and nothing
# else: no /dev/null, no terminals, no disks.
mount -t devtmpfs dev /dev
mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t tmpfs tmp /tmp

power_off() {
    echo "=== powering off ==="
    # the kernel's own power-off, asked for through sysrq: there is no init
    # system yet to shut down
    echo o > /proc/sysrq-trigger
    sleep 60
}

echo
echo "=== bunix booted ==="
echo "kernel:     $(uname -srm)"
echo "page size:  $(getconf PAGESIZE)"
echo "init:       pid $$, bash $BASH_VERSION"
echo "root:       $(echo /*)"

for word in $(cat /proc/cmdline); do
    [ "$word" != demo ] || power_off
done

# A shell that owns the console, so that Ctrl-C reaches what it runs.  When
# it exits, so does the machine: the kernel panics if /init ever returns.
setsid -c bash -i
power_off
