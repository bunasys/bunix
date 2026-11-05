kind: manual
description: |
  Ghostty -- the terminal: GTK 4 and libadwaita, drawn with OpenGL, its
  terminal core in libghostty.  Built with Zig 0.17 (base/zig.bst) from
  the release tarball, which comes with its GTK interface already compiled.
  Zig fetches nothing: every package Ghostty's build.zig.zon.json pins is a
  source below, unpacked to zig-deps/p/<its Zig hash>, which `--system`
  points Zig at.  FreeType, HarfBuzz, Fontconfig, libpng, zlib, Oniguruma
  and gtk4-layer-shell are the system's; the rest (glslang, SPIRV-Cross,
  simdutf, highway, wuffs, the fonts) Ghostty builds into itself.
  The two git packages (arocc, zigimg) come as archives of their pinned
  commits.

build-depends:
- bootstrap/build-env.bst
- base/zig.bst
- base/pkgconf.bst
- base/gettext.bst
- base/wayland-protocols.bst

depends:
- base/fontconfig.bst
- base/freetype.bst
- base/glib.bst
- base/gtk4.bst
- base/gtk4-layer-shell.bst
- base/harfbuzz.bst
- base/libadwaita.bst
- base/libpng.bst
- base/libxkbcommon.bst
- base/mesa.bst
- base/oniguruma.bst
- base/wayland.bst
- base/zlib.bst

environment:
  # Zig's caches, inside the build directory (the sandbox has no home)
  ZIG_GLOBAL_CACHE_DIR: "%{build-root}/.zig-global-cache"
  ZIG_LOCAL_CACHE_DIR: "%{build-root}/.zig-local-cache"

config:
  build-commands:
  - |
    # pkg-config names Ghostty's build asks for that this system has no
    # .pc file for, seen only by this build:
    # - bzip2: asked for with the system's FreeType.  bzip2 1.0.8 installs
    #   no .pc; adding one to base/bzip2.bst would rebuild nearly all of
    #   the base for one line.
    # - x11, harfbuzz-gobject: the generated GObject bindings list every
    #   library a namespace could use.  Ghostty calls nothing from them
    #   with X11 off, and Zig links only what is called: were that wrong,
    #   the link would fail on the missing symbol.
    mkdir -p pkgconfig-shims
    printf 'Name: bzip2\nDescription: bzip2 1.0.8\nVersion: 1.0.8\nLibs: -lbz2\nCflags:\n' \
      > pkgconfig-shims/bzip2.pc
    for name in x11 harfbuzz-gobject; do
      printf 'Name: %s\nDescription: not used\nVersion: 0\nLibs:\nCflags:\n' $name \
        > pkgconfig-shims/$name.pc
    done

  # ReleaseFast: Ghostty's recommendation for packages (its safety checks
  # cost too much speed in a terminal).  baseline: any x86-64 CPU, not
  # just the build machine's.  No docs: packaging mode makes the man pages
  # with pandoc, and the desktop extension leaves man pages out.  The
  # version is given: the tarball has no git history to read it from.
  - |
    PKG_CONFIG_PATH=$PWD/pkgconfig-shims DESTDIR=%{install-root} zig build \
      --prefix /usr --system "$PWD/zig-deps/p" \
      -Doptimize=ReleaseFast -Dcpu=baseline \
      -Dgtk-x11=false -Dgtk-wayland=true -Dsentry=false -Demit-docs=false \
      -Dinstalled-exe-path=/usr/bin/ghostty -Dversion-string=1.4.0

  install-commands:
  - ls -l %{install-root}/usr/bin/ghostty

sources:
- kind: tar
  url: https://release.files.ghostty.org/1.4.0/ghostty-1.4.0.tar.gz
  ref: cb188ac6c3a8278d5fd7bfef15d8c017104c87f638b5560eb38024a71ae0f005
# aro
- kind: tar
  url: https://codeberg.org/ziglang/arocc/archive/d0c8c4d9c55daa7ef6e40cf0f630a5b5e900989b.tar.gz
  ref: 42f5ac4d1fb7c55ad4073dc462b02d485ace4da6d7fc29b35acfa99e28f2cb7d
  directory: zig-deps/p/aro-0.0.0-JSD1QtuBNwCASyBtNF3pqTl_W3oAJQGEVyFAtrBSE_Pa
# bindings
- kind: tar
  url: https://deps.files.ghostty.org/DearBindings_v0.17_ImGui_v1.92.5-docking.tar.gz
  ref: 8bfec500e00926f679853ee23d67cc392d3c3181733ca4704738651d3f70baa3
  base-dir: ''
  directory: zig-deps/p/N-V-__8AANT61wB--nJ95Gj_ctmzAtcjloZ__hRqNw5lC1Kr
# breakpad
- kind: tar
  url: https://deps.files.ghostty.org/breakpad-b99f444ba5f6b98cac261cbb391d8766b34a5918.tar.gz
  ref: 6cca98943d1a990766cef61077c09aff5938063fe17a1efe1228e5412b6d6ad9
  directory: zig-deps/p/N-V-__8AALw2uwF_03u4JRkZwRLc3Y9hakkYV7NKRR9-RIZJ
# fontconfig
- kind: tar
  url: https://deps.files.ghostty.org/N-V-__8AAOgqbADacob-q2_DMQlmgaG4xKHRuW-6PJ4oJzMZ.tar.xz
  ref: 4f7b554a38cdf78c033f666c8871f3749e14a094f65a07f630c91ed0b43d35e3
  directory: zig-deps/p/N-V-__8AAOgqbADacob-q2_DMQlmgaG4xKHRuW-6PJ4oJzMZ
# freetype
- kind: tar
  url: https://deps.files.ghostty.org/freetype-1220b81f6ecfb3fd222f76cf9106fecfa6554ab07ec7fdc4124b9bb063ae2adf969d.tar.gz
  ref: 427201f5d5151670d05c1f5b45bef5dda1f2e7dd971ef54f0feaaa7ffd2ab90c
  directory: zig-deps/p/N-V-__8AAKLKpwC4H27Ps_0iL3bPkQb-z6ZVSrB-x_3EEkub
# gettext
- kind: tar
  url: https://deps.files.ghostty.org/gettext-0.24.tar.gz
  ref: c918503d593d70daf4844d175a13d816afacb667c06fba1ec9dcd5002c1518b7
  directory: zig-deps/p/N-V-__8AADcZkgn4cMhTUpIz6mShCKyqqB-NBtf_S2bHaTC-
# glslang
- kind: tar
  url: https://deps.files.ghostty.org/glslang-12201278a1a05c0ce0b6eb6026c65cd3e9247aa041b1c260324bf29cee559dd23ba1.tar.gz
  ref: 14a2edbb509cb3e51a9a53e3f5e435dbf5971604b4b833e63e6076e8c0a997b5
  directory: zig-deps/p/N-V-__8AABzkUgISeKGgXAzgtutgJsZc0-kkeqBBscJgMkvy
# gobject
- kind: tar
  url: https://deps.files.ghostty.org/gobject-2026-10-02-38-1.tar.zst
  ref: 400fa7fd7bb7d29ec5348e14c70785a23f96926546afc6f02f7086c66b362ba4
  directory: zig-deps/p/gobject-0.3.2-Skun7LuIogBbEh-6WrLeEzMaRCnOMB3eOf__RaPYSMCZ
# gtk4_layer_shell
- kind: tar
  url: https://deps.files.ghostty.org/gtk4-layer-shell-1.1.0.tar.gz
  ref: 98284281260a5eef5b4f63a55f16c4bf6a788a1020a6db037ecb0f71fa336988
  directory: zig-deps/p/N-V-__8AALiNBAA-_0gprYr92CjrMj1I5bqNu0TSJOnjFNSr
# harfbuzz
- kind: tar
  url: https://deps.files.ghostty.org/harfbuzz-11.0.0.tar.xz
  ref: f16351bafe214725fe2c1d5b59f0d93e49905a4b247899fb90d70cff953a2b9b
  directory: zig-deps/p/N-V-__8AAG02ugUcWec-Ndp-i7JTsJ0dgF8nnJRUInkGLG7G
# highway
- kind: tar
  url: https://deps.files.ghostty.org/highway-66486a10623fa0d72fe91260f96c892e41aceb06.tar.gz
  ref: 87d4f8893ef4e08f224973608ffebf94268a81380ba79c12e8841968c80aa212
  directory: zig-deps/p/N-V-__8AAGmZhABbsPJLfbqrh6JTHsXhY6qCaLAQyx25e0XE
# imgui
- kind: tar
  url: https://deps.files.ghostty.org/N-V-__8AAEbOfQBnvcFcCX2W5z7tDaN8vaNZGamEQtNOe0UI.tar.gz
  ref: c816c20e8c75f3e15ae867350e79925502d1a6a85938bb1a73b8927e5f31f9cb
  directory: zig-deps/p/N-V-__8AAEbOfQBnvcFcCX2W5z7tDaN8vaNZGamEQtNOe0UI
# iterm2_themes
- kind: tar
  url: https://deps.files.ghostty.org/ghostty-themes-release-20261019-151001-86a776d.tgz
  ref: ab2513e316372c45c9f86e3e511aebdbfa6c39fa03c210096b19152fe288505b
  directory: zig-deps/p/N-V-__8AAJ3vBQAq1fLMh5J8uWLkeDLS6WAdR2x5KcrmEyz6
# jetbrains_mono
- kind: tar
  url: https://deps.files.ghostty.org/JetBrainsMono-2.304.tar.gz
  ref: c57a691e8b82ad098b5963f3959032e4038f391087af7715885ba59046105cc4
  base-dir: ''
  directory: zig-deps/p/N-V-__8AAIC5lwAVPJJzxnCAahSvZTIlG-HhtOvnM1uh-66x
# libpng
- kind: tar
  url: https://deps.files.ghostty.org/libpng-1220aa013f0c83da3fb64ea6d327f9173fa008d10e28bc9349eac3463457723b1c66.tar.gz
  ref: fecc95b46cf05e8e3fc8a414750e0ba5aad00d89e9fdf175e94ff041caf1a03a
  directory: zig-deps/p/N-V-__8AAJrvXQCqAT8Mg9o_tk6m0yf5Fz-gCNEOKLyTSerD
# libxev
- kind: tar
  url: https://deps.files.ghostty.org/libxev-819ffa180ca20e31c7eded74e2e1aceb1eab557f.tar.gz
  ref: 42993af02089811fc26ea90deabbe8a60fb469059dd5947f1debf57c560c3f36
  directory: zig-deps/p/libxev-0.0.0-86vtc8QQFACz0sVc7U-VDiDIgH-XfBuEY5JpABLjHNpn
# libxml2
- kind: tar
  url: https://deps.files.ghostty.org/libxml2-2.11.5.tar.gz
  ref: 6c28059e2e3eeb42b5b4b16489e3916a6346c1095a74fee3bc65cdc5d89a6215
  directory: zig-deps/p/N-V-__8AAG3RoQEyRC2Vw7Qoro5SYBf62IHn3HjqtNVY6aWK
# nerd_fonts_symbols_only
- kind: tar
  url: https://deps.files.ghostty.org/NerdFontsSymbolsOnly-3.4.0.tar.gz
  ref: 1164d1b956d4bde248d7b2f0998c43cc94f5202431a1564a793895b1e73b0d04
  base-dir: ''
  directory: zig-deps/p/N-V-__8AAMVLTABmYkLqhZPLXnMl-KyN38R8UVYqGrxqO26s
# oniguruma
- kind: tar
  url: https://deps.files.ghostty.org/oniguruma-1220c15e72eadd0d9085a8af134904d9a0f5dfcbed5f606ad60edc60ebeccd9706bb.tar.gz
  ref: 001aa1202e78448f4c0bf1a48c76e556876b36f16d92ce3207eccfd61d99f2a0
  directory: zig-deps/p/N-V-__8AAHjwMQDBXnLq3Q2QhaivE0kE2aD138vtX2Bq1g7c
# pixels
- kind: tar
  url: https://deps.files.ghostty.org/pixels-12207ff340169c7d40c570b4b6a97db614fe47e0d83b5801a932dcd44917424c8806.tar.gz
  ref: 55e83b16d091082502bf149bf457f31f42092c5982650e3ffbae7b48871bf11a
  directory: zig-deps/p/N-V-__8AADYiAAB_80AWnH1AxXC0tql9thT-R-DYO1gBqTLc
# plasma_wayland_protocols
- kind: tar
  url: https://deps.files.ghostty.org/plasma_wayland_protocols-12207e0851c12acdeee0991e893e0132fc87bb763969a585dc16ecca33e88334c566.tar.gz
  ref: 5c58ba214acd8e6bca3426dc08b022c46a8dd997b29a1b3e28badf71c20df441
  directory: zig-deps/p/N-V-__8AAKYZBAB-CFHBKs3u4JkeiT4BMvyHu3Y5aaWF3Bbs
# sentry
- kind: tar
  url: https://deps.files.ghostty.org/sentry-1220446be831adcca918167647c06c7b825849fa3fba5f22da394667974537a9c77e.tar.gz
  ref: 2ac6497cc8d61a8d31093e47addb8c9b2c45b16b0705bb334a835b6423c318df
  directory: zig-deps/p/N-V-__8AAPlZGwBEa-gxrcypGBZ2R8Bse4JYSfo_ul8i2jlG
# spirv_cross
- kind: tar
  url: https://deps.files.ghostty.org/spirv_cross-1220fb3b5586e8be67bc3feb34cbe749cf42a60d628d2953632c2f8141302748c8da.tar.gz
  ref: b52b6fcfc45e7fa69b1f06a1362c155473444e2cc09995556b156c53ba6657e3
  directory: zig-deps/p/N-V-__8AANb6pwD7O1WG6L5nvD_rNMvnSc9Cpg1ijSlTYywv
# translate_c
- kind: tar
  url: https://deps.files.ghostty.org/translate_c-02ff0c523fb92a38939b04d0145c4a9602a74d56.tar.gz
  ref: e344433bcce14759529e58ea600e67d7c39846b1775b122f88db7cb4dad58591
  directory: zig-deps/p/translate_c-2.0.0-Q_BUWltOBwBYABF84EUL208pIFeUIwbBs29FmVBaafN5
# uucode
- kind: tar
  url: https://deps.files.ghostty.org/uucode-ea62149739404a73c202b48a33bf6dd2af4bd9b0.tar.gz
  ref: f37c4071a217853450d084cb9c12b6d4b68f887eb9cb42fe77a84f86056eacbf
  directory: zig-deps/p/uucode-0.2.0-ZZjBPoGFVgCiflJNFc6Io8xzC67B6PA5bUkk4LT0kCxg
# vaxis
- kind: tar
  url: https://deps.files.ghostty.org/vaxis-6fd944a27fb3d6f596e981076381a3131f2448b4.tar.gz
  ref: 39d50c983da3dc952c9449c5ef7aadd49142758376ab09149d6212a49c37e16a
  directory: zig-deps/p/vaxis-0.6.0-BWNV_MafDAAEzkVUvrW9NFUqnnMUoeHqrs2mecnD6D7w
# wayland
- kind: tar
  url: https://deps.files.ghostty.org/wayland-9cb3d7aa9dc995ffafdbdef7ab86a949d0fb0e7d.tar.gz
  ref: ea4191d68e437677e51f3aacde27829810144e931d397a327dc6035e2c39c50d
  directory: zig-deps/p/N-V-__8AAKrHGAAs2shYq8UkE6bGcR1QJtLTyOE_lcosMn6t
# wayland_protocols
- kind: tar
  url: https://deps.files.ghostty.org/N-V-__8AAFdWDwA0ktbNUi9pFBHCRN4weXIgIfCrVjfGxqgA.tar.gz
  ref: dd2df14ab5f41038257aaedcc4b5fb9ac0ee018f3f0f94af9097028e60d33223
  directory: zig-deps/p/N-V-__8AAFdWDwA0ktbNUi9pFBHCRN4weXIgIfCrVjfGxqgA
# wayland_protocols
- kind: tar
  url: https://deps.files.ghostty.org/wayland-protocols-258d8f88f2c8c25a830c6316f87d23ce1a0f12d9.tar.gz
  ref: 5cedcadde81b75e60f23e5e83b5dd2b8eb4efb9f8f79bd7a347d148aeb0530f8
  directory: zig-deps/p/N-V-__8AAKw-DAAaV8bOAAGqA0-oD7o-HNIlPFYKRXSPT03S
# wuffs
- kind: tar
  url: https://deps.files.ghostty.org/wuffs-7411f488fe2e2c205c3d3b3d28638b7356522930.tar.gz
  ref: 17877d346f7988651d6c62e45b2e3b05c86809a6442c5e34612374b2a9719a1c
  directory: zig-deps/p/N-V-__8AAP5JWgCGP_AD0teWpa4krRvE9VPZzvviGdbmN4jI
# z2d
- kind: tar
  url: https://deps.files.ghostty.org/z2d-40af3e84a4e15a9f31d126b3f281f23ce6a3dae5.tar.gz
  ref: fdaca4e2789bb8b781eef2cc76eab5ef3490d8cceec699e40d1cc96b53ad3f74
  directory: zig-deps/p/z2d-0.13.0-j5P_HgsRFABzZDH54gI35P0OSrg7HFyJwS2bXX5uBdU4
# zf
- kind: tar
  url: https://deps.files.ghostty.org/zf-87153bb86b75d21fbac897b738f316d449f5d0c9.tar.gz
  ref: 56174bcd35fbeab7fd5501bdfa7175fd0474c88d733a6455050977075b8da50a
  directory: zig-deps/p/zf-0.11.0-OIRy8XCRAAB6FiMwIrtD6FqlagnFwpI6YyOu7bXeYH5J
# zig_js
- kind: tar
  url: https://deps.files.ghostty.org/zig_js-3c23860e47fdcdc5af805efb7fd0bdac5fd3e9bc.tar.gz
  ref: a2ff488a244301f4e59469a5232aad6869b01acc50f7d7ed2647c029a57d4b3b
  directory: zig-deps/p/zig_js-0.0.0-rjCAV7-GAADvMTBL7lPMuvDk7xgS9PCMIZWiOUXLZSlj
# zig_objc
- kind: tar
  url: https://deps.files.ghostty.org/zig_objc-3352c12a868f8787ab71bf2ca6eab9fcfb635c52.tar.gz
  ref: 5a27d67c016031c51b260744909cceedad9f307d2f93569cb1c81ac91b45f178
  directory: zig-deps/p/zig_objc-0.0.0-Ir_Sp_4tAQDXtPi51nW_jD9LOEzBvU9lofwO9Pzi6IB4
# zig_wayland
- kind: tar
  url: https://deps.files.ghostty.org/zig_wayland-27dda01712ddf3cb46ebd93380d88b01a7c828f8.tar.gz
  ref: c7d268d7c0dcecfeb209d0ccf2b04364d1541722c5e53e4c5bbd3eaa481847a4
  directory: zig-deps/p/wayland-0.7.0-dev-lQa1klz9AQB87V0pMKMdm8JvyOx32XR9FxcWnw9wh6XZ
# zigimg
- kind: tar
  url: github:sergot/zigimg/archive/c701c9f99779d7ddf594dcc6da8f858fd277d61f.tar.gz
  ref: c716c6f262e03291b3801bfd399aec70f3c65069d4ca462ba7362273f88fea66
  directory: zig-deps/p/zigimg-0.1.0-8_eo2ri_FwBqF5UYiggLz4IGjHJO_n9-B6gT9Ayqg8G4
# zlib
- kind: tar
  url: https://deps.files.ghostty.org/zlib-1220fed0c74e1019b3ee29edae2051788b080cd96e90d56836eea857b0b966742efb.tar.gz
  ref: 17e88863f3600672ab49182f217281b6fc4d3c762bde361935e436a95214d05c
  directory: zig-deps/p/N-V-__8AAB0eQwD-0MdOEBmz7intriBReIsIDNlukNVoNu6o
