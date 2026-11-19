unpack $src
# The Python that builds run (tools.nix) has no zlib, and meson asks for
# gzip when it starts, only to unpack what it downloads from its package
# index, which a build here never does.  The import is moved into the one
# function that uses it.  To go when that Python has zlib.
grep -q '^import gzip$' mesonbuild/wrap/wrap.py
sed -i -e '/^import gzip$/d' \
    -e 's/^\( *\)return gzip.decompress(data)$/\1import gzip\n\1return gzip.decompress(data)/' \
    mesonbuild/wrap/wrap.py
grep -q '^ *import gzip$' mesonbuild/wrap/wrap.py
# Meson is Python and nothing else, so installing it is copying it: no
# need for Python's packaging tools.  The program is what its own
# packaging would generate.
site=$out$(python3 -c 'import sysconfig; print(sysconfig.get_path("purelib"))')
mkdir -p $site $out/usr/bin
cp -r mesonbuild $site/
cat > $out/usr/bin/meson <<'END'
#!/usr/bin/python3
import sys
from mesonbuild.mesonmain import main
sys.exit(main())
END
chmod 755 $out/usr/bin/meson
