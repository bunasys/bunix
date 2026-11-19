unpack $src
# A module that is Python and nothing else: installing it is copying it,
# as for meson.  $module is its directory under the source's src/.  The C
# files some have, to be faster, are optional and left out.
site=$out$(python3 -c 'import sysconfig; print(sysconfig.get_path("purelib"))')
mkdir -p $site
cp -r src/$module $site/
rm -f $site/$module/*.c
