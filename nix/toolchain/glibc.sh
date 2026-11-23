unpack $src

# the kernel's headers, beside glibc's own
mkdir -p $out/usr
cp -r $linux_headers/include $out/usr/
chmod -R u+w $out/usr/include

mkdir build
cd build

# UAPI.9: /usr/sbin is a link to /usr/bin, and there is no /usr/libexec.
# glibc takes these from configparms, not from configure.
printf '%s\n' rootsbindir=/usr/bin sbindir=/usr/bin libexecdir=/usr/lib > configparms

# --libdir, libc_cv_slibdir: libraries, and the loader, in the directory
#   named after the architecture.
# --enable-kernel: as in project.conf (glibc-min-kernel)
../configure \
    --prefix=/usr --libdir=/usr/lib/$triplet libc_cv_slibdir=/usr/lib/$triplet \
    --with-headers=$out/usr/include --enable-kernel=5.4 \
    --enable-stack-protector=strong \
    --disable-nscd --disable-werror
make
make DESTDIR=$out install

# The install runs ldconfig, which writes a cache of the libraries it sees
# there and then; an image makes its own.  var/ holds only a Makefile.
rm -r $out/etc/ld.so.cache $out/var

# ldd, sotruss, tzselect and xtrace are bash scripts.  glibc cannot need
# bash, which needs glibc; they are left out.  (`ld.so --list <program>`
# is what ldd runs.)
for program in $out/usr/bin/*; do
    if [ "$(head -c 2 $program)" = '#!' ]; then
        rm $program
    fi
done

# A program asks for its loader by one fixed path ($loader):
# /lib/ld-linux-aarch64.so.1 on aarch64, /lib64/ld-linux-x86-64.so.2 on
# x86_64.  /lib is /usr/lib and /lib64 is /usr/lib/$triplet (stage.sh, and
# any image), so x86_64's is found; aarch64's needs this link beside the
# directory.
if [ $system = aarch64-linux ]; then
    ln -s $triplet/ld-linux-aarch64.so.1 $out/usr/lib/ld-linux-aarch64.so.1
fi
