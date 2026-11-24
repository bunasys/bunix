unpack $src
for fix in $patches; do
    patch --fuzz=0 -p1 -i $fix
done

# The drivers of the GPUs each architecture's machines have, and two for
# any: virgl, a virtual machine's GPU that hands OpenGL to its host, and
# llvmpipe, which draws with the processor.
#   x86_64   iris and crocus (Intel, 2006 on), radeonsi (AMD, GCN on)
#   aarch64  asahi (Apple's GPUs: Mesa's driver is for those of the M1
#            and M2 so far; the kernel's has more, boot/linux/aarch64.config)
case $system in
    x86_64-linux) drivers=iris,crocus,radeonsi,virgl,llvmpipe ;;
    aarch64-linux) drivers=asahi,virgl,llvmpipe ;;
    *) echo "mesa.sh: no drivers chosen for $system" >&2; exit 1 ;;
esac

# LLVM: llvmpipe compiles what it draws with it, and the Intel and Apple
# drivers' own programs are compiled to SPIR-V with clang while Mesa
# builds (mesa_clc, which is not installed).  Linked into Mesa
# (-Dshared-llvm=disabled), so that the extension has the part of LLVM
# that Mesa uses and not all of LLVM's library, which comes with clang
# and the rest of LLVM in one package (base.nix).
#
# -Damd-use-llvm=false: radeonsi compiles its shaders with ACO, Mesa's
# own compiler for AMD's GPUs.  The LLVM it would use otherwise is built
# without AMD's target (files/mesa/: the patch).
#
# -Dplatforms=wayland, -Dglx=disabled: Wayland only.  -Dgles1=disabled:
# OpenGL ES 2 and 3 and OpenGL; not ES 1.  -Dglvnd=disabled: one OpenGL,
# Mesa's, and no dispatcher between programs and it.
meson setup build --prefix=/usr --bindir=bin --sbindir=bin --libdir=lib/$triplet \
    --libexecdir=lib --sysconfdir=/etc --localstatedir=/var --buildtype=release \
    --wrap-mode=nodownload \
    -Dplatforms=wayland -Dgallium-drivers=$drivers -Dvulkan-drivers= \
    -Dglx=disabled -Degl=enabled -Dgbm=enabled -Dopengl=true -Dgles1=disabled \
    -Dgles2=enabled -Dglvnd=disabled \
    -Dllvm=enabled -Dshared-llvm=disabled -Damd-use-llvm=false \
    -Dgallium-va=disabled -Dvideo-codecs= -Dintel-rt=disabled -Dmicrosoft-clc=disabled \
    -Dgallium-rusticl=false -Dvalgrind=disabled -Dlibunwind=disabled \
    -Dlmsensors=disabled -Dselinux=false -Dzstd=enabled -Dexpat=enabled \
    -Dxmlconfig=enabled -Ddisplay-info=disabled -Dbuild-tests=false
ninja -C build -j$jobs
DESTDIR=$out ninja -C build install

# LLVM is inside it, and not something it loads
if find $out -type f -name '*.so*' -exec readelf -d {} \; | grep 'NEEDED.*libLLVM'; then
    echo "mesa.sh: Mesa loads LLVM's library, and was to have LLVM inside it" >&2
    exit 1
fi
