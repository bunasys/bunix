kind: manual
description: |
  Linux 6.18 (LTS) for x86_64 PCs: x86_64_defconfig plus the options in
  files/linux/x86_64.fragment.  What every machine needs to boot is built
  in; drivers for GPUs, Wi-Fi, Bluetooth and touch are signed,
  zstd-compressed modules.  Installed in /usr/lib/modules/<release>/: the
  modules, and vmlinuz, the place UAPI.9 gives the kernel image.

build-depends:
- bootstrap/build-env.bst
- base/flex.bst
- base/bc.bst
- base/elfutils.bst
- base/openssl.bst
- base/pkgconf.bst
# scripts/build_OID_registry generates the certificate parser's OID table
- base/perl.bst
# compresses the modules; depmod indexes them
- base/zstd.bst
- base/kmod.bst

sources:
- kind: tar
  url: kernel:linux/kernel/v6.x/linux-6.18.60.tar.xz
  ref: 3c2f44ef6acc021a7ad444d9a2e6ec1ef488ff09368793d0004a6080f69d621e
- kind: local
  path: files/linux
  directory: bunix

variables:
  localversion: -bunix

environment:
  # recorded in the kernel's version string (uname -v) instead of the
  # sandbox's user and host name
  KBUILD_BUILD_USER: bunix
  KBUILD_BUILD_HOST: bunix

config:
  configure-commands:
  - make x86_64_defconfig
  - scripts/kconfig/merge_config.sh -m .config bunix/x86_64.fragment
  - make olddefconfig
  - |
    # olddefconfig silently drops options whose dependencies are not met,
    # which would leave a driver out without any error
    grep -E '^(CONFIG_|# CONFIG_)' bunix/x86_64.fragment > wanted-options
    dropped=0
    while read -r option; do
      if ! grep -qxF "$option" .config; then
        echo "not applied: $option"
        dropped=1
      fi
    done < wanted-options
    exit $dropped

  build-commands:
  - make LOCALVERSION=%{localversion} bzImage modules

  install-commands:
  - |
    release=$(make -s LOCALVERSION=%{localversion} kernelrelease)
    install -D -m 0644 arch/x86/boot/bzImage %{install-root}/usr/lib/modules/$release/vmlinuz
    install -m 0644 .config %{install-root}/usr/lib/modules/$release/config
  - |
    # Signs and compresses each module on the way.  depmod runs separately:
    # the kernel's own call would look for the modules under <root>/lib.
    release=$(make -s LOCALVERSION=%{localversion} kernelrelease)
    make LOCALVERSION=%{localversion} INSTALL_MOD_PATH=%{install-root}/usr \
      INSTALL_MOD_STRIP=1 DEPMOD=true modules_install
    rm -f %{install-root}/usr/lib/modules/$release/build
    depmod -b %{install-root} $release
