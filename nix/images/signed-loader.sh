# systemd-boot signed for Secure Boot (images/system.nix, x86): what shim
# starts, beside it on the ESP, as grubx64.efi (bunix-install, the live
# stick), and asks the firmware's or its own keys (MOK) about first.  In
# /usr beside the unsigned one, as systemd names such a file
# (systemd-bootx64.efi.signed).
#
# A test system's is signed here, with the development key, by the
# script a release's is signed with.  A release's is signed where the key
# is (tools/publish.sh), and handed to this build, which takes it if it
# is this systemd-boot (check-release-signed.sh).
set -euo pipefail
cd /build

loader=$(echo /usr/lib/systemd/boot/efi/systemd-boot*.efi)
[ -f "$loader" ]
directory=$out/usr/lib/systemd/boot/efi
mkdir -p $directory
signed=$directory/$(basename $loader).signed

# And the certificate of the key it is signed by, as MokManager takes one
# from a disk (DER): what a PC's owner enrols on its first start from
# bunix, where shim does not know the key yet (bunix-install puts it on
# the ESP, as bunix.cer)
certificate=$development_certificate
if [ -n "$release_signed" ]; then
    certificate=$release_certificate
fi
mkdir -p $out/usr/share/bunix
openssl x509 -in $certificate -outform DER -out $out/usr/share/bunix/secure-boot.cer

if [ -z "$release_signed" ]; then
    BUNIX_SECURE_BOOT_KEY_FILE=$development_key BUNIX_SECURE_BOOT_CERTIFICATE=$development_certificate \
        bash $sign_kernel_image $loader $signed
    exit 0
fi
bash $check_release_signed $loader $release_signed
cp $release_signed $signed
