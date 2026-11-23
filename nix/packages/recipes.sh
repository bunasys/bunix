# What a machine is given to install packages by (packages.nix), in
# /usr/share/bunix/packages, a directory a recipe:
#
#   about        what `bunix install` reads: lines of key=value (version,
#                description, url, sha256, needs)
#   environment  the variables the recipe gives its script, as a shell
#                reads them
#   build.sh     the script, as a build here runs it
#
# and /usr/lib/bunix/build-package, which runs such a script on a
# machine.
#
# $recipes is a word a recipe: its name and its three files, with colons
# between.
packages=$out/usr/share/bunix/packages
for recipe in $recipes; do
    IFS=: read -r name about environment script <<< "$recipe"
    install -D -m 644 $about $packages/$name/about
    install -D -m 644 $environment $packages/$name/environment
    install -D -m 644 $script $packages/$name/build.sh
done

# What is this architecture's, and this build's, there as here: the
# directory of libraries, and the compiler's flags (this build has them
# as every package's does, from tools.nix).
builder=$out/usr/lib/bunix/build-package
install -D -m 755 $build_package $builder
sed -i -e "s|@triplet@|$triplet|" -e "s|@CFLAGS@|$CFLAGS|" \
    -e "s|@CXXFLAGS@|$CXXFLAGS|" -e "s|@LDFLAGS@|$LDFLAGS|" $builder
if grep -q '@[A-Za-z]*@' $builder; then
    echo "recipes.sh: build-package still has a name to fill in" >&2
    exit 1
fi
