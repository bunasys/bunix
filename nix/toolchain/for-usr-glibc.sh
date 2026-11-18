# For the two packages that stage 1's gcc compiles for the system: binutils
# and gcc.  (glibc is not compiled for a glibc.)
#
# Stage 1's gcc builds programs for stage 1's glibc, in the store.  These
# flags have it use the start files and libraries of the one staged at
# /usr, and the loader by its usual path.  The headers need no flag: both
# glibcs are the same version, and their headers the same files.
case $system in
    aarch64-linux) loader=/lib/ld-linux-aarch64.so.1 ;;
    x86_64-linux) loader=/lib64/ld-linux-x86-64.so.2 ;;
    *) echo "for-usr-glibc.sh: the loader's path for $system is not known" >&2; exit 1 ;;
esac
for_usr_glibc_flags="-B/usr/lib/$triplet -Wl,--dynamic-linker=$loader"
