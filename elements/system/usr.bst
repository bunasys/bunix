kind: manual
description: |
  The installed system's /usr for one release, as the three partitions of a
  /usr slot (docs/updates.md, step 2):

    bunix_<release>.usr-x86-64.<uuid>.raw             erofs, LZ4HC
    bunix_<release>.usr-x86-64-verity.<uuid>.raw      dm-verity hash tree
    bunix_<release>.usr-x86-64-verity-sig.<uuid>.raw  root hash, signed

  systemd-repart derives the data and hash partitions' UUIDs from the root
  hash; the UKI's usrhash= (usrhash, for system/uki.bst) finds them by it.
  These files are what sysupdate writes into the inactive slot, and what
  system/disk.bst puts into the first one.

(@):
- include/system.yml
- include/release.yml

build-depends:
- bootstrap/build-env.bst
- base/systemd.bst
- base/erofs-utils.bst
- filename: system/rootfs.bst
  config:
    location: /rootfs

sources:
- kind: local
  path: keys/verity.key
  directory: keys
- kind: local
  path: keys/verity.crt
  directory: keys

config:
  build-commands:
  - |
    # The partitions' labels carry the release: sysupdate reads the
    # installed versions from them.  SplitName puts each partition's UUID in
    # its file name, where sysupdate takes it from (@u).  LZ4HC: /usr is
    # read on every boot and program start, and LZ4 decompresses several
    # times faster than LZMA.  No validatefs: the build sandbox cannot store
    # its extended attribute.  CopyFiles=/usr/:/ -- /usr's contents at the
    # partition's top level, which is mounted on /usr.
    mkdir -p usr.d
    printf '%s\n' '[Partition]' 'Type=usr' 'Format=erofs' 'Compression=lz4hc' \
      'CopyFiles=/usr/:/' 'Verity=data' 'VerityMatchKey=usr' 'Minimize=best' \
      'AddValidateFS=no' 'Label=bunix_%{release-version}' 'SplitName=%t.%U' \
      > usr.d/10-usr.conf
    printf '%s\n' '[Partition]' 'Type=usr-verity' 'Verity=hash' 'VerityMatchKey=usr' \
      'Minimize=best' 'Label=bunix_%{release-version}_verity' 'SplitName=%t.%U' \
      > usr.d/20-usr-verity.conf
    printf '%s\n' '[Partition]' 'Type=usr-verity-sig' 'Verity=signature' \
      'VerityMatchKey=usr' 'Label=bunix_%{release-version}_verity_sig' 'SplitName=%t.%U' \
      > usr.d/30-usr-verity-sig.conf

  - |
    # as sysext/gcc.bst: no loop devices, a writable TMPDIR, a private key
    # copy.  The seed, from which repart derives the UUIDs not taken from
    # the root hash (the signature partition's), differs per release: two
    # releases' partitions sit on the same disk.
    mkdir -p tmp out
    export TMPDIR=$PWD/tmp
    install -m 0600 keys/verity.key tmp/verity.key
    # The system's setuid programs, set here on a copy: BuildStream's
    # artifacts keep no setuid bits, so system/rootfs.bst cannot.  passwd:
    # users change their own password, in /etc/shadow, which only root may
    # write (PAM asks for the old one first).
    setuid_programs="passwd"
    mkdir image
    cp -a /rootfs/usr image/
    for program in $setuid_programs; do
      chmod 4755 image/usr/bin/$program
    done
    find image/usr -perm -4000 -type f
    # The modules' fingerprint, which system/uki.bst checks against the
    # kernel it boots: each kernel build signs its modules with a new key
    (cd image/usr/lib/modules && find . -name '*.ko*' -type f | sort | xargs sha256sum) \
      | sha256sum | cut -c1-64 > modules.sha256
    /usr/bin/systemd-repart --empty=create --size=auto --dry-run=no --offline=yes \
      --definitions=usr.d --copy-source=image --split=yes \
      --private-key=tmp/verity.key --certificate=keys/verity.crt \
      --seed=$(printf 'bunix usr %s' %{release-version} | sha256sum | head -c 32) --json=short \
      out/bunix_%{release-version}.raw > repart.json
    rm out/bunix_%{release-version}.raw
    # The signature partition's image is its JSON, unpadded; partitions are
    # written in whole sectors, and the format allows zeros after the JSON.
    truncate -s 4K out/*.usr-x86-64-verity-sig.*.raw
    ls -l out
    python3 -c 'import json,sys; print(json.load(open("repart.json"))[0]["roothash"])' > usrhash
    echo "usrhash=$(cat usrhash)"

  install-commands:
  - |
    mkdir -p %{install-root}
    cp out/*.raw usrhash modules.sha256 %{install-root}/
