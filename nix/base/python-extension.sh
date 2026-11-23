unpack $src
# One module of Python's standard library that needs a library, compiled
# by hand against the Python that is installed, as Python's own build
# compiles it.  The Python that builds run is built before any library
# (tools.nix), and so without these.
#
#   $module     its name, as Python imports it
#   $c_files    its C files, in Python's source
#   $flags      what Python's configure would have found out with the
#               library there, and the library to link
#   $try        Python that fails if the module does not work: here, not
#               inside the build of what needs it
#
# -DPy_BUILD_CORE_MODULE, -I.../internal: a module of the standard library
#   may use Python's internal headers.
# -DNDEBUG, -fno-strict-overflow: Python's own flags.
suffix=$(python3 -c 'import sysconfig; print(sysconfig.get_config_var("EXT_SUFFIX"))')
modules=$(python3 -c 'import sysconfig; print(sysconfig.get_path("platstdlib"))')/lib-dynload
headers=$(python3 -c 'import sysconfig; print(sysconfig.get_path("include"))')
mkdir -p $out$modules
gcc $CFLAGS -DNDEBUG -fno-strict-overflow -shared -fPIC \
    -DPy_BUILD_CORE_MODULE -I$headers -I$headers/internal -IModules \
    $c_files $flags -o $out$modules/$module$suffix
PYTHONPATH=$out$modules python3 -c "$try"
