# The part of gcc that what it compiles needs to run: the shared libraries
# by the names programs ask for them (libstdc++.so.6, libgcc_s.so.1, the
# sanitizers'...).  $whole is gcc as built (toolchain.nix).
#
# Not the names without a version (libstdc++.so): those are what the
# linker looks for, and go with the compiler.
mkdir -p $out/usr/lib/$triplet
# --no-preserve=ownership: the files are nobody's here, and there is no one
# to give the copies to but the build itself
cp -a --no-preserve=ownership $whole/usr/lib/$triplet/*.so.* $out/usr/lib/$triplet/
# a script for gdb, named after libstdc++.so.6.x so that it matched
rm $out/usr/lib/$triplet/*-gdb.py
