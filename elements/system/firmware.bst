kind: manual
description: |
  Device firmware from linux-firmware, cut down to what the kernel's
  modules (system/linux.bst) load on PCs and laptops: GPUs (Intel, AMD),
  Wi-Fi and Bluetooth (Intel, Qualcomm/Atheros, Realtek, MediaTek,
  Broadcom), Intel's touch and sensor hub, the wired NICs that need it.
  zstd-compressed, in /usr/lib/firmware.  About 240 MB of linux-firmware's
  2 GB; most of the rest is for servers, phones, routers, TV tuners and
  sound DSPs.

build-depends:
- bootstrap/build-env.bst
- base/zstd.bst

sources:
- kind: tar
  url: kernel:linux/kernel/firmware/linux-firmware-20261019.tar.xz
  ref: a10d1ab5baf2c74ba92e8c7cf313e691696c26bddfa6df00db795e48d70cd4ca

config:
  build-commands:
  # every file compressed, with the links WHENCE names
  - ./copy-firmware.sh --zstd -j$(nproc) all-firmware

  install-commands:
  - |
    cd all-firmware
    # whole directories, and file patterns within shared ones
    keep="
      i915 xe amdgpu radeon
      intel/iwlwifi intel/ibt-* intel/ish
      ath9k_htc ath10k/QCA6174 ath10k/QCA9377
      ath11k/QCA6390 ath11k/QCA2066 ath11k/WCN6855 ath12k/WCN7850 qca
      rtw88 rtw89 rtl_bt rtlwifi rtl_nic
      mediatek/WIFI_* mediatek/BT_* mediatek/mt7925
      brcm cypress
      tigon bnx2
    "
    mkdir -p %{install-root}/usr/lib/firmware
    for path in $keep; do
      cp -a --parents $path %{install-root}/usr/lib/firmware/
    done
    # The names drivers ask for are often links at the top
    # (iwlwifi-*.ucode -> intel/iwlwifi/...): all of them, minus those into
    # what was left out
    find . -maxdepth 1 -type l -exec cp -a {} %{install-root}/usr/lib/firmware/ \;
    find %{install-root}/usr/lib/firmware -xtype l -delete
    du -sh %{install-root}/usr/lib/firmware
  - |
    install -d %{install-root}/usr/share/licenses/linux-firmware
    cp -a WHENCE LICENSE LICENSES %{install-root}/usr/share/licenses/linux-firmware/
