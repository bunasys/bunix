unpack $src
# A module that is Python and nothing else: installing it is copying it,
# as for meson.  $module_paths is what of the source is the module: a
# directory, or files.  The C files some have, to be faster, are optional
# and left out.
site=$out$(python3 -c 'import sysconfig; print(sysconfig.get_path("purelib"))')
mkdir -p $site
cp -r $module_paths $site/
find $site -name '*.c' -delete
