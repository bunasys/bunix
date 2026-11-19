unpack $src
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
