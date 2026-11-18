unpack $src

# perl's Configure is its own, not autoconf's.
# -Dlocincpth, -Dloclibpth, -Dlibpth, -Dusrinc: it looks for headers and
#   libraries as files in /usr, which is not there, and leaves out what it
#   does not find (the maths library, for one); glibc's are in the store.
# -Dcf_by ... -Dosvers: perl records who built it, on which machine and
#   kernel: always the same here.
sh Configure -des -Dcc=gcc -Dprefix=$out \
    -Dlocincpth=$glibc/include -Dusrinc=$glibc/include \
    -Dloclibpth=$glibc/lib -Dlibpth=$glibc/lib \
    -Dman1dir=none -Dman3dir=none -Dinc_version_list=none \
    -Dcf_by=bunix -Dcf_email=root -Dperladmin=root \
    -Dmyhostname=bunix -Dmydomain=.bunix -Dmyuname=bunix -Dosvers=bunix
make
make install

# perl keeps how it was built, for building modules later, with the full
# path of each tool Configure found: sed, grep, ar and thirty more, all the
# build's own.  They become names, to be found on PATH.
recorded=$(find $out/lib -name Config.pm -o -name Config_heavy.pl -o -name config.h)
[ -n "$recorded" ]
for directory in ${PATH//:/ }; do
    sed -i "s|$directory/||g" $recorded
done
