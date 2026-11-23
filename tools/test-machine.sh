# Where bunix is built and where its virtual machines run, for
# tools/boot-vm.sh and the tests: read by them (`. test-machine.sh`), not
# run.  One of two places, by the architecture asked for:
#
#   BUNIX_ARCHITECTURE=aarch64   (the default)
#       built in the builder of this Mac (tools/nix-builder/lima.yaml),
#       and run here, by this Mac's QEMU on its own processor
#   BUNIX_ARCHITECTURE=x86_64
#       built on the x86_64 builder (BUNIX_X86_BUILDER, for ssh; default
#       enas-asus.home.arpa), and run there on its processor (KVM), by
#       the QEMU that is a package of bunix's (nix/base.nix), which
#       tools/nix-builder/with-usr.sh starts.  The builder is sent the
#       working tree first, and builds QEMU.
#
# Either way the script that reads this runs on the Mac, and finds the
# machine's SSH port at 127.0.0.1, and the machine finds what the Mac
# serves at 10.0.2.2: for x86_64 both ports are carried by the ssh that
# runs QEMU.
#
# The script sets `tool`, its name, before it reads this.  Reading it
# does nothing but name things; a script has, from then on:
#
#   $architecture       aarch64 or x86_64
#   $architecture_in_file_names
#                       arm64 or x86-64, as update files are named
#   $console            the kernel's name for the machine's serial port
#   $machine_on_real_processor
#                       QEMU's arguments for a machine on the processor
#                       there is
#
#   prepare_machine     what costs something, done once the script has
#                       found nothing wrong with what it was asked: its
#                       directories, emptied; and for x86_64 the working
#                       tree sent, and QEMU built
#
# and after prepare_machine:
#
#   $work               the script's directory on this Mac: one for each
#                       architecture, so that a test of one does not
#                       take the files of a test of the other
#   $machine_directory  the directory QEMU finds its files in: on this
#                       Mac, or on the x86_64 builder; never $work
#   $source             the repository as a build names it:
#                       build $source/nix/images/disk.nix
#   $efi_firmware       QEMU's arguments for the EFI firmware that comes
#                       with it
#
#   build <nix-build's arguments>
#                       prints where the builder's store has the result
#   release_version     prints the version being built (nix/release.nix)
#   copy_built_file <file in the store> <file here>
#   copy_built_directory <directory in the store> <directory here>
#   copy_built_file_to_machine <file in the store> <name>
#                       out of the builder's store, writable: to this
#                       Mac, or into $machine_directory.  A file's path
#                       may have a * in it, for the one file it names.
#   send_to_machine <name>
#                       $work/<name>, made here, into $machine_directory
#   in_machine_directory <shell commands>
#                       runs them there.  No single quote in them, and
#                       programs that a Mac and a Linux both have.
#   run_qemu <QEMU's arguments>
#                       a machine whose console is this terminal, in
#                       place of the script: it does not come back.
#                       What every machine here has is added: four
#                       processors, 4 GB, a network card whose port 22
#                       is 127.0.0.1's $ssh_port, no window for its
#                       screen, and an end where a real machine would
#                       restart.  With BUNIX_MONITOR set, QEMU's
#                       monitor is the socket $machine_directory/monitor,
#                       where QEMU runs: `screendump <file>` sent there
#                       writes the screen as a picture.
#   start_qemu <QEMU's arguments>
#                       the same behind the script, its console in
#                       $work/console.log; `kill -0 $qemu` asks whether
#                       it still runs
#   end_qemu            ends that one, as a plug pulled, and comes back
#                       when it is gone
#
# $ssh_port, and $http_port if the Mac serves the machine files, are the
# script's, set before it starts a machine.
#
# Nothing is cleared away on the x86_64 builder when a script ends: its
# directory there (~/bunix-test/<tool>) stays until the script runs
# again, as $work does here.

architecture=${BUNIX_ARCHITECTURE:-aarch64}

case $architecture in
aarch64)
    architecture_in_file_names=arm64
    console=ttyAMA0
    # -accel hvf: the Mac's hypervisor
    machine_on_real_processor="-M virt -accel hvf -cpu host"

    prepare_place() {
        source=/bunix
        machine_directory=$work/machine
        mkdir "$machine_directory"
        efi_firmware="-bios $(dirname "$(command -v qemu-system-aarch64)")/../share/qemu/edk2-aarch64-code.fd"
    }
    # nix-build prints the store path of what it built, and nothing else,
    # on its standard output.  No pipe after it: a failed build has to
    # stop the script.
    build() {
        limactl shell bunix-builder nix-build "$@" --no-out-link
    }
    evaluate() {
        limactl shell bunix-builder nix-instantiate --eval "$1"
    }
    # (the one file: with two, cat would make one of both)
    copy_built_file() {
        limactl shell bunix-builder sh -c "set -- $1 && [ \$# = 1 ] && cat \"\$1\"" > "$2"
    }
    copy_built_directory() {
        mkdir -p "$2"
        limactl copy -r "bunix-builder:$1/." "$2/"
        chmod -R u+w "$2"
    }
    copy_built_file_to_machine() {
        copy_built_file "$1" "$machine_directory/$2"
    }
    send_to_machine() {
        cp "$work/$1" "$machine_directory/$1"
    }
    in_machine_directory() {
        (cd "$machine_directory" && sh -c "$1")
    }
    qemu_itself() {
        exec qemu-system-aarch64 "$@"
    }
    end_qemu() {
        kill "$qemu" 2> /dev/null || true
        wait "$qemu" 2> /dev/null || true
    }
    ;;

x86_64)
    architecture_in_file_names=x86-64
    console=ttyS0
    machine_on_real_processor="-M q35 -accel kvm -cpu host"

    builder_host=${BUNIX_X86_BUILDER:-enas-asus.home.arpa}
    # in_builder <shell commands>: runs them on the builder, in its
    # user's home.  No single quote in them: they go inside a pair.  The
    # builder's own shell is not bash, and its Nix is one installed for
    # its user alone (tools/nix-builder/home-store/nix.conf), found by
    # these two variables; its store is under the home directory too.
    builder_nix='export NIX_CONF_DIR=$HOME/nix-tool PATH=$HOME/nix-tool/bin:$PATH'
    in_builder() {
        ssh "$builder_host" "bash -c '$builder_nix && $1'"
    }

    prepare_place() {
        builder_home=$(in_builder 'echo $HOME')
        builder_store=$builder_home/nix-root
        # the tool's own, so that two tools at once do not take each
        # other's
        source=$builder_home/bunix-test/$tool/source
        machine_directory=$builder_home/bunix-test/$tool/machine
        # The firmware is in QEMU's package, which is its /usr when it
        # runs; what the firmware keeps from one start to the next
        # (EFI's variables) is a file it writes, a copy of the package's
        # empty one.
        efi_firmware="-drive if=pflash,format=raw,readonly=on,file=/usr/share/qemu/edk2-x86_64-code.fd -drive if=pflash,format=raw,file=$machine_directory/efi-variables.fd"

        echo "x86_64: sending the working tree to $builder_host, and building QEMU there"
        # What is tested is the working tree: what git has of it and is
        # still there, and what is new and not ignored.  Not the
        # browser's source and BuildStream's elements, which no build
        # here reads.
        repository=$(cd "$(dirname "$0")/.." && pwd)
        (cd "$repository" && git ls-files --cached --others --exclude-standard |
            grep -v -E '^(files/hudhud|elements)/' |
            while IFS= read -r file; do
                if [ -e "$file" ] || [ -L "$file" ]; then echo "$file"; fi
            done > "$work/source-files"
            COPYFILE_DISABLE=1 tar --no-xattrs -T "$work/source-files" -cf "$work/source.tar")
        # A machine that a run cut short left behind still has its port:
        # ended first, if it is one (-pidfile, below).
        in_builder "left=\$(cat $machine_directory/qemu.pid 2> /dev/null) &&
            grep -q -a qemu-system /proc/\$left/cmdline 2> /dev/null && kill \$left
            rm -rf $source $machine_directory && mkdir -p $source $machine_directory &&
            tar -xf - -C $source" < "$work/source.tar"
        rm "$work/source.tar" "$work/source-files"
        qemu_package=$(build "$source/nix/base.nix" -A qemu)
        in_builder "cp $builder_store$qemu_package/usr/share/qemu/edk2-i386-vars.fd $machine_directory/efi-variables.fd &&
            chmod u+w $machine_directory/efi-variables.fd"
    }
    build() {
        in_builder "nix-build $* --no-out-link"
    }
    evaluate() {
        in_builder "nix-instantiate --eval $1"
    }
    copy_built_file() {
        in_builder "set -- $builder_store$1 && [ \$# = 1 ] && cat \"\$1\"" > "$2"
    }
    # Through a file, not a pipe: a copy that fails on the builder has to
    # stop the script.
    copy_built_directory() {
        mkdir -p "$2"
        in_builder "tar -C $builder_store$1 -cf - ." > "$work/built.tar"
        tar -xf "$work/built.tar" -C "$2"
        rm "$work/built.tar"
        chmod -R u+w "$2"
    }
    copy_built_file_to_machine() {
        in_builder "cp --sparse=always $builder_store$1 $machine_directory/$2 && chmod u+w $machine_directory/$2"
    }
    send_to_machine() {
        in_builder "cat > $machine_directory/$1" < "$work/$1"
    }
    in_machine_directory() {
        in_builder "cd $machine_directory && $1"
    }
    # QEMU's arguments go ahead of it, in a file, a line each: some have
    # spaces in them, and would not get through two shells whole.
    # -tt: with a terminal there, QEMU ends when this ssh does.
    # -pidfile: for end_qemu, and for the next run (prepare_place).
    qemu_itself() {
        printf '%s\n' "$@" -pidfile "$machine_directory/qemu.pid" |
            in_builder "cat > $machine_directory/qemu-arguments"
        carried_ports="-L 127.0.0.1:$ssh_port:127.0.0.1:$ssh_port"
        if [ -n "${http_port:-}" ]; then
            carried_ports="$carried_ports -R 127.0.0.1:$http_port:127.0.0.1:$http_port"
        fi
        # shellcheck disable=SC2086  # the ports are several words
        exec ssh -tt -o ExitOnForwardFailure=yes $carried_ports "$builder_host" "bash -c '$builder_nix &&
            cd $machine_directory && mapfile -t arguments < qemu-arguments &&
            exec $source/tools/nix-builder/with-usr.sh $qemu_package -- qemu-system-x86_64 \"\${arguments[@]}\"'"
    }
    # $qemu is the ssh, which ends at once; QEMU, on the builder, a moment
    # after it, and until then it has the disk and the ports that the
    # next machine is to have.
    end_qemu() {
        kill "$qemu" 2> /dev/null || true
        wait "$qemu" 2> /dev/null || true
        in_builder "while kill -0 \$(cat $machine_directory/qemu.pid 2> /dev/null) 2> /dev/null; do sleep 0.2; done"
    }
    ;;

*)
    echo "$tool: BUNIX_ARCHITECTURE is aarch64 or x86_64, not $architecture" >&2
    exit 1
    ;;
esac

# ---- Of either place -------------------------------------------------------------

prepare_machine() {
    work=${TMPDIR:-/tmp}/bunix-${tool%.sh}-$architecture
    rm -rf "$work"
    mkdir -p "$work"
    prepare_place
}

# evaluate prints what Nix makes of a file: a string as it is written,
# in quotes.
release_version() {
    version_in_quotes=$(evaluate "$source/nix/release.nix")
    version_in_quotes=${version_in_quotes#\"}
    echo "${version_in_quotes%\"}"
}

run_qemu() {
    # A socket in the machine's own directory, not a port: whoever
    # reaches QEMU's monitor can have it write files and run programs.
    # Without it the monitor is at the terminal, with the machine's
    # console (Ctrl-a c).
    monitor=
    if [ -n "${BUNIX_MONITOR:-}" ]; then
        monitor="-monitor unix:$machine_directory/monitor,server=on,wait=off"
    fi
    # shellcheck disable=SC2086  # the monitor's words are two
    qemu_itself "$@" -smp 4 -m 4G -nographic -no-reboot $monitor \
        -netdev "user,id=net,hostfwd=tcp:127.0.0.1:$ssh_port-:22" -device virtio-net-pci,netdev=net
}
# run_qemu takes the place of what runs it, which behind the script is a
# shell of its own: so $qemu is QEMU, or the ssh it ends with, and not a
# shell that would leave it running.
start_qemu() {
    run_qemu "$@" < /dev/null >> "$work/console.log" 2>&1 &
    qemu=$!
}
