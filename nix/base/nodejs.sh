unpack $src

# One compiler for every two gigabytes of memory, and no more than $jobs:
# V8's largest files take a gigabyte or two each to compile, and the
# Mac's virtual machine has many processors and little memory.
kb_for_a_compiler=$((2 * 1024 * 1024))
memory_kb=$(awk '/^MemTotal:/ { print $2 }' /proc/meminfo)
compilers=$((memory_kb / kb_for_a_compiler))
[ "$compilers" -ge 1 ] || compilers=1
[ "$compilers" -le "$jobs" ] || compilers=$jobs

# configure.py itself: the `configure` wrapper only accepts the Python
# versions known when Node 24 came out, and the system's is newer.
python3 configure.py --prefix=/usr --ninja
ninja -C out/Release -j$compilers
# Node's makefile installs what is built, and first has ninja look again
# at whether all of it is: with as many compilers, should it find work.
MAKEFLAGS=-j$compilers make install DESTDIR=$out BUILDTYPE=Release

# /usr is the system's, and read-only: what `npm install --global` adds
# goes to /usr/local, where a machine's own software is.  (npm reads this
# file of its own before any other settings.)
echo prefix=/usr/local > $out/usr/lib/node_modules/npm/npmrc

$out/usr/bin/node --version
# npm, npx and corepack are scripts Node runs, linked from /usr/bin: a
# link that points outside what is installed is found here
test -e $out/usr/bin/npm
test -e $out/usr/bin/npx
test -e $out/usr/bin/corepack
