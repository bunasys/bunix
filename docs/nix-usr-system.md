# The system out of Nix: /usr, and no store

Status: 2026-11-21.  All six steps of the order of work are done: a
system with no `/nix` boots, and the store-layout system is gone.  Since
then: a network and SSH in the image; clang and Rust as packages;
one kernel, Aurora Silicon's, built with them; Wi-Fi (iwd, with the
system bus it needs); Aurora's boot loader for Apple Silicon Macs; and
systemd as the init system, in place of a script.
On 2026-11-19 it booted a real Mac, a 13-inch MacBook Pro M1, from
memory, and was logged into over Wi-Fi.  A machine with a partition
named bunix-root keeps `/var`, `/home` and `/root` on it; the system
itself is still booted into memory.  In a virtual machine it also boots
from a disk, as a machine with EFI starts one: systemd-boot, a unified
kernel image, `/usr` read-only on a partition of its own and checked
against its hash, a second slot for an update, and a root partition
made at the first boot.  On x86_64 every package builds, and the system
has started in an emulated PC, from memory and from such a disk.  The
tests of installing and updating run for both: aarch64's machine on the
Mac, x86_64's on an x86_64 builder, in QEMU with KVM ("QEMU, for a
machine with EFI").

`docs/nix-bootstrap.md` ends with an open question: how bunix's packages
and its `/usr` image come out of the store.  This is the answer.

## The decision

- **Nix builds; it is not in what is built.**  A bunix system has no
  `/nix`.  Its programs are in `/usr`, find their loader and libraries at
  the usual paths, and are laid out as UAPI.9 says, as today.
- **The store is the builder's.**  It holds sources, the bootstrap, and
  every package's result, each result being a `/usr` tree.

The first system that booted was the other thing: programs whose loader
and libraries are store paths.  It proved the toolchain, the kernel and
the boot; its layout is not kept, and `tools/boot-vm.sh` now boots a
system made as below.

## Two kinds of package

| | Bootstrap package | System package |
|---|---|---|
| Is | stage 1 and stage 2 | everything in a bunix image, and the tools that build it |
| Made by | `mkPackage` (`nix/package.nix`) | `mkSystemPackage` (`nix/system-package.nix`) |
| Prefix | its own store path | `/usr` |
| Built in | Nix's sandbox | a staged root, inside Nix's sandbox |
| Finds its libraries by | paths recorded in it | the loader's default: `/usr/lib/<triplet>` |
| Runs | anywhere the store is | only where its `/usr` is: an image, or a build that staged it |
| Result | the store path | `$out/usr/...`, `$out/etc/...`, and the file `$out/depends` |
| What it needs to run is known by | Nix finding store paths in it | its `depends`, written down |

## The chain

```
seed ─ stage 1 (store: glibc, binutils, gcc)
     ─ stage 2 (store: bash, make, tar, ...)
     ─ toolchain (/usr: glibc, binutils, gcc)   built by stage 1's gcc, stage 2's tools
     ─ tools (/usr: bash, coreutils, make, ...) built by the toolchain, stage 2's tools
     ─ every other package (/usr)               built by the toolchain and the tools
```

glibc, binutils, gcc and about fifteen tools are built twice: once to
build with, once to ship.  `elements/bootstrap/` does the same today.

A group of packages built before the system has tools of its own says so
once, where the group is defined (`bootstrapTools`): stage 1's and stage
2's programs are then on PATH after `/usr/bin`.  The toolchain and the
tools have them; the packages after do not, and their authors never
meet the idea.  Those are built with `buildEnvironment`: the system's
compiler and tools, as BuildStream's elements are with
`bootstrap/build-env.bst`.

The compiler of those packages is gcc.  The kernel is the first thing
built with clang (below); the direction is clang for everything but
glibc, a group of packages at a time.

The tools are GNU's, and an image ships the same ones: GNU coreutils in
place of uutils', and no BusyBox.  What BusyBox supplied (grep, sed, awk,
tar, gzip, wget, ip, traceroute, which, strings, lsof) comes from GNU's
packages, already among the tools, and from iproute2, curl and a few
small packages, to be ported.

There was a stage 3: a complete toolchain in the store's layout, with
packages built by it.  Nothing of the system was built with it, and it
is removed.

## How a system package is built

A build needs its dependencies at `/usr`, and each is somewhere else: a
store path of its own.  So a build starts by **staging** (`nix/stage.sh`),
as BuildStream does:

1. it enters a user namespace of its own, in which it may mount;
2. it lays the `usr/` of every dependency over the others, as one
   read-only `/usr`, and copies their `etc/` into one `/etc`;
3. it makes a root with that `/usr`, the store read-only at `/nix` (for the
   source and the script), its result writable, and `/tmp`, `/dev`,
   `/proc`;
4. it runs the package's script there: `./configure --prefix=/usr`,
   `make`, `make DESTDIR=$out install`.

Inside, a program is where it expects everything to be.  A configure
script that records `/usr/bin/sed` has recorded the right thing; a script
that starts with `#!/bin/bash` runs.  The fixes that store-layout
packages needed one by one (bash, Python, perl, util-linux) are not
needed.

- **Two packages, one file.**  If two staged packages have the same path
  under `/usr`, the build fails and names it.  (Left to the overlay, the
  winner would be whichever package's store hash sorts first.)
- **The build is root, and nobody.**  Root inside its namespace, which is
  what lets it mount; no user at all outside.  A recipe that insists on
  not being run as root is told otherwise, as the `.bst` elements for
  coreutils and tar already do.
- **Owners, set-user-id and capabilities are not a package's.**  A build
  cannot give a file to another user or make it set-user-id, and the
  store would not keep either.  They are applied when an image is put
  together, as `elements/base/util-linux.bst` notes today: set-user-id
  from the image's own list (`set_user_id`, `images/system.nix`).
- **An account is a package's to ask for, and the image's to make.**  A
  package that needs one installs a line in `/usr/lib/sysusers.d/`,
  systemd's format, with the id written out:
  `u sshd 74 "sshd privilege separation" /usr/share/empty.sshd`.  What
  puts an image together makes the accounts of the packages in it, with
  systemd-sysusers (`images/image.sh`).

## One build, two packages

gcc's run-time libraries (`libstdc++.so.6`, `libgcc_s.so.1`, the
sanitizers') are what a C++ program needs to run; the compiler is not.
gcc is built once, as `gccWhole`, and shipped as two packages, each made
by copying its part of that result: `gccLibraries` (11 MB) and `gcc`,
which depends on it.  A package with a C++ program depends on
`gccLibraries`, and an image with it has no compiler
(`nix/tests/usr-cxx-package`).

A package made from another's result has a `version` where others have a
`source`.  BuildStream does this with a `filter` element.

## A program built elsewhere

Rust is published as programs, not only as source.  Its packages say
`builtElsewhere = true`: the files are shipped as published, not
stripped, and may name their builder's store as text.  They are still
checked for what makes them start here: this system's loader, and
libraries among their `depends`.

They are rustc, cargo, rustfmt, the standard library and its source, as
the Rust project publishes them, each archive pinned.  They are in
`/usr/lib/rust`, where rustc finds its libraries beside itself, with
links in `/usr/bin`.  `elements/bootstrap/rust.bst` builds Rust from
source with such a download as its seed; that is not ported.

Two more, both in the devtools extension only.  Nix: the one program,
linked with all it needs, as the Nix project's own builds publish it;
building it here is Nix and ten libraries this system does not have
yet.  Its source is a build of their build server, named by its number,
which that server may not keep for ever.  And Firecracker, for x86_64,
as on x86: its makers' release.

## QEMU, for a machine with EFI

QEMU (`base.nix`: `qemu`, with pixman, libslirp and libfdt) is built
here, on both architectures, each for machines of its own kind, and is
in no image yet.  It is what a system is tested in as a machine with
EFI starts it: Firecracker has no firmware, so it starts a kernel and
never systemd-boot or a unified kernel image, and nothing in it counts
the tries of an update.  What is not built here is the firmware QEMU
gives its machines (EDK II for EFI, SeaBIOS, the cards' ROMs): the
files QEMU's source carries, built by its project.  Not tracked for new
versions: what looks for them reads `upstreams.yml`, by element, and
QEMU, libslirp and libfdt have none.

On a builder whose own `/usr` is another
system's, `tools/nix-builder/with-usr.sh` runs it with `/usr` made of
its packages, without root:

```
qemu=$(nix-build nix/base.nix -A qemu --no-out-link)
tools/nix-builder/with-usr.sh $qemu -- qemu-system-x86_64 -M q35 -accel kvm -cpu host -m 4G \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/qemu/edk2-x86_64-code.fd \
    -drive if=pflash,format=raw,file=vars.fd \
    -drive file=disk.raw,format=raw,if=virtio \
    -netdev user,id=net,hostfwd=tcp:127.0.0.1:2022-:22 -device virtio-net-pci,netdev=net \
    -nographic -no-reboot
```

(`vars.fd`: a copy of the package's `usr/share/qemu/edk2-i386-vars.fd`,
which the firmware writes its settings to; `disk.raw`: a copy of
`images/disk.nix`'s, with room added after it.)  So started, 0.4.1's
disk came up by systemd-boot and its kernel image, all of the system
running, the clock set by the network, and SSH taking the key handed
over as on aarch64 (`tools/boot-vm.sh`).  aarch64's is built, and has
started nothing: the Mac has a QEMU of its own.

The tests use it.  `tools/test-machine.sh` is where `tools/boot-vm.sh`
and the three tests learn where to build and where the machine runs:
with `BUNIX_ARCHITECTURE=x86_64` the working tree is sent to the x86_64
builder, built there, and started there by this QEMU, while the test
itself stays on the Mac -- the machine's SSH port, and the port the Mac
serves an update's files on, are carried by the ssh that runs QEMU.
What a test shows of x86-64 that it does not of aarch64: EFI firmware
that keeps its variables from one start to the next, as a PC's does.
What it leaves out there: what an Apple Silicon Mac alone has (the boot
loader's files on the ESP, U-Boot, firmware of the machine's own), and
a disk of a system for release (`BUNIX_SIGNATURE`): the builder is sent
what git has of the working tree, and a signature is not of that.

## clang, and the kernel

LLVM, clang and lld are one package, `llvm`, built from source by gcc.
bindgen is built by cargo from its crates, each pinned
(`base/bindgen-crates.json`), with no network.

There is one kernel: Aurora Silicon's, which is Linux with the drivers
and device trees of Apple Silicon Macs.  It is built with clang and
LLVM's linker (`LLVM=1`), with its Rust drivers, on top of the source's
own `asahi.config`; `boot/linux/aarch64.config` has what bunix adds, each
line with its reason, and the build fails if one of them is not in the
final configuration.  The same image boots a virtual machine.  On
x86_64 it is the same source with that architecture's default
configuration and `boot/linux/x86_64.config` ("What the image that
boots lacks" says what it has).

Aura, Aurora's boot loader (from m1n1), is a package too (`boot.nix`):
built by clang and LLVM's linker, its Rust part by cargo with no network,
from the crates of `boot/aura-crates.json` and one from a repository at a
pinned commit, against Rust's libraries for a machine with no operating
system (`rust-std-aarch64-none`).  It installs its images in
`/usr/lib/aura`: Stage 1 with no configuration, which waits for a
computer on USB, and beside it aura's tools for that computer, and a
piece they would otherwise need an assembler for; Stage 2, the same
source built to be loaded from a disk; and aura's three tools for
starting from a disk ("A Mac starts from its disk", below).

U-Boot is Aurora's too (`boot.nix`, `boot/u-boot.sh`), at the commit
Aurora's own systems pin, built by gcc with the source's configuration
for Apple's machines, less one tool for the computer it is built on,
which nothing here uses.  A second build of it, for
QEMU's virtual machine, is what the tests start a disk with.

bindgen is 0.73.2 with the two patches of Aurora's source
(`tools/aurora-bindgen/`, here in `files/bindgen/`), for C layouts the
released one gets wrong.  The kernel's build also checks the layout of
everything bindgen generated.

## On a Mac

`tools/boot-mac.sh t8103-j293` boots bunix on an Apple Silicon Mac from
another Mac, over a USB-C cable, into memory: the kernel, the device tree
of that model, and the image.  The system is not on the Mac's disk;
what it keeps from boot to boot may be ("A disk", below).

The Mac has to be waiting for it, which takes one change to its disk, by
its owner: a small container beside macOS that holds a boot loader in
proxy mode.  The Asahi Linux installer makes one and nothing else, in
expert mode (`curl https://alx.sh | EXPERT=1 sh`, "Tethered boot (m1n1,
for development)"): it shrinks macOS by 2.5 GB and finishes in the Mac's
recovery mode.  Holding the power button at start-up then chooses
between macOS and waiting on USB.  Deleting the container and growing
macOS back undoes it.

What waits is Asahi's m1n1.  `boot-mac.sh` has it start aura, the one
built here, and aura starts the kernel.

Firmware is the machine's (below): for Wi-Fi, the files are in the Mac's
own macOS (`/usr/share/firmware/wifi`), and `asahi_firmware.wifi`,
Asahi's tool that Aurora's installer carries, makes of them an archive
with `/vendorfw` in it.
`BUNIX_FIRMWARE` names that archive; it is put before the image, and the
kernel is told where to look.  It is not in this repository, nor in any
package.

Tried on the 13-inch MacBook Pro M1 (J293): the screen and the laptop's
keyboard are the console, the internal disk's bunix-root is checked and
mounted, and Wi-Fi joins a WPA3 network, by itself from the second time
on.  A network to another computer over the
USB cable does not work: in this kernel a Mac's port, as a USB device,
is seen by the other computer and never configured, as Aurora's own
notes say of it.  `/usr/lib/bunix/usb-link` sets such a link up
(in `images/system/`), for the day it does.

### A disk

A machine with a partition for it keeps `/var`, `/home` and `/root`
there: sshd's keys (`/var/lib/sshd`), so the machine is the same machine
to SSH at every boot, the networks iwd has joined, the journal, and on
an installed Mac its own firmware (`/var/lib/vendorfw`, below).  On a
Mac, so far, `/usr` and `/etc` are still the image's, in memory.

The image mounts nothing: it is for any machine.  Which partition is a
machine's is said when it is booted: `tools/boot-mac.sh` takes its name
(`BUNIX_ROOT=bunix-root`) and gives systemd the mounts on the kernel's
command line (`systemd.mount-extra=`), and with them an id for the
machine, made of the Mac's serial number: `/etc` is new at every boot,
and the journal on the disk is the machine's by that id.  By name and not by type, as
systemd would find it by itself: another Linux on the same disk has a
root partition of that type too.

Nothing here makes a Mac's partitions (`images/disk.sh` makes a virtual
machine's); on the first Mac they were made by
hand, from bunix itself, in the space its owner had taken from macOS
beside the 2.5 GB boot container:

```
sfdisk --append /dev/nvme0n1     two lines: 1 GiB, type EFI system,
                                 name bunix-esp; 28 GiB, type root
                                 (64-bit Arm), name bunix-root
mkfs.vfat -F 32 -n BUNIX-ESP /dev/nvme0n1p5
mkfs.ext4 -L bunix-root /dev/nvme0n1p6
```

and 5.5 GB were left free.  Deleting the two entries undoes it.

### A Mac starts from its disk

The 13-inch MacBook Pro M1 starts this way (2026-11-21), by itself and
with its Wi-Fi.  The chain:

```
the Mac's own firmware
  -> aura, Stage 1       the Mac is told of it once, in its recovery
                         system.  It has the id of one ESP in it.
  -> aurora/stage2.bin   on that ESP: aura again (Stage 2), the device
                         tree of every Mac the kernel knows, U-Boot
  -> systemd-boot        on that ESP, started by U-Boot as by any EFI
                         firmware; from here on a Mac is a machine like
                         another ("Where this is going", below)
```

`boot.nix`'s `mac-stage2` makes the file of the middle step, with aura's
own tool, and it is in the system (`/usr/lib/mac-stage2/stage2.bin`):
`bunix-install` copies it to the ESP of an Apple Silicon Mac's own disk,
and refuses an ESP that has another system's there.  The device trees
are the kernel's of the same build, and U-Boot hands the one aura picked
on to the kernel.

Stage 1 is made for one ESP, on the computer bunix is built on:
`tools/mac-stage1.sh <id of the ESP>`, the id being what the installer
prints at its end.  It runs aura's tool that writes the id into the
image, and says what to do with the result in the Mac's recovery system,
where aura's own script (`enroll-stage1.sh`) checks and then tells the
Mac.  With `put root@<the Mac's address>`, while the Mac still runs the
system the installer ran in, it also puts the files on the ESP
(`bunix-enroll/`), where the recovery system reads them: no USB stick
is carried over.  Two short scripts beside them have the checksums
written in (`enroll.sh`, and `way-back.sh` for the plain Stage 1), as
the recovery system cannot paste.  The id is not written into Stage 1
by the installer itself: aura's tool for it is Python, which the system
does not have, and a second one would be ours to keep in step.

The Mac is told in place of what its boot container starts now ("On a
Mac"): from then on it no longer waits on USB, and the plain Stage 1,
which does, is kept beside the new one as the way back.

`tools/mac-stage1.sh <id> try` instead loads that Stage 1 into the
memory of a Mac that waits on USB, as `boot-mac.sh` does with the plain
one: the whole chain runs from the disk once, and nothing on the Mac has
changed if it does not.

Open:

- **Stage 2 is not updated with the system.**  An update brings a kernel
  image; the device trees on the ESP stay the installed version's.
  Aurora's systems replace the file on a trial start and keep the old
  one until the new has worked; nothing here does yet.
- **U-Boot keeps EFI's variables in a file on the ESP** (`ubootefi.var`),
  written when one changes.  On a Mac that is the ESP aura names,
  bunix's; in the virtual machine it is the first ESP of the disk,
  whoever's it is.
- **aura is a version behind** the one Aurora's NixOS pins (1.0.0b14.1);
  the kernel and U-Boot are the same commits.
- **The picture at start-up** is Aurora's; aura takes another when built
  with one.

### Where this is going

What bunix is on x86 (`docs/updates.md`,
`files/rootfs/usr/lib/repart.d`, `sysupdate.d`): `/usr` read-only on a
partition of its own, in two slots of 2 GB, one running and one to go
back to, written by systemd-sysupdate; extensions as sysext; and a
writable root partition with `/etc`, `/var` and `/home`.

What is there of it (`tools/boot-vm.sh disk`, a virtual machine):

- **`/usr` as the images of a partition.**  `images/system.nix` makes, of
  the tree it packs for memory, `/usr` as a read-only file system (erofs)
  and the hashes of its blocks (dm-verity), with systemd-repart, and the
  one hash that stands for both.
- **What starts it.**  A machine with EFI: a virtual machine's so far;
  a Mac's is U-Boot's ("A Mac starts from its disk").  systemd-boot, on the partition
  the machine boots from, starts the newest unified kernel image there
  (`images/uki.nix`): the kernel, `images/initrd.nix`, and a command line
  with the hash of the one `/usr` that kernel runs (`usrhash=`), as one
  EFI program.  `images/initrd.nix` is systemd in memory, which sets up
  `/usr` from the partitions that hash names, makes the root partition
  if the disk has none, mounts it, by its name, and hands over to the
  systemd in that `/usr`.  The kernel image has no device tree: a
  machine that needs one gets it from what started its EFI.
- **An `/etc` that starts empty.**  What the image has for `/etc` is also
  in `/usr` (`/usr/share/factory/etc`), and systemd-tmpfiles puts in
  `/etc` what is missing, file by file; the certificates as links into
  `/usr`, so that an update brings new ones.  The units that run are
  enabled inside `/usr`, and updated with it.  The accounts and the
  machine's id are made at the first boot and kept.  What is read before
  `/etc` is filled has to be right without it: so the machine has a name
  built into systemd.
- **udev told of the device.**  `dm-udev-rules`, the device mapper's own
  rules: without them systemd waits for ever for `/dev/mapper/usr`.
- **A disk.**  `images/disk.nix`, after x86's: the partition a machine
  boots from, with systemd-boot and the kernel image; `/usr` slot A, with
  the system's image, its hashes and the signature; slot B, empty, for
  the next update; and no root partition, which systemd-repart makes at
  the first boot in the space that is left
  (`system/usr/lib/repart.d`).  For a disk that is bunix's alone:
  systemd-repart knows a root partition by its type, and on a disk
  shared with another system it would take that system's for this one,
  and grow whichever it takes into the space beside it.  There, as on
  the first Mac, what installs bunix has to make every partition itself,
  the slots first: `bunix-install` does (below).
- **Installing.**  `bunix-install <directory>`, on a system started in
  memory, puts the version whose files the directory has
  (`images/update.nix`) on a disk: into free space, in place of a
  partition or of an earlier Linux, or over a whole disk.  It is x86's
  (`files/rootfs/usr/bin/bunix-install`, `docs/install.md`) with what its
  first lines list changed: the kernel images on the ESP, no firmware
  boot entry, nothing of Apple's deleted and never a Mac's whole disk,
  what an Apple Silicon Mac's boot loader loads from the ESP ("A Mac
  starts from its disk"), and the person's choice of bash or fish.  It asks for the machine's
  name and one account, an administrator; root's is locked.  The root
  partition it makes ends where the next partition begins: free space
  right after the chosen place becomes bunix's, since systemd-repart
  grows the root partition into such space at every boot (seen in the
  test: a megabyte at a disk's end).
  `tools/install-test.sh` installs twice in a virtual machine, on an
  empty disk and on one laid out as a Mac's with 4096-byte sectors, and
  starts both.
- **The hash signed.**  A third partition beside `/usr` and its hashes:
  the root hash, signed.  The kernel has bunix's certificate built in
  (`keys/verity.crt`) and checks such signatures against it; the system
  has the certificates it takes in `/usr/lib/verity.d`.  `/usr` itself is
  held by the hash on the kernel's command line; the signature is for
  what no command line names, extensions above all, and is what sysupdate
  puts beside a new `/usr`.

- **Updates, and the way back.**  `images/update.nix` is one version as
  the files a machine downloads: the three partitions of a `/usr` slot,
  each named by the id its partition is to have, and the kernel image.
  A disk is made of the same files.  The system says where to get them
  (`system/usr/lib/sysupdate.d`, after x86's, with `%a` for the
  architecture, in the kernel image's name too, which x86's published
  one does not have yet): sysupdate writes a
  new `/usr` into the slot that is not running, and its kernel image last,
  with three tries in its name.  systemd-boot counts them down;
  `systemd-boot-check-no-failures` says what a good boot is (no unit
  failed), and `systemd-bless-boot` then takes the tries off the name.  A
  version that never gets there in three starts is gone back from; one
  that starts with a unit failed runs, and uses up a try at each start.
  The list of a version's files is signed (OpenPGP), and checked before
  anything is written: systemd runs `gpg` for that, which here is x86's
  small script around Sequoia's `sqv` (`base.sqv`, with Botan linked in).
  `tools/update-test.sh` goes through all of it in a virtual machine:
  the list bunix 0.4.0 was published with, taken by the certificate the
  system comes with; lists that are unsigned, signed by a stranger,
  changed after signing, or past their day, each refused; a version
  whose kernel image is there for the other architecture only, not
  taken; an update, the restart into it, an update that cannot start,
  its three tries, and the return.
- **A release.**  `tools/publish.sh` puts one together, of both
  architectures, in one directory (`docs/release.md`).  Each builder is
  sent the last commit: aarch64's on this Mac, x86_64's over SSH.  Each
  builds its system and its extension up to their hashes; the hashes
  are signed on the Mac ("Who signs"), and the builds finished with the
  signatures.  Then the list of all the files, with the day it is good
  until, is signed with the release key (`tools/sign-list.sh`: the key
  from the password manager into Sequoia's `sq`, through a pipe).
  `tools/release-test.sh` serves the directory to a virtual machine of
  the version before, which is told where to look, and to ask for the
  devtools extension: it takes the release, restarts into it and marks
  it good.  Tried with test systems' files and a list signed with a key
  made for the trial, which the machine was told to take, for both
  architectures' builds, and then with 0.4.1's own, which is published
  (`docs/release.md`), for a machine of either architecture; x86-64's
  files of 0.4.1 were started only after they were uploaded.

Not there yet: a machine whose clock is behind (one with no clock of its own starts at
the first of November 2026, before any signature was made, and takes no
update until the network has told it the time: what runs updates has to
wait for that); a version that does not
start restarted without a person (it waits in the initrd's emergency
shell); anything that runs an update by itself, which has to clear away
a download that was cut off first (`systemd-sysupdate vacuum`: sysupdate
refuses to go on over one) and should not update from a version not yet
marked good; a test system's update files told from a release's by
more than the name of the build's result; the kernel image signed (what would check it is Secure Boot,
which a Mac's EFI does not have, so whoever can write the boot
partition chooses what runs); a medium the installer finds
its files on by itself; and any of it
on a Mac.  U-Boot, as built for a virtual machine, has done both things
that were in doubt: its EFI lets systemd-boot rename a file, as counting
boots needs (`BUNIX_EFI=u-boot tools/update-test.sh`: the update,
the three tries of a bad one, and the way back), and it starts a disk
of 4096-byte sectors laid out as a Mac's (`tools/install-test.sh`).  As
built for a Mac it starts the 13-inch MacBook Pro M1 ("A Mac starts
from its disk").

### Extensions

What a machine does not need to run, and its person may ask for, is an
extension: an image that systemd-sysext lays over `/usr`
(`docs/updates.md`).  `images/extension.nix` makes one of a list of
packages: their files and those of all they need to run, without what
`/usr` has already, and, so far, without what is for building (x86's
gcc extension is for that, and is not ported).  The image is a
small disk of three partitions, as a `/usr` slot is three: the file
system, the hashes of its blocks, and the root hash, signed by
`tools/sign.sh` as `/usr`'s is.  A system merges only an image that is
signed by a key it takes (`sysext.conf.d/bunix.conf`), and only an
extension of its own version.  (A directory that root puts where
extensions are looked for is merged as it is.)

`images/devtools.nix` is the first: git, gdb, strace, file, libarchive's
bsdtar and unzip, as on x86; Node.js 24 with npm and corepack; Nix,
which bunix is built by, with its daemon; and on x86_64 Firecracker.
The image for arm64 is about 134 MiB, more than half of it Node.

`/usr` is read-only, so what npm installs for everyone
(`npm install --global`) goes to `/usr/local`: npm is told so in the
extension.  corepack has no such setting, and is told each time:
`corepack enable --install-directory /usr/local/bin`.  Node's headers
are not in the extension, as no package's are: for an add-on written
in C++, npm downloads them.

`images/llvm.nix` is the second, for building software on a machine:
clang and LLVM's linker and tools, make, patch, pkgconf, cmake, meson
and ninja, and binutils.  Of gcc it has what clang takes from it on
Linux (the start files, libgcc, the C++ library's headers:
`toolchain.nix`, `clangSetup`), and not gcc; `cc` and `c++` are clang,
which links with LLVM's linker.  Without LLVM's own runtime libraries:
no sanitizers, coverage or OpenMP.  The headers of the C library
and of the system's own libraries are the system's already, an image
being of whole packages.  About 300 MiB for arm64.  What is built is
installed in `/usr/local`, a link in the image to `/var/usrlocal` on
the root partition, as on x86.  `/usr/local/bin` is on a login's `PATH`,
before `/usr/bin` (pam_env, `usr/lib/bunix/login-environment`; tried
over SSH, not at the console), and not on a service's.  Its libraries
are not where the loader and pkgconf look: a build that is to find them
says so (`bunix install` does, below).

`bunix ext enable <name>` turns one on (`src/bunix`): it enables the
feature, has sysupdate download the running version's image, and
restarts systemd-sysext.  By hand, which is what a 0.4.1 has:

```
mkdir -p /etc/sysupdate.d/devtools.feature.d
printf '[Feature]\nEnabled=true\n' > /etc/sysupdate.d/devtools.feature.d/enable.conf
/usr/lib/systemd/systemd-sysupdate update && systemctl restart systemd-sysext
```

### Packages built on the machine

`bunix install <name>` builds a package where it is to run, and installs
it in `/usr/local` (`src/bunix/src/install.rs`).  `nix/packages.nix` has
the recipes, as data: a source of `sources.json`, the script that builds
it, and what it needs.  Each recipe is a system package as well, built
by Nix for `/usr` and by gcc: one that does not build is not shipped.
The llvm extension brings them to a machine
(`/usr/share/bunix/packages`), with `/usr/lib/bunix/build-package`,
which runs a recipe's script as a build of bunix does, but with clang
and for `/usr/local`.  On the machine the source is downloaded and
checked against the recipe's hash, built in a directory that is root's
alone (the log in `/var/log/bunix`), and copied into place; a list of
its files is kept (`/var/lib/bunix/installed`), so that a later version
leaves none of an earlier behind, and so that no file is replaced that
another package or a person put there.  less and htop are the first two.

What that does not do yet:

- A recipe's script has to take where it installs from
  `$configure_for_usr`, which the autotools one does; the meson and
  cmake scripts name `/usr`, and changing them rebuilds every package.
- A recipe's variables are strings: one that needs a patch cannot be
  handed to a machine.
- The build runs as root, on the machine itself and not in a sandbox,
  and what it makes is not stripped or checked as a system package is.
- Nothing removes a package.
- What was installed is linked against the system's libraries as they
  were: after an update of the system it is not built again.
- Every package is built from source on every machine: a cache of what
  was built, for faster installs, is to come.

A machine that has asked takes a version only together with that
version's extension, as one update, and has it merged at every boot.
Two versions' extensions are kept, as two of `/usr` are, in
`/var/lib/bunix/extensions`; what is merged is the running version's
(`/usr/lib/bunix/extensions-of-this-version`).  x86 keeps them where
systemd-sysext looks, which takes the newest: after an update, and
after going back from one, that is not the running version's, and none
is merged.
Its file is published with the architecture in its name
(`devtools_<version>.arm64.raw`), where x86's had none.

Nix's store is `/nix`, on the root file system, made when its socket is
first started; its settings are copied to `/etc/nix/nix.conf` where the
machine has none: every build in a sandbox, as a user made up for it,
nothing taken from others' stores, and only for the machine's
administrators (wheel).  The socket is started with the merge, at boot
and by hand alike: systemd is asked for its sockets again once the
extension is there (`systemd-sysext.service.d/bunix.conf`).

`tools/update-test.sh` asks for the extension before its update, runs
its programs after the restart, and checks that what is in its place is
not merged when it is not signed, or signed as of another hash.

Not ported: the gcc, rust, swift and desktop extensions.

### Who signs

A key that is secret is no build's to read: what a build reads is in the
builder's store, for every user of the builder, and stays there.  So a
system is built, then signed, then put together.

- **Built.**  No secret goes in.  The result has `/usr`'s image and the
  root hash (`usr-partition/usrhash`).
- **Signed.**  `tools/sign.sh <root hash>` asks a password manager
  (1Password's `op`) for bunix's key when it signs, hands it to openssl
  through a pipe, and writes the signature: what systemd-repart would
  have written, to the byte.  Only the hash is signed, not the image.
  The signature is not secret, and is the same whenever it is made.
- **Put together.**  The signature is an input like any other
  (`images/update.nix`: `signature`, which `images/disk.nix` passes on).
  It is checked there, against the hash and against bunix's certificate,
  before it is one of a version's files, and so before it goes on a disk.

The steps, as commands, are at the top of `tools/sign.sh`.

A test build would need a signature for every change.  So a disk made
with no signature given is a test system's: its hash is signed in a
build, by the same script, with a key that is in the repository for
everyone to read (`nix/development-key/`), and the system takes that
key's signatures as well as bunix's, and says so of itself
(`VARIANT_ID=development` in `/usr/lib/os-release`).  A system for
release takes bunix's only, and does not take a test build's image as
bunix's.  The kernel has bunix's certificate only, in both.

What is enforced, and what is not: nothing yet refuses a `/usr` that has
no signature.  `/usr` is opened by the hash on the kernel's command
line, and the signature beside it is not asked for at boot; it is there
for what will ask.  An extension's is asked for: one that is not signed
by a key the system takes is not merged ("Extensions").  That the kernel takes a
signature made with bunix's own key, and no other, was tried in a
virtual machine with a system for release (`BUNIX_SIGNATURE=...
tools/boot-vm.sh disk`): given a copy of `/usr` and its signature,
"verified (with signature)"; with one byte of the signature changed,
"Root hash verification failed".  A test system's signature is of the
development key, which only the system, not the kernel, has the
certificate of.

bunix's key is the one x86 signs with.  x86 still reads it from a file
(`keys/verity.key`, never committed), which puts it in BuildStream's
cache; `docs/updates.md` has moving that off the build host as work to
do.  While that file is in a checkout that a builder is given to read
(`tools/nix-builder/lima.yaml` gives it the whole repository), the key
is within a build's reach whatever this side does: it belongs outside
the checkout, once the password manager has it.  The certificate is
also the kernel's built-in one, which is more than a key for images
should be vouching for, as on x86.

What the check of `/usr` does not cover: `/etc` is on the root partition,
unchecked, and whoever can write the disk can change what runs through
it.  And a `/usr` that fails its check, or a disk that is not found,
ends at root's shell on the console, with no password: the initrd has no
login, whatever the system on the disk asks at its own console.

One tree is both systems, in memory and on a disk, so each has a little
that is for the other: the copy of `/etc` in `/usr`, and the image's own
`/etc/fstab`, which mounts nothing.

The first Mac's disk is laid out for it.  bunix-root has the type and
the directories of the root partition, and becomes it by gaining `/etc`.
bunix-esp is empty, and is for a kernel and a boot loader that need no
cable.  The free space is the two slots.

## Dependencies are declared

Nix learns what a bootstrap package needs at run time by finding store
paths in it.  A system package has none in `usr/` or `etc/`, by design.
What it needs is written down, as in a `.bst` element:

- `depends`: needed to run, and so in any image that has the package;
- `buildDepends`: staged for the build only.

The build writes `depends` into the result as the file `$out/depends`:
the store paths of what the package needs to run.  It is the one file of
a system package that names the store.  Nix finds those paths as it does
in any package, and so can answer "this package and all it needs", for
staging and for images; the system never reads the file, and an image
leaves it out.

Checked of every system package when its build ends (`system-package.sh`,
`stage.nix`), each with a test that a package breaking it is refused
(`nix/tests/usr-rejects`):

- no file in it names the store, and no link points into it;
- every script in its `/usr/bin` is run by something the package has or
  declares (`#!/bin/sh` is bash's);
- the only store paths Nix finds in it are its `depends`;
- every shared library a program in it asks for is in the package or in
  its `depends`, not merely in a `buildDepends`;
- libraries are in `/usr/lib/<triplet>`, and there is no `/usr/lib64`,
  `/usr/libexec` or `/usr/sbin`.

Not checked, because nothing shows it at build time: a program the
package runs by name from inside another (`sed` in a script, `sh` through
`system()`) that no `depends` provides.

## The image

The union of the chosen packages' `usr/` and `etc/` trees, with what they
`depends` on, as files: no `/nix`, no `depends` files.  The system
(`nix/images/system.nix`) is one such union, with bunix's configuration
over it, packed by the kernel's `gen_init_cpio` as an initramfs, and its
`/usr` also as the images of a partition.  An extension
(`nix/images/extension.nix`) is the same union without what the system
has.

systemd is its init system.  bunix's configuration is `files/rootfs`'s
where the system on x86 has the same (the network's files, the journal,
the console's unit), and `images/system/` where this one differs yet:
which units run (one preset file, applied when the image is made, the
result kept in `/usr`), sshd's unit with
its keys in `/var`, a console script with bash where x86's has fish,
a journal that is on disk only where there is one,
and an address asked for by the network card's own.  systemd's own tools make the
accounts, enable the preset's units and compile udev's hardware database
on the tree before it is packed.  The same script (`images/image.sh`)
makes `images/initrd.nix` of fewer packages.  It refuses a file that is
in two packages, and two accounts that ask for one id.  The key that may log in over SSH comes
on the kernel's command line as a credential of systemd's, which sshd's
unit takes: it is for that boot, beside root's own keys.  A build that makes an
image names its `contents`, and Nix gives it those packages and all they
need.

No package is yet in two parts for running and for building against, so
an image with glibc has its headers and static libraries too.

## Where things are

```
nix/
  development-key/            the key test builds are signed with, which
                              is not secret
  fetch.nix  sources.json     a pinned download; every source, as data
                              (but crates: base/bindgen-crates.json,
                              base/sqv-crates.json, boot/aura-crates.json)
  architecture.nix            the library directory's name and the loader's path
  release.nix                 the version being built
  bootstrap/                  the store: seed.nix sh.nix package.{nix,sh}
                              stage1.nix stage1/ stage2.nix stage2/
  stage.{nix,sh}              a build with /usr made of system packages
  system-package.{nix,sh}     mkSystemPackage, and what is checked of a result
  autotools.sh  meson.sh  cmake.sh  cargo.sh
                              the recipe of an ordinary package
  toolchain.nix  toolchain/   glibc, binutils, gcc
  tools.nix      tools/       what a build runs
  base.nix       base/        after elements/base/; the porting rule is at its top
  boot.nix       boot/        the kernel and its device trees; the boot
                              loader of Apple Silicon Macs, U-Boot, and
                              the file of both that a Mac's ESP has
  images/                     what is made of packages (below)
  tests/<name>/  run.sh
files/<package>/              patches, and files a package installs as they are
```

What `images/` makes, and of what:

```
system.nix  (image.sh)  ->  initramfs.cpio.gz: the system, for memory
                            usr-partition/: its /usr as a partition's
                            images, with usrhash, version, os-release
                            usr-paths: what /usr has, as a list
initrd.nix  (image.sh)  ->  initramfs.cpio.gz: what starts a system
                            that is on a disk
uki.nix     (uki.sh)    <-  boot.linux, initrd.nix, system.nix's hash
                        ->  bunix_<version>.efi
update.nix  (update.sh) <-  system.nix's usr-partition/, uki.nix, a
                            signature (tools/sign.sh; for a test system,
                            development-signature.sh makes it)
                        ->  one version's files, as they are downloaded
disk.nix    (disk.sh)   <-  update.nix
                        ->  disk.raw
extension.nix (extension-parts.sh, extension.sh)
                        <-  packages, system.nix's usr-paths, a signature
                        ->  <name>_<version>.<architecture>.raw
devtools.nix  llvm.nix  the extensions so far, by extension.nix
system/  initrd/            bunix's own configuration of the first two
```

What a person runs, on a builder:

```
nix-build nix/base.nix -A util-linux     one package
bash nix/tests/run.sh                    every test
BUNIX_ARCHITECTURE=x86_64 tools/<boot-vm.sh, or one of the three tests>
                                         for x86_64, on its builder (tools/test-machine.sh)
tools/boot-vm.sh                         on the Mac: build the image and boot it
tools/boot-vm.sh check                   boot it, and ask systemd if all started
tools/boot-vm.sh disk [check]            the same, installed on a disk, by EFI
BUNIX_CHECK_SCRIPT=tools/vm-checks/accounts.sh tools/boot-vm.sh disk check
                                         and accounts tried on it; run0.sh
                                         and passwd-chsh.sh the same way
tools/update-test.sh                     on a disk: update it, with the devtools extension,
                                         and go back from a bad update
BUNIX_EFI=u-boot tools/update-test.sh
                                         the same, started by U-Boot (aarch64)
tools/install-test.sh                    install it on two disks, and start them
tools/release-test.sh <directory> <version before>
                                         update to a release as tools/publish.sh made it
tools/sign.sh <root hash>                sign a system's hash with bunix's key
tools/nix-builder/with-usr.sh <package>... -- <program>
                                         on a builder: run a program of the system's packages (QEMU)
tools/boot-mac.sh t8103-j293             boot it on another Mac, over USB
tools/mac-stage1.sh <id of the ESP> [try | put root@<address>]
                                         what a Mac is told to start, to start it from its disk
```

## Open questions

- **Owners.**  A file that is another account's than root's has no list
  to be on, and nothing that applies one, as set-user-id has
  (`images/image.sh`); none is needed so far.  And PAM's helper that
  checks a password is not set-user-id, as on x86: it cannot check one
  for a program that is not root's.
- **Account ids.**  Each is a number in its package's script, and two
  packages with the same one are only found out when an image has both.
  systemd's own accounts get the numbers sysusers gives them when the
  image is made, which move when a package with an account joins.  Files on a disk are owned by those numbers now, so
  one that changes between images is no longer harmless.
- **`/etc` and `/var`.**  Which of a package's files outside `/usr` belong
  to its result, and which to the image.  Today a package's `etc/` is
  staged and its `var/` is not; recipes remove the `var/` and `run/` they
  install, and systemd-tmpfiles makes what programs keep state in.  `/etc`
  on a disk is filled from a copy in `/usr`, once: a default that changes
  in a later `/usr` does not reach a file already copied, as on x86.
  sshd's keys are in `/var/lib/sshd` only because `/etc`, in memory, is
  not kept.
- **An extension that is refused fails the boot.**  An image where
  extensions are looked for that is not signed, or is damaged, fails
  the unit that merges them, and a boot with a failed unit is not
  marked good: a new version would be gone back from for it.  Right for
  the extension an update brought; a stray file would do the same.
- **Nix's program is downloaded from its makers' build server**, which
  may not keep that build for ever: to be kept beside bunix's releases.
- **Power lost right after the first start.**  The first start fills
  `/etc` from the copy in `/usr`, and nothing makes sure those files are
  on the disk before going on: for some seconds a machine that loses
  power is left with empty files in `/etc` (seen in
  `tools/install-test.sh`: no message bus at the next start).  x86 fills
  `/etc` the same way.
- **A package in two parts, for running and for building against.**  An
  image with glibc has its headers and static libraries; one with ncurses
  has its .pc files.  gcc is split by hand (above); the rest are not.
- **Scripts in glibc.**  ldd, sotruss, tzselect and xtrace are bash
  scripts, and glibc cannot depend on bash, which depends on glibc.  They
  are left out for now; they belong in a small package of their own.
- **libgcc_s.**  glibc loads it by name when a thread is cancelled or
  exits early, which no check can see, and glibc cannot depend on a
  package built from it.  Every image lists `gccLibraries` in its contents.
- **Locales and time zones.**  glibc has none compiled: only the C locale
  works, and no zone can be named.
- **How many recipes port unchanged.**  Of the first seven from
  `elements/base/`, six did; util-linux needed one argument.  systemd is
  ported with what needs a library not yet here turned off
  (`base/systemd.sh`).  The claim is "nearly all" until many more have
  been ported.
- **Python's modules.**  The Python that builds run has only the modules
  that need no library.  zlib's is a package of its own, compiled from
  Python's source and laid over it (`base/python-extension.sh`), and
  ctypes after it; whether the next ones go the same way, or a system's
  Python is built whole, is open.

- **A disk is not the same disk twice.**  `images/disk.nix` built again
  of the same things differs (`nix-build --check` says so), in the
  partition a machine boots from: a FAT file system has a serial number
  and times of its own making.  x86's is the same.  What matters of it
  is the same: `/usr`'s image and its hash are, and so is the kernel
  image.

## What the image that boots lacks

It is systemd with a network (networkd, resolved, timesyncd), Wi-Fi
(iwd), sshd, and accounts as x86 has them: PAM with x86's rules
(`files/rootfs/usr/lib/pam.d`), logins that are sessions of logind's,
shadow's tools, and a console that is root's shell until root has a
password and a login prompt from then on
(`BUNIX_CHECK_SCRIPT=tools/vm-checks/accounts.sh tools/boot-vm.sh disk
check` goes through them on a running system).  SSH takes keys only.  A
member of wheel becomes root for a command with `run0`: it asks polkit,
which asks them for their own password (`tools/vm-checks/run0.sh`, run
the same way).  systemd's own rule for polkit is there too: a member of
the group `empower` is asked nothing, and only root can add one.
A user changes their own password with `passwd` and their shell with
`chsh`, to fish or back to bash (`tools/vm-checks/passwd-chsh.sh`); a new
user's shell, and root's, is bash.  The two programs are set-user-id, and
the only ones.  A Nix build may not make a file so; the image says they
are, where it describes each file: /usr's file system is made of an
archive, which names a mode for every file, and not of the tree.
It has no kernel modules, no locales or time zones, no firewall.  A Wi-Fi network is joined once by hand, with `iwctl`, and
again by itself where there is a disk to remember it on.  In memory the
machine's id is new at every boot, unless the command line gives it one;
on a disk it is made at the first boot and kept.  A machine told of a partition that is not there comes up
in memory all the same.

Of systemd, not on yet, each for want of a library: the
TPM, and seccomp,
without which systemd's own services are not confined to the system
calls they need (`base/systemd.sh`).

Suspend is systemd's and the kernel's.  On the 13-inch MacBook Pro M1 it
was asked for once (`systemctl suspend`), and opening the lid woke it,
with Wi-Fi and the disk as they were; logind suspends when the lid
closes.  How long a battery lasts asleep is not measured.

Its kernel has, built in because nothing loads modules, what an M1
laptop and a Mac mini need to reach the disk, Ethernet, Wi-Fi, a
keyboard (USB, and the M1 laptops' own), a display on USB-C, and a
network over a USB cable to another computer; and it installs Apple's
device trees.  What has run on a Mac is in "On a Mac"; the Mac mini's
parts (Ethernet, the display on USB-C) have not.

On x86_64 the kernel is the same source with the architecture's own
default configuration and `boot/linux/x86_64.config`, which is the
kernel of bunix on x86 so far (`files/linux/x86_64.fragment`) built
without modules; the file's first lines list what else differs.  So it
has what a virtual machine needs, and a PC with a wired network and the
firmware's own picture on its screen; not the drivers of real GPUs,
Wi-Fi, Bluetooth or sound, nor the wired network chips that load
firmware: those need modules and firmware in `/usr`.  The architecture's
default configuration builds some of them in, and the file turns those
off by name.
Its build needs libelf (`base.elfutils`) and zstd, which a Mac's does
not.  Built on the x86_64 builder, it has started the system in an
emulated PC (QEMU on the Mac, with no hypervisor): from memory, and from
a disk of `images/disk.nix` through EFI firmware, systemd-boot and the
kernel image, with `/usr` checked against its hash and the root
partition made at the first start (whose rule gets x86's `/lib64` link
when the image is made: `images/image.sh`).  Nothing else of it is tried
there: the tests that install, update and go back (`tools/`) run on a
Mac, for aarch64.  And a PC's serial port has no shell on it: the
console's is enabled for the screen and for the serial ports of a Mac
and of an Arm virtual machine.

Aurora's source is at Linux 7.3.0 and does not follow the 7.3.x
releases that carry fixes (2026-11-21: its branch says 7.3.0 at our
commit and at its head).  That is to be settled before a system for
x86, which so far has a kernel from kernel.org's long-term line, is
published with this one.

Firmware is the machine's, not a package: Apple's Wi-Fi firmware is in
each Mac's own macOS, and is added to the image when that Mac is booted
(`boot/linux/aarch64.config`); the USB-A ports of a Mac mini need
firmware too, and have none.  The regulatory database is a package.

On a disk that firmware is in `/var/lib/vendorfw`, on the root
partition: `bunix-install` copies there what the system in memory was
handed, so a Mac is installed from a boot that had its firmware
(`BUNIX_FIRMWARE`).  An update replaces `/usr` and leaves it.  The
drivers are built into the kernel and ask for firmware before the root
partition is mounted, so `vendor-firmware.service` names the directory
to the kernel once it can be read, and has the PCI devices that were
left without a driver tried again (a Mac's Wi-Fi is one).  A system
that was handed firmware when it was started keeps that.  Asahi keeps the archive on the ESP and
unpacks it in the initramfs at every start; here the initramfs is the
same for every machine and knows nothing of this.  Tried on the 13-inch
MacBook Pro M1, started from its disk: the driver fails as the kernel
starts, is asked again three seconds later, and the Mac joins its
network.

The copy is the one of the day bunix was installed: nothing brings a
newer one after macOS is updated, and a system installed before this
has none until it is installed again.

The regulatory database is asked for in the same too-early way, by code
that is built in for every machine, and is the same file everywhere: it
is in the initramfs as well as in `/usr`.

## Order of work

| Step | Done when | |
|---|---|---|
| 1. Staging: a build with a `/usr` made of its dependencies | `nix/tests/usr-staging`, `usr-glibc` pass on both builders | done |
| 2. glibc for `/usr`, built by stage 1's gcc | a program linked against it runs in a staged build, loader `/lib/ld-linux-...` | done |
| 3. binutils and gcc for `/usr` | `nix/tests/usr-toolchain`: C and C++, threads, shared libraries and LTO with no flags, no store path in the results | done |
| 4. tools: bash, coreutils, make and the rest, built by that gcc | `nix/tests/usr-build-environment`: glibc builds again with the system's compiler and tools alone, and comes out the same, file for file | done |
| 5. The image as a union of `/usr` trees | `tools/boot-vm.sh` boots it; `ldd` shows `/usr/lib` paths; there is no `/nix` | done (aarch64; on x86_64 it boots in an emulated PC, by hand) |
| 6. Remove stage 3 and the store-layout packages; move the bootstrap under `nix/bootstrap/` | the tests that remain pass on both builders | done |
