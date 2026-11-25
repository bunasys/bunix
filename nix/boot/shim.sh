# shim and its helpers for x86_64, signed by Microsoft (boot.nix): Debian's
# builds, the only programs of what starts a PC that are not built here.
# A PC's firmware with Secure Boot on starts what Microsoft's UEFI CA
# signed, and Microsoft signs shim, not what a distribution builds; shim
# then starts what a key in its own list (MOK) or the firmware's signed,
# which is where bunix's key goes.  Taken as they are: a byte changed and
# the signature no longer holds.  (As 0.4.0's elements/system/shim.bst.)
#
# A .deb is an ar archive, its files in data.tar.xz.
mkdir shim-signed shim-helpers
(cd shim-signed && ar x $src && tar -xf data.tar.xz)
(cd shim-helpers && ar x $shim_helpers && tar -xf data.tar.xz)
shims=$out/usr/lib/shim
install -D -m 644 shim-signed/usr/lib/shim/shimx64.efi.signed $shims/shimx64.efi
# MokManager, which shim starts to enrol a key (bunix's) that a person
# confirms at the machine's screen
install -D -m 644 shim-helpers/usr/lib/shim/mmx64.efi.signed $shims/mmx64.efi
# its licence, which goes where its files go
install -D -m 644 shim-signed/usr/share/doc/shim-signed/copyright $out/usr/share/doc/shim/copyright
