# The compiler: gcc as built ($whole), without the files that are the
# gcc-libraries package ($libraries), which it depends on (toolchain.nix).
mkdir -p $out
cp -a --no-preserve=ownership $whole/usr $out/
chmod -R u+w $out/usr
(cd $libraries/usr && find . ! -type d) | while read -r file; do
    rm "$out/usr/$file"
done
