#!/usr/bin/bash
# usb-link [ncm|ecm]: makes this machine a USB device to the computer at
# the other end of each USB-C cable: a serial port with a root shell on
# it, and a network adapter (ncm, or the older ecm).  In the image as
# /usr/lib/bunix/usb-link, to be run by hand, as root.  For bringing a
# machine up: whoever holds the cable is root.
#
# Not working on a Mac yet: with this kernel the other computer sees the
# device and never configures it (docs/nix-usr-system.md, "On a Mac").
#
# A USB-C port of a Mac is a host's, for keyboards and disks, until it is
# told to be a device's; then it is what the kernel's configfs describes.
# One such device for each port, since the cable can be in any.
export PATH=/usr/bin
network=${1:-ncm}

[ -d /sys/kernel/config/usb_gadget ] || mount -t configfs configfs /sys/kernel/config || exit 1

# The ports' controllers appear some seconds after the kernel starts, and
# a port's device side only once it is told to be a device.
for second in $(seq 60); do
    for role in /sys/class/usb_role/*/role; do
        [ ! -e "$role" ] || echo device > "$role"
    done
    ! ls /sys/class/udc 2> /dev/null | grep -q . || break
    sleep 1
done
# the second port's, if the first was the one seen
sleep 2

port=0
for controller in /sys/class/udc/*; do
    [ -e "$controller" ] || continue
    port=$((port + 1))
    gadget=/sys/kernel/config/usb_gadget/port$port
    mkdir -p $gadget/strings/0x409 $gadget/configs/c.1 \
        $gadget/functions/acm.usb $gadget/functions/$network.usb || continue
    # the Linux Foundation's numbers for a device of several functions
    echo 0x1d6b > $gadget/idVendor
    echo 0x0104 > $gadget/idProduct
    echo bunix > $gadget/strings/0x409/manufacturer
    echo "bunix USB link" > $gadget/strings/0x409/product
    # fixed, so that the other computer sees the same adapter at every boot
    echo 02:00:00:00:0$port:02 > $gadget/functions/$network.usb/dev_addr
    echo 02:00:00:00:0$port:01 > $gadget/functions/$network.usb/host_addr
    ln -s $gadget/functions/acm.usb $gadget/functions/$network.usb $gadget/configs/c.1/
    echo ${controller##*/} > $gadget/UDC || continue
    echo "port $port: ${controller##*/}"

    serial=/dev/ttyGS$((port - 1))
    [ -e $serial ] || continue
    # The shell on the serial port: started again when it ends.
    ( while true; do
          setsid -c bash -i < $serial > $serial 2>&1
          sleep 1
      done ) &
done
[ $port != 0 ] || echo "no USB port became a device"
