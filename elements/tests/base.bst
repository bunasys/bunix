kind: manual
description: |
  Runs every program of the base system once (its --version, mostly), in a
  sandbox with the base packages staged over the build environment -- which
  catches missing libraries and broken installs.

build-depends:
- bootstrap/build-env.bst
- base.bst

config:
  build-commands:
  - |
    for cmd in \
      "bash --version" "fish --version" "busybox --help" \
      "coreutils --list" "find --version" "xargs --version" "rg --version" \
      "nvim --version" "less --version" "htop --version" \
      "ps --version" "free --version" "pstree --version" "killall --version" \
      "lsblk --version" "mount --version" "fdisk --version" \
      "ifconfig --version" "netstat --version" \
      "dig -v" "delv -v" "nsupdate -V" \
      "curl --version" "openssl version" \
      "systemctl --version" "networkctl --version" "resolvectl --version" \
      "dbus-daemon --version" "iwctl --help"
    do
      echo "== $cmd"
      # some print their version and exit non-zero; what counts is that the
      # program exists and its libraries load
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
  - curl --version | grep -q OpenSSL
  - test -s /etc/ssl/certs/ca-certificates.crt
  - test -s /usr/lib/firmware/regulatory.db
  - test -x /usr/lib/systemd/systemd
