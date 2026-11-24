# Each of $fonts is a file in the store named <hash>-<family>--<file>:
# a font goes to /usr/share/fonts/<family>, its license to
# /usr/share/licenses/fonts-<family>.
for path in $fonts; do
    name=${path##*/}
    name=${name#*-}
    family=${name%%--*}
    file=${name#*--}
    case $file in
        OFL.txt) install -D -m 644 $path $out/usr/share/licenses/fonts-$family/OFL.txt ;;
        *) install -D -m 644 $path $out/usr/share/fonts/$family/$file ;;
    esac
done

# Kawkab Mono, from its release's zip: its TrueType files, not the
# OpenType ones next to them, which are the same faces again, nor its
# web fonts
mkdir kawkab-mono
bsdtar -xf $kawkab_mono --strip-components=1 -C kawkab-mono
install -D -m 644 -t $out/usr/share/fonts/kawkabmono kawkab-mono/KawkabMono-*.ttf
install -D -m 644 kawkab-mono/OFL.txt $out/usr/share/licenses/fonts-kawkabmono/OFL.txt
