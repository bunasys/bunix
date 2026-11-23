unpack $src
# ninja builds itself, with a python script, and has no install step.
python3 configure.py --bootstrap
install -D -m 755 ninja $out/usr/bin/ninja
