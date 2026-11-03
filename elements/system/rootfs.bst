kind: manual
description: |
  The root file system: the packages of base.bst and bunix's own
  configuration (files/rootfs), plus glibc and gcc's runtime libraries from
  the toolchain, made into a bootable system.  Build-only files are removed,
  commands get their names, units are enabled, system users created and
  binaries stripped.  tests/rootfs.bst checks the result.

(@): include/release.yml

build-depends:
- bootstrap/build-env.bst
# staged off to the side: the tools building this image are at /
- filename: base.bst
  config:
    location: "%{sysroot}"

sources:
- kind: local
  path: files/rootfs
  directory: config

variables:
  # runs one of the image's own programs here, with the image's libraries
  in-image: >-
    env LD_LIBRARY_PATH=%{install-root}%{libdir}:%{install-root}%{libdir}/systemd

config:
  install-commands:
  - |
    # the packages, then bunix's configuration over them
    cp -a %{sysroot}/. %{install-root}/
    cp -a config/. %{install-root}/
    # the release: what updates are fetched for, and what extension images
    # must have been built for (include/release.yml)
    printf 'IMAGE_VERSION=%s\nSYSEXT_LEVEL=%s\n' %{release-version} %{release-version} \
      >> %{install-root}/usr/lib/os-release

  - |
    # glibc and gcc's runtime libraries, from the toolchain everything was
    # built with (staged at / here): only what programs load at run time.
    # Rust programs link libgcc_s for unwinding.
    cd %{libdir}
    cp -a ld-linux-x86-64.so.2 libc.so.6 libm.so.6 libmvec.so.1 libresolv.so.2 \
          libanl.so.1 libnss_files.so.2 libnss_dns.so.2 libnss_compat.so.2 \
          libpthread.so.0 libdl.so.2 librt.so.1 libutil.so.1 libgcc_s.so.1 \
          %{install-root}%{libdir}/
    cp -a /usr/bin/ldconfig /usr/bin/getent %{install-root}%{bindir}/

  - |
    # what is only needed to build software: headers, static libraries,
    # pkg-config and cmake files, documentation, translations, and the
    # *-config scripts and terminfo compilers
    cd %{install-root}
    rm -rf usr/include .%{libdir}/pkgconfig .%{libdir}/cmake usr/share/pkgconfig \
           usr/share/aclocal usr/share/man usr/share/doc usr/share/info \
           usr/share/locale usr/share/gettext usr/share/bash-completion usr/share/zsh \
           usr/share/fish/man usr/share/fish/groff
    find .%{libdir} -maxdepth 1 \( -name '*.a' -o -name '*.la' \) -delete
    cd usr/bin
    rm -f tic infocmp toe tabs captoinfo infotocap ncursesw6-config ncurses6-config \
          curl-config xmlwf c_rehash fish_key_reader
    rm -rf %{install-root}/etc/ssl/misc

  - |
    # systemd components this system never starts: no sleep, no remote
    # journals, no portable services, no user sessions.  Kept for installed
    # systems (docs/updates.md, step 2): fsck, update-done (first boot with
    # an empty /etc), repart (creates the root partition), boot counting
    # (bless-boot, boot-check-no-failures), and the generators that find and
    # mount /usr and the root partition.
    cd %{install-root}/usr/lib/systemd
    for helper in battery-check factory-reset growfs \
                  journal-remote makefs mountfsd mountwork nsresourced nsresourcework \
                  pstore reply-password report report-basic report-cgroup \
                  sleep socket-proxyd ssh-issue ssh-proxy storage-block storage-fs \
                  sulogin-shell update-helper \
                  validatefs xdg-autostart-condition; do
      rm -f systemd-$helper
    done
    rm -rf tests boot user user-* initrd-preset varlink-bridges profile.d \
           ssh_config.d user.conf.d user-generators user-environment-generators
    cd system-generators
    for generator in *; do
      case $generator in
        systemd-gpt-auto-generator|systemd-veritysetup-generator|systemd-fstab-generator|\
        systemd-bless-boot-generator) ;;
        *) rm -f "$generator" ;;
      esac
    done
    cd %{install-root}
    # ukify assembles boot images at build time (system/uki.bst); it needs
    # Python, which the system does not have
    rm -f usr/bin/ukify usr/lib/systemd/ukify
    rm -rf usr/share/systemd usr/lib/environment.d usr/lib/binfmt.d \
           usr/lib/modprobe.d usr/lib/modules-load.d usr/lib/sysctl.d/50-coredump.conf \
           usr/share/polkit-1 usr/lib/dbus-1.0/dbus-daemon-launch-helper
    # ...and their unit files, so `systemctl list-unit-files` shows only what exists
    cd usr/lib/systemd/system
    for pattern in '*ssh*' 'systemd-sleep*' 'systemd-hibernate*' 'systemd-suspend*' \
                   'systemd-storage*' 'systemd-mountfsd*' 'systemd-nsresourced*' \
                   'systemd-pstore*' 'systemd-journal-remote*' 'systemd-battery*' \
                   'systemd-factory-reset*' \
                   'systemd-growfs*' 'systemd-update-utmp*' \
                   'systemd-validatefs*' 'systemd-xdg-*' 'systemd-quotacheck*' \
                   'systemd-confext*' \
                   'systemd-firstboot*' 'systemd-vconsole*' 'systemd-binfmt*' \
                   'systemd-hwdb*' 'systemd-random-seed*' 'systemd-backlight*' \
                   'systemd-rfkill*' 'systemd-oomd*' 'systemd-userdbd*' 'systemd-homed*' \
                   'systemd-machined*' 'systemd-importd*' 'systemd-portabled*' \
                   'systemd-nspawn*' 'systemd-coredump*' 'systemd-modules-load*' \
                   'systemd-tpm2*' 'systemd-pcr*' 'systemd-creds*' 'systemd-bsod*' \
                   'systemd-storagetm*' 'systemd-time-wait-sync*' \
                   'systemd-localed*' 'systemd-hostnamed*' \
                   'systemd-ask-password*' 'getty*' 'serial-getty*' 'console-getty*' \
                   'autovt*' 'systemd-mute-console*' \
                   'systemd-sysinstall*' 'modprobe@*'; do
      find . -maxdepth 1 -name "$pattern" -exec rm -rf {} +
    done
    # aliases of the units just removed (dbus-org.freedesktop.import1.service, ...)
    find . -xtype l -delete

  - |
    # ncurses compiles 2899 terminfo entries (7.5 MB); keep the terminals
    # anyone reaches this system from
    cd %{install-root}/usr/share
    mkdir terminfo.keep
    for name in xterm xterm-256color xterm-color xterm-new screen screen-256color \
                tmux tmux-256color linux vt100 vt102 vt220 ansi dumb rxvt \
                rxvt-unicode rxvt-unicode-256color alacritty foot foot-extra kitty \
                wezterm ghostty Eterm eterm-color putty putty-256color vte vte-256color; do
      letter=$(printf %.1s "$name")
      if [ -f terminfo/$letter/$name ]; then
        mkdir -p terminfo.keep/$letter
        cp -a terminfo/$letter/$name terminfo.keep/$letter/
      fi
    done
    rm -rf terminfo
    mv terminfo.keep terminfo

  - |
    # the UAPI.9 hierarchy: merged /usr, and the directories a running system expects
    cd %{install-root}
    ln -s usr/bin bin
    ln -s usr/bin sbin
    ln -s usr/lib lib
    ln -s bin usr/sbin
    # x86_64 programs ask for their loader as /lib64/ld-linux-x86-64.so.2
    ln -s usr/lib/%{triplet} lib64
    mkdir -p proc sys dev run tmp mnt home root srv var/log var/lib var/tmp var/cache etc/systemd/system
    ln -s ../run var/run
    ln -s ../run/lock var/lock
    # where an installed system mounts its EFI system partition
    mkdir -p efi boot
    # (BuildStream's artifacts keep no file modes but the executable bit, so
    # /tmp's 1777 and the like are set when system/iso.bst packs the image)
    # The kernel unpacks the initramfs and runs /init: systemd itself.  The
    # initramfs is the root file system, so nothing is mounted or switched to.
    ln -s usr/lib/systemd/systemd init
    [ -e usr/bin/init ] || ln -s ../lib/systemd/systemd usr/bin/init

  - |
    # Command names.  uutils first, then BusyBox for what nothing else
    # provides: find/xargs are uutils findutils, ps/top/free procps-ng,
    # killall psmisc, mount/dmesg/kill/more util-linux, netstat net-tools,
    # nslookup BIND, less and vi (neovim) their own packages.
    cd %{install-root}%{bindir}
    for name in $(%{in-image} ./coreutils --list); do
      [ -e "$name" ] || ln -s coreutils "$name"
    done
    for name in grep egrep fgrep sed awk gzip gunzip zcat tar wget ip ping ping6 \
                traceroute which strings lsof; do
      [ -e "$name" ] || ln -s busybox "$name"
    done
    ln -s nvim vi
    ln -s nvim vim
    echo "$(find . -lname coreutils | wc -l) commands from uutils, $(find . -lname busybox | wc -l) from BusyBox"

  - |
    # Units.  Upstream's .wants links name units this system no longer has,
    # so the static wiring starts from scratch.
    cd %{install-root}/usr/lib/systemd/system
    find . -maxdepth 1 -type d -name '*.wants' -exec rm -rf {} +
    wants() { mkdir -p "$1.wants" && ln -s "../$2" "$1.wants/$2"; }
    wants sysinit.target systemd-journald.service
    wants sysinit.target systemd-journal-flush.service
    wants sysinit.target systemd-tmpfiles-setup.service
    wants sysinit.target systemd-sysctl.service
    wants sysinit.target systemd-udevd.service
    wants sysinit.target systemd-udev-trigger.service
    wants sockets.target systemd-journald.socket
    wants sockets.target systemd-journald-dev-log.socket
    wants sockets.target systemd-udevd-control.socket
    wants sockets.target systemd-udevd-kernel.socket
    # the system bus, for busctl, resolvectl and networkctl; started on first use
    wants sockets.target dbus.socket
    wants local-fs.target tmp.mount
    wants timers.target systemd-tmpfiles-clean.timer
    # an installed system's first boot starts with an empty /etc: users
    # come from /usr/lib/sysusers.d, and update-done records that /etc is
    # up to date with /usr
    wants sysinit.target systemd-sysusers.service
    wants sysinit.target systemd-update-done.service
    # The initrd sets up /usr's dm-verity device from usrhash= (veritysetup
    # units come from a generator, started through veritysetup.target), then
    # creates the root partition on first boot (/usr/lib/repart.d)
    wants sysinit.target veritysetup.target
    wants initrd-root-fs.target systemd-repart.service
    # The boot splash (base/plymouth.bst), wired as Plymouth's own build
    # does: shown from the start of boot (in the initrd, and again after
    # the switch to the real root), until multi-user.target; again while
    # the system shuts down
    wants sysinit.target plymouth-start.service
    wants sysinit.target plymouth-read-write.service
    wants initrd-switch-root.target plymouth-start.service
    wants initrd-switch-root.target plymouth-switch-root.service
    wants multi-user.target systemd-logind.service
    # The other consoles (Ctrl+Alt+F2 to F6): logind starts autovt@ttyN when
    # one is switched to, which here is the console shell of tty1
    # (files/rootfs, console-shell@.service).  A login prompt replaces it
    # once there are users with passwords (docs/desktop.md, phase 4).
    ln -s console-shell@.service autovt@.service
    wants multi-user.target plymouth-quit.service
    wants multi-user.target plymouth-quit-wait.service
    for target in reboot poweroff halt kexec; do
      wants $target.target plymouth-$target.service
      wants $target.target plymouth-switch-root-initramfs.service
    done
    ln -sf multi-user.target default.target

  - |
    # The services with an [Install] section, enabled the way an admin
    # would (including the varlink sockets the daemons come with) -- and
    # then moved from /etc to /usr: an installed system's /etc starts
    # empty, and what is enabled belongs to the image, updated with it.
    %{in-image} %{install-root}%{bindir}/systemctl --root=%{install-root} enable \
      systemd-networkd.service systemd-resolved.service systemd-timesyncd.service \
      iwd.service console-shell@tty1.service console-shell@ttyS0.service \
      systemd-sysext.service systemd-boot-check-no-failures.service
    cd %{install-root}/etc/systemd/system
    for entry in *; do
      if [ -d "$entry" ] && [ ! -L "$entry" ]; then
        mkdir -p %{install-root}/usr/lib/systemd/system/$entry
        mv "$entry"/* %{install-root}/usr/lib/systemd/system/$entry/
        rmdir "$entry"
      else
        mv "$entry" %{install-root}/usr/lib/systemd/system/
      fi
    done

  - |
    # the users the daemons run as (messagebus, systemd-network, ...), from
    # /usr/lib/sysusers.d, so /etc/passwd is complete before the first boot
    %{in-image} %{install-root}%{bindir}/systemd-sysusers --root=%{install-root}
    cut -d: -f1 %{install-root}/etc/passwd | tr '\n' ' '
    # sysusers writes the shadow files with mode 0000, which BuildStream
    # (outside the sandbox, without root's privileges) cannot read to store
    chmod 0600 %{install-root}/etc/shadow %{install-root}/etc/gshadow

  - |
    # /etc's factory copy.  An installed system boots with an empty /etc
    # (its root partition is new), and systemd-tmpfiles fills it from
    # /usr/share/factory/etc: the configuration admins may edit is copied
    # (C: only when missing, so local edits survive updates); the CA bundle
    # is linked (L), so updates of /usr bring new certificates.  Users and
    # the machine ID are made at boot, not copied.  The live ISO keeps /etc
    # as it is.
    cd %{install-root}
    mkdir -p usr/share/factory
    cp -a etc usr/share/factory/
    cd usr/share/factory/etc
    rm -f passwd passwd- group group- shadow shadow- gshadow gshadow- machine-id
    rm -rf systemd/system
    find . ! -type d | sort | sed 's|^\./||' | while read -r f; do
      case $f in
        ssl/*) echo "L+ /etc/$f - - - - /usr/share/factory/etc/$f" ;;
        *)
          if [ -L "$f" ]; then
            echo "L /etc/$f - - - - $(readlink "$f")"
          else
            echo "C /etc/$f"
          fi ;;
      esac
    done > %{install-root}/usr/lib/tmpfiles.d/bunix-etc.conf
    cat %{install-root}/usr/lib/tmpfiles.d/bunix-etc.conf

  - |
    cd %{install-root}
    find usr -type f | while read -r f; do
      case $(file -b "$f") in
        ELF*) strip --strip-unneeded "$f" ;;
      esac
    done
