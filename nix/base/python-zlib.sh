unpack $src
# One module of Python's standard library, compiled by hand against the
# Python that is installed, as Python's own build compiles it:
# -DPy_BUILD_CORE_MODULE, -I.../internal: a module of the standard library
#   may use Python's internal headers.
# -DHAVE_ZLIB_COPY: Python's configure sets it when it finds zlib, which
#   the installed Python's did not; without it, no copy() of a stream.
# -DNDEBUG, -fno-strict-overflow: Python's own flags.
suffix=$(python3 -c 'import sysconfig; print(sysconfig.get_config_var("EXT_SUFFIX"))')
modules=$(python3 -c 'import sysconfig; print(sysconfig.get_path("platstdlib"))')/lib-dynload
headers=$(python3 -c 'import sysconfig; print(sysconfig.get_path("include"))')
mkdir -p $out$modules
gcc $CFLAGS -DNDEBUG -fno-strict-overflow -shared -fPIC \
    -DPy_BUILD_CORE_MODULE -DHAVE_ZLIB_COPY=1 -I$headers -I$headers/internal -IModules \
    Modules/zlibmodule.c -lz -o $out$modules/zlib$suffix
# fails here if it does not load, not inside the build of what needs it
PYTHONPATH=$out$modules python3 -c 'import zlib; zlib.decompressobj().copy()'
