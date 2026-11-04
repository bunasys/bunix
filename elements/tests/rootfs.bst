kind: manual
description: |
  Runs the root file system on its own.  It is staged alone at / -- no
  toolchain, no build environment -- so these commands run with the image's
  own shell, tools and dynamic loader, exactly as on the booted system.
  Checks that every ELF file's libraries resolve, that the layout follows
  the UAPI.9 hierarchy, and that the programs start.

build-depends:
- system/rootfs.bst

config:
  build-commands:
  - |
    # Every library every program and library needs, resolved by the image's
    # loader -- which also follows each file's RUNPATH.
    loader=/usr/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2
    unresolved=0
    for f in $(find /usr -type f); do
      is_elf=$(head -c 4 "$f" | tail -c 3)
      [ "$is_elf" = ELF ] || continue
      missing=$($loader --list "$f" 2>&1 | grep 'not found') || true
      if [ -n "$missing" ]; then
        echo "UNRESOLVED in $f: $missing"
        unresolved=1
      fi
    done
    exit $unresolved

  - |
    # https://uapi-group.org/specifications/specs/linux_file_system_hierarchy/
    deviations=0
    expect_link() {
      if [ "$(readlink "$1")" != "$2" ]; then
        echo "$1 should be a symlink to $2"
        deviations=$((deviations + 1))
      fi
    }
    expect_link /bin usr/bin
    expect_link /sbin usr/bin
    expect_link /lib usr/lib
    expect_link /lib64 usr/lib/x86_64-linux-gnu
    expect_link /usr/sbin bin
    expect_link /var/run ../run
    expect_link /etc/os-release ../usr/lib/os-release
    expect_link /usr/bin/sh bash
    expect_link /usr/bin/vi nvim
    expect_link /usr/local ../var/usrlocal
    # places packages put files by default that the hierarchy rules out
    for dir in /usr/libexec /usr/etc /usr/lib64 /opt; do
      if [ -e $dir ]; then
        echo "$dir should not exist: $(find $dir -mindepth 1 | head -3 | tr '\n' ' ')"
        deviations=$((deviations + 1))
      fi
    done
    for dir in /etc /home /root /srv /tmp /var/tmp /var/lib /var/log /var/cache /usr/share; do
      if [ ! -d $dir ]; then
        echo "$dir is missing"
        deviations=$((deviations + 1))
      fi
    done
    exit $deviations

  - |
    for cmd in \
      "bash --version" "fish --version" "busybox --help" "ls --version" \
      "find --version" "xargs --version" "rg --version" "grep --version" \
      "nvim --version" "less --version" "htop --version" \
      "ps --version" "free --version" "pstree --version" "killall --version" \
      "lsblk --version" "mount --version" "fdisk --version" \
      "ifconfig --version" "netstat --version" \
      "dig -v" "delv -v" "nsupdate -V" \
      "curl --version" "openssl version" "getent --help" \
      "systemctl --version" "networkctl --version" "resolvectl --version" \
      "dbus-daemon --version" "iwctl --help" \
      "sqv --version" "nawa --version" "updatectl --version" "systemd-sysext --version" \
      "/usr/lib/systemd/systemd-sysupdate --version" "/usr/lib/systemd/systemd-pull --version" \
      "efibootmgr --version" "mkfs.vfat --help" "sfdisk --version" \
      "ip -V" "ss -V" "bridge -V" "rsync --version" "tar --version" \
      "lspci --version" "lsusb --version" "nvme version" "smartctl --version" \
      "mokutil --version" "cryptsetup --version" "veritysetup --version" \
      "hostnamectl --version" "timedatectl --version" "zdump --version"
    do
      echo "== $cmd"
      # some print their version and exit non-zero; what counts is that the
      # program exists and starts
      out=$($cmd 2>&1) || true
      echo "$out" | head -2
      program=${cmd%% *}
      if ! command -v "$program" > /dev/null; then
        echo "MISSING: $program"; failed=1
      fi
      case $out in
        *"error while loading shared libraries"*) echo "BROKEN: $program"; failed=1 ;;
      esac
    done
    exit ${failed:-0}

  - |
    # udev's hardware database is compiled (system/rootfs.bst)
    test -s /usr/lib/udev/hwdb.bin
    # GNU tar and iproute2 replace BusyBox's, and the time zones are there
    tar --version | grep -q 'GNU tar'
    test "$(readlink /usr/bin/ip)" != busybox
    test -f /usr/share/zoneinfo/Europe/Berlin
    test -f /usr/share/zoneinfo/tzdata.zi
    TZ=Asia/Tokyo date +%Z | grep -qx JST

  - |
    # neovim finds its tree-sitter parsers in the multiarch $libdir
    loaded=$(nvim --headless +'lua io.stdout:write(tostring(vim.treesitter.language.add("lua")))' +q 2>&1)
    test "$loaded" = true

  - |
    # the users the enabled daemons run as, and root's login shell
    for user in messagebus systemd-network systemd-resolve systemd-timesync; do
      getent passwd $user > /dev/null || { echo "no user $user"; exit 1; }
    done
    getent passwd root | grep -q ':/usr/bin/fish$'

  - |
    # What is enabled: the network stack, Wi-Fi, the console shells,
    # extensions and boot counting.  Enabled in /usr (an installed system's
    # /etc starts empty), so systemctl is-enabled, which looks in /etc,
    # does not see it: the links are checked instead.
    cd /usr/lib/systemd/system
    for unit in systemd-networkd.service systemd-resolved.service \
                systemd-timesyncd.service iwd.service console-shell@tty1.service \
                systemd-sysext.service systemd-boot-check-no-failures.service \
                zram-swap.service nftables.service systemd-machine-id-commit.service; do
      linked=$(ls -d *.wants/$unit *.requires/$unit 2>/dev/null || true)
      [ -n "$linked" ] || { echo "$unit is not enabled"; exit 1; }
    done
    test "$(readlink default.target)" = multi-user.target
    # the journal survives a reboot; PCI devices power down when idle
    grep -qx 'Storage=persistent' /usr/lib/systemd/journald.conf.d/bunix.conf
    grep -q 'power/control}="auto"' /usr/lib/udev/rules.d/60-bunix-power.rules
    test -z "$(ls -A /etc/systemd/system)"
    # no link to a unit that is not there
    dangling=$(find /usr/lib/systemd/system -xtype l)
    [ -z "$dangling" ] || { echo "dangling unit links: $dangling"; exit 1; }
    # the installer, which runs only on the live ISO
    test -x /usr/bin/bunix-install

  - |
    # Updates (docs/updates.md): the release version, the gcc feature,
    # and gpg being only sqv's manifest check
    . /usr/lib/os-release
    test -n "$IMAGE_VERSION" && test "$SYSEXT_LEVEL" = "$IMAGE_VERSION"
    grep -q '^ImagePolicy=root=signed+absent:usr=signed+absent$' \
      /usr/lib/systemd/sysext.conf.d/bunix.conf
    # bunix's release certificate (armored), not systemd's own keyring
    head -1 /usr/lib/systemd/import-pubring.pgp | grep -q 'BEGIN PGP PUBLIC KEY BLOCK'
    if gpg --version > /dev/null 2>&1; then
      echo "gpg should refuse everything but the manifest check"; exit 1
    fi
