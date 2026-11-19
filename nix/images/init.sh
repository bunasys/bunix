#!/usr/bin/bash
# /init: the first program the kernel starts, and so far the whole of
# bunix's init system.
#
# Words on the kernel's command line that it reads:
#   demo                            say what booted and power off, for a
#                                   boot that nobody is watching
#   authorized_key=<type>:<key>     a public key that may log in as root
#                                   over SSH, for this boot.  sshd is started
#                                   when there is one, or when root has keys
#                                   of its own on a disk.
#   usb_link[=ncm|ecm]              be a serial port and a network adapter
#                                   to the computer on each USB-C port, and
#                                   give that computer a root shell on the
#                                   serial port (usb-link.sh).  For bringing
#                                   a machine up: whoever holds the cable is
#                                   root.  Not working on a Mac yet.
#
# A machine with a partition named bunix-root keeps /var, /home and /root
# on it ("What outlasts a boot", below).
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
usb_link=
# read -a: split into words, and nothing more; a `*` stays a `*`
read -r -a command_line < /proc/cmdline
for word in "${command_line[@]}"; do
    case $word in
        demo) demo=yes ;;
        authorized_key=*) authorized_key=${word#authorized_key=} ;;
        usb_link) usb_link=ncm ;;
        usb_link=ncm|usb_link=ecm) usb_link=${word#usb_link=} ;;
    esac
done

power_off() {
    echo "=== powering off ==="
    # What was written to a disk has to reach it: the kernel's power-off,
    # below, waits for nothing, and there is no init system to shut down
    # first.  The partition is in use, by this shell if by nothing else,
    # so it is made read-only where it cannot be unmounted.
    sync
    [ ! -d /sysroot ] || mount -o remount,ro /sysroot
    # the kernel's own power-off, asked for through sysrq
    echo o > /proc/sysrq-trigger
    sleep 60
}

start_sshd() {
    # The command line's key is for this boot, and kept apart from root's
    # own keys, which may be on a disk and are not this script's to
    # rewrite.  (The command line cannot carry the space between a key's
    # type and the key.)
    [ -z "$authorized_key" ] || echo "${authorized_key/:/ }" > /run/authorized_keys
    # The keys this machine proves itself with are made once and kept in
    # /var, which outlasts a boot where there is a disk for it; sshd looks
    # for them in /etc/ssh.  (-f: under this directory, in its etc/ssh.)
    mkdir -p /var/lib/sshd/etc/ssh
    ssh-keygen -A -f /var/lib/sshd > /dev/null || return 1
    cp -p /var/lib/sshd/etc/ssh/ssh_host_* /etc/ssh/ || return 1
    # sshd insists on being started by its full path
    /usr/bin/sshd -o "AuthorizedKeysFile=.ssh/authorized_keys /run/authorized_keys"
}

# Wi-Fi: iwd, and the bus it is spoken to over.  It joins a network when
# told to (`iwctl station wlan0 connect <name>`), and dhcpcd then asks that
# network for an address as it does any other.
start_wifi() {
    mkdir -p /run/dbus /var/lib/dbus /var/lib/iwd
    # the bus wants the machine to have an identity
    dbus-uuidgen --ensure || return 1
    # --nosyslog: nothing here reads the system's log; what the bus has to
    # say goes to the console
    dbus-daemon --system --nosyslog || return 1
    # By its full path: it is not among the programs of /usr/bin.  It does
    # not leave the foreground by itself, and would write over the console.
    /usr/lib/iwd/iwd > /run/iwd.log 2>&1 &
    # it gives up at once if the kernel lacks something it needs
    sleep 1
    kill -0 $!
}

# ---- What outlasts a boot ----------------------------------------------------

# Everything above the kernel is in memory, and gone when the machine is
# turned off.  A machine with a partition named bunix-root keeps on it
# what a system's writable partition holds, in the same places: /var
# (the keys of sshd, the networks iwd has joined, the addresses dhcpcd was
# given), /home and /root.  /usr and /etc are still the image's.
#
# By its name, and not by its type, as systemd will find it: another
# Linux on the same disk has a root partition of that type too, and it is
# not this system's to check and mount.

# A disk appears a moment after /init starts; a machine with no such
# partition, as a virtual one, waits these five seconds for nothing.
find_bunix_root() {
    local try
    for try in 1 2 3 4 5 6 7 8 9 10; do
        ! blkid -t PARTLABEL=bunix-root -o device || return 0
        sleep 0.5
    done
    return 1
}

mount_bunix_root() {
    local partition=$1 e2fsck_status directory
    # -p: repair what is safe to repair without asking; more than that
    # (a status of 4 and up) is a person's to look at
    e2fsck -p "$partition" > /run/e2fsck.log 2>&1
    e2fsck_status=$?
    [ $e2fsck_status -lt 4 ] || return 1
    mkdir -p /sysroot
    mount "$partition" /sysroot || return 1
    for directory in var home root; do
        mkdir -p /sysroot/$directory
        mount --bind /sysroot/$directory /$directory || return 1
    done
    # What the image's /var has (initramfs.sh), the disk's has to have too:
    # the directories, and the link for programs that look for /run there
    # (iwd, for the bus).  -T: a directory in the link's place is an error,
    # not somewhere to put the link.
    mkdir -p /var/lib /var/log /var/tmp || return 1
    ln -sfnT ../run /var/run
}

disk_state="none: no partition named bunix-root; nothing outlasts this boot"
bunix_root=$(find_bunix_root)
if [ -n "$bunix_root" ]; then
    disk_state="FAILED to use $bunix_root; e2fsck's log is /run/e2fsck.log"
    ! mount_bunix_root "$bunix_root" || disk_state="/var, /home and /root are on $bunix_root (bunix-root)"
fi

# ---- The network, and a way in over it -------------------------------------

ip link set lo up
# Every account may ping: ping then needs no rights of root's.  The
# kernel's own setting is that none may; systemd is what changes it on
# other systems.
sysctl -q -w net.ipv4.ping_group_range="0 2147483647"

# The link is put together by a program of its own, beside the rest of
# /init: the ports it needs appear some seconds from now.
usb_link_state="not asked for (usb_link on the command line)"
if [ -n "$usb_link" ]; then
    /usr/lib/bunix/usb-link $usb_link > /run/usb-link.log 2>&1 &
    usb_link_state="being set up, $usb_link network (/run/usb-link.log); not working on a Mac yet"
fi

wifi_state="FAILED to start; iwd's log is /run/iwd.log"
! start_wifi || wifi_state="iwd is running; join a network with iwctl"

# where dhcpcd keeps the addresses it was given
mkdir -p /var/lib/dhcpcd
# -b: do not wait for an address before going on; -q: say only what fails
dhcpcd -b -q

sshd_state="not started: no authorized_key on the command line, and none of root's own"
if [ -n "$authorized_key" ] || [ -s /root/.ssh/authorized_keys ]; then
    sshd_state="FAILED to start"
    ! start_sshd || sshd_state="started"
fi

echo
echo "=== bunix booted ==="
echo "kernel:     $(uname -srm)"
echo "page size:  $(getconf PAGESIZE)"
echo "init:       pid $$, bash $BASH_VERSION"
echo "root:       $(echo /*)"
echo "disk:       $disk_state"
echo "sshd:       $sshd_state"
echo "wifi:       $wifi_state"
echo "usb link:   $usb_link_state"

[ -z "$demo" ] || power_off

# A shell that owns the console, so that Ctrl-C reaches what it runs.  When
# it exits, so does the machine: the kernel panics if /init ever returns.
setsid -c bash -i
power_off
