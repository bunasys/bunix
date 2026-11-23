unpack $src

# the kernel has its own names for architectures
case $system in
    aarch64-linux) kernel_arch=arm64 ;;
    x86_64-linux) kernel_arch=x86_64 ;;
    *) echo "linux-headers.sh: the kernel's name for $system is not known" >&2; exit 1 ;;
esac

# The kernel's build compiles a few helper programs and runs them.
make ARCH=$kernel_arch HOSTCC="$CC" headers
find usr/include -type f ! -name '*.h' -delete

mkdir -p $out
cp -r usr/include $out/
