# Device firmware

bunix ships no firmware. Wi-Fi chips (and some others) need theirs, so it is
added per machine: put the files here, laid out as they go under
`/usr/lib/firmware`, for example

    firmware/iwlwifi-so-a0-gf-a0-89.ucode
    firmware/rtw89/rtw8852b_fw.bin

and build `system/iso.bst` again. The files become a second initramfs on the
ISO, `boot/firmware.img`, which GRUB loads with the system's own. Plain or
zstd-compressed (`.zst`) files both work.

Everything in this directory except this README goes into the image.
