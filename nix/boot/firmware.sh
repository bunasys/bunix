# /usr/lib/firmware: what PCs' devices are started with (boot.nix).
unpack $src

# every file compressed, with the links WHENCE names.  One at a time:
# its -j wants GNU parallel, which is not a package here.
./copy-firmware.sh --zstd all-firmware

cd all-firmware
# whole directories, and file patterns within shared ones
keep="
  i915 xe amdgpu radeon
  intel/iwlwifi intel/ibt-* intel/ish LENOVO/ish HP/ish dell/ish
  ath9k_htc ath10k/QCA6174 ath10k/QCA9377
  ath11k/QCA6390 ath11k/QCA2066 ath11k/WCN6855 ath12k/WCN7850 qca
  rtw88 rtw89 rtl_bt rtlwifi rtl_nic
  mediatek/WIFI_* mediatek/BT_* mediatek/mt7925
  brcm cypress
  tigon bnx2
"
firmware=$out/usr/lib/firmware
mkdir -p $firmware
for path in $keep; do
    cp -a --parents $path $firmware/
done
# The names drivers ask for are often links at the top
# (iwlwifi-*.ucode -> intel/iwlwifi/...): all of them, minus those into
# what was left out
find . -maxdepth 1 -type l -exec cp -a {} $firmware/ \;
find $firmware -maxdepth 1 -xtype l -delete
# Some of Broadcom's files are settings for one board each, under the
# board's name as its firmware spells it, with spaces: a few tablets,
# and Raspberry Pis.  An image cannot carry such a name
# (images/image.sh), and those boards' Wi-Fi goes without.
find $firmware -name '* *' -print -delete

# Not as the element, which dropped every link that led nowhere: inside
# what is kept, such a link is a file some machine asks for and would
# not get (the sensor hubs of three makers' laptops were, before their
# directories joined the list above).
if find $firmware -xtype l | grep .; then
    echo "firmware.sh: the links above lead to what is not kept" >&2
    exit 1
fi
# copy-firmware.sh goes on when a file cannot be compressed, and ends
# well: every file is read back here.
find $firmware -name '*.zst' -type f -exec zstd -q -t {} +
du -sh $firmware
cd ..

install -d $out/usr/share/licenses/linux-firmware
cp -a WHENCE LICENSE LICENSES $out/usr/share/licenses/linux-firmware/
