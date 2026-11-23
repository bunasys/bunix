unpack $src

# perl records when it was configured, by running `date`, and takes no
# option for it: the date it runs is given the time every build has.
sed -i '/^cf_time=/s|\$date 2>&1|$date -u -d @'$SOURCE_DATE_EPOCH' 2>\&1|' Configure
grep -q "^cf_time=.*-d @$SOURCE_DATE_EPOCH" Configure

# perl's Configure is its own, not autoconf's.
# Arch Linux's layout: core modules in core_perl, distribution-packaged
#   modules in vendor_perl; architecture-independent ones under /usr/share.
# -Dman1dir, -Dman3dir: no manual pages; the element installs them.
# -Dlibpth: Configure looks for libraries as files, in directories it
#   guesses; they are in the one named after the architecture.
# -Dcf_by ... -Dosvers: perl records who built it, on which machine and
#   kernel: always the same here.
sh Configure -des -Dcc=gcc \
    -Dprefix=/usr -Dvendorprefix=/usr \
    -Dprivlib=/usr/share/perl5/core_perl -Darchlib=/usr/lib/perl5/core_perl \
    -Dvendorlib=/usr/share/perl5/vendor_perl -Dvendorarch=/usr/lib/perl5/vendor_perl \
    -Dsitelib=/usr/share/perl5/site_perl -Dsitearch=/usr/lib/perl5/site_perl \
    -Dscriptdir=/usr/bin -Dsitescript=/usr/bin -Dvendorscript=/usr/bin \
    -Dman1dir=none -Dman3dir=none \
    -Dinc_version_list=none -Duseshrplib -Dusethreads \
    -Dlibpth="/usr/lib/$triplet /usr/lib" \
    -Doptimize="$CFLAGS" -Dldflags="$LDFLAGS" -Dlddlflags="-shared $LDFLAGS" \
    -Dcf_by=bunix -Dcf_email=root -Dperladmin=root \
    -Dmyhostname=bunix -Dmydomain=.bunix -Dmyuname=bunix -Dosvers=bunix
make
make DESTDIR=$out install
