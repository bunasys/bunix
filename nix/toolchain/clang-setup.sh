# What clang needs on a bunix that LLVM's own package does not have
# (toolchain.nix).  $whole is gcc as built.
#
# Of gcc, the three things clang takes from it on Linux:
#   - the start and end of every program, and the compiler's support
#     library, in gcc's own directory, which clang looks for by the name
#     gcc was installed under
#   - the C++ library's headers
#   - the names the linker asks for gcc's shared libraries by
#     (libstdc++.so, libgcc_s.so): the libraries themselves are the
#     gcc-libraries package's
gcc_directory=$(cd $whole/usr && echo lib/gcc/$triplet/*)
mkdir -p $out/usr/$gcc_directory $out/usr/lib/$triplet $out/usr/include $out/usr/bin
cp -a --no-preserve=ownership $whole/usr/$gcc_directory/crt*.o \
    $whole/usr/$gcc_directory/libgcc.a $whole/usr/$gcc_directory/libgcc_eh.a $out/usr/$gcc_directory/
cp -a --no-preserve=ownership $whole/usr/include/c++ $out/usr/include/
for library in libstdc++ libgcc_s libgcc_s_asneeded libatomic libatomic_asneeded; do
    cp -a --no-preserve=ownership $whole/usr/lib/$triplet/$library.so $out/usr/lib/$triplet/
done

# And clang's own settings, which it reads from beside its program:
# LLVM's linker, where it would run binutils' (-fuse-ld=lld).  That one
# links what clang compiles for optimizing at link time (-flto), which
# binutils' cannot read without a plugin LLVM is not built with here.
for driver in clang clang++; do
    echo "-fuse-ld=lld" > $out/usr/bin/$driver.cfg
done
