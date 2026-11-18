#!/usr/bin/bash
# /init: the first program the kernel starts, and so far the whole of
# bunix's init system.
#
# Words on the kernel's command line that it reads:
#   demo                            say what booted and power off, for a
#                                   boot that nobody is watching
#   authorized_key=<type>:<key>     a public key that may log in as root
#                                   over SSH; without one, sshd is not started
export PATH=/usr/bin

# The kernel keeps a file system of its devices, and mounts it itself only
# on a root that is a disk.  Before this, /dev has the console and nothing
# else: no /dev/null, no terminals, no disks.
mount -t devtmpfs dev /dev
mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t tmpfs tmp /tmp
# terminals for programs that make their own (ssh, tmux), and shared
# memory: both are directories of /dev that are file systems themselves
mkdir -p /dev/pts /dev/shm
mount -t devpts devpts /dev/pts
mount -t tmpfs shm /dev/shm

hostname bunix

demo=
authorized_key=
# read -a: split into words, and nothing more; a `*` stays a `*`
read -r -a command_line < /proc/cmdline
for word in "${command_line[@]}"; do
    case $word in
        demo) demo=yes ;;
        authorized_key=*) authorized_key=${word#authorized_key=} ;;
    esac
done

power_off() {
    echo "=== powering off ==="
    # the kernel's own power-off, asked for through sysrq: there is no init
    # system yet to shut down
    echo o > /proc/sysrq-trigger
    sleep 60
}

start_sshd() {
    mkdir -p -m 700 /root/.ssh
    # the command line cannot carry the space between a key's type and the key
    echo "${authorized_key/:/ }" > /root/.ssh/authorized_keys
    # the keys this machine proves itself with: new at every boot, as
    # everything in an initramfs is
    ssh-keygen -A > /dev/null || return 1
    # sshd insists on being started by its full path
    /usr/bin/sshd
}

# ---- The network, and a way in over it -------------------------------------

ip link set lo up
# where dhcpcd keeps the addresses it was given
mkdir -p /var/lib/dhcpcd
# -b: do not wait for an address before going on; -q: say only what fails
dhcpcd -b -q

sshd_state="not started: no authorized_key on the command line"
if [ -n "$authorized_key" ]; then
    sshd_state="FAILED to start"
    ! start_sshd || sshd_state="started, root's key from the command line"
fi

echo
echo "=== bunix booted ==="
echo "kernel:     $(uname -srm)"
echo "page size:  $(getconf PAGESIZE)"
echo "init:       pid $$, bash $BASH_VERSION"
echo "root:       $(echo /*)"
echo "sshd:       $sshd_state"

[ -z "$demo" ] || power_off

# A shell that owns the console, so that Ctrl-C reaches what it runs.  When
# it exits, so does the machine: the kernel panics if /init ever returns.
setsid -c bash -i
power_off
