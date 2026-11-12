kind: manual
description: |
  Hudhud's Shields engine (docs/browser.md, "Shields"): Brave's
  adblock-rust behind a small C interface (files/hudhud/shields),
  and the filter lists compiled into one engine file the browser loads at
  start.

  The lists, pinned like any other source and refreshed with each browser
  release: EasyList and EasyPrivacy (from uBlock Origin's uAssets, which
  carries them), uBlock Origin's filters, privacy, unbreak and quick-fix
  lists, and Liste AR for Arabic sites.

  Installs /usr/lib/hudhud/libhudhud_shields.so and shields.dat.
  (base/chromium.bst takes the interface's header from the source, not
  from here: see docs/browser.md, "The elements".)

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst
- bootstrap/rust.bst

variables:
  browser-dir: "%{prefix}/lib/hudhud"

config:
  build-commands:
  # crates come from the cargo2 source below, never the network
  - cargo build --release --locked --offline

  - |
    # The lists, in the order Brave and uBlock Origin apply them; the
    # unbreak and quick-fix lists hold the exceptions that keep sites
    # working.
    ua=lists/uAssets
    ./target/release/hudhud-shields-compile shields.dat \
      $ua/thirdparties/easylist/easylist.txt \
      $ua/thirdparties/easylist/easyprivacy.txt \
      $ua/filters/filters.txt \
      $ua/filters/privacy.txt \
      $ua/filters/unbreak.txt \
      $ua/filters/quick-fixes.txt \
      lists/listear/Liste_AR.txt

  install-commands:
  - |
    mkdir -p %{install-root}%{browser-dir}
    cp target/release/libhudhud_shields.so shields.dat %{install-root}%{browser-dir}/
    ls -l %{install-root}%{browser-dir}

sources:
- kind: local
  path: files/hudhud/shields
- kind: tar
  url: github:uBlockOrigin/uAssets/archive/bdf05d40f0a7f0d20bace4a6c00c91ef78095068.tar.gz
  ref: b10f77064c15450d92dbd83dd9dfc36e239f5dfe125c8374f1e9dc794ab64d96
  directory: lists/uAssets
- kind: tar
  url: github:easylist/listear/archive/47b1abc67b49865ea9b91d480e6b82fb7fb54883.tar.gz
  ref: 60e509f39357265c5712b7c71798db8dc796e35333bf9b851194d68fc1b597cf
  directory: lists/listear
- kind: cargo2
  url: "crates:"
  ref:
  - kind: registry
    name: adblock
    version: 0.13.5
    sha: 7a4c8558f27608dec74695c866f9a8ef897ec7a77cb826f8a5baf0b8ba461d2a
  - kind: registry
    name: addr
    version: 0.15.6
    sha: a93b8a41dbe230ad5087cc721f8d41611de654542180586b315d9f4cf6b72bef
  - kind: registry
    name: aho-corasick
    version: 1.1.5
    sha: c982642fa9e8606056828ee9a8505737230110bb1099153c79efe865c59d12ba
  - kind: registry
    name: arrayvec
    version: 0.7.8
    sha: d3fb67a6e08acf24fdeccbac2cb6ac4305825bd1f117462e0e6f2f193345ad56
  - kind: registry
    name: base64
    version: 0.22.1
    sha: 72b3254f16251a8381aa12e40e3c4d2f0199f8c6508fbecb9d91f575e0fbb8c6
  - kind: registry
    name: bitflags
    version: 2.13.2
    sha: 3ded4057c258ba199e2d26386d3af3780957ecaee6c4ef4041c6b4b8b97c0b06
  - kind: registry
    name: displaydoc
    version: 0.2.7
    sha: c6232dd377dcc64799954cbd3a9bb882e9cdc1308ccd87b1c098f1fb2eaf82a8
  - kind: registry
    name: either
    version: 1.19.0
    sha: 0e9c71c2167ca323c882b99918929403426e2373ea17242ff5653e0d5e1058be
  - kind: registry
    name: flatbuffers
    version: 25.12.19
    sha: 35f6839d7b3b98adde531effaf34f0c2badc6f4735d26fe74709d8e513a96ef3
  - kind: registry
    name: icu_collections
    version: 2.4.0
    sha: fe090a42a0d3140fed8c63263ed1fecc02422cb2f4bfe55cd8de2de1b8e105dd
  - kind: registry
    name: icu_locale_core
    version: 2.4.0
    sha: 25d29b57c17c6528d0dc4c2141cfa2d08200465acb537a3909c8b9b8a4a984c0
  - kind: registry
    name: icu_normalizer
    version: 2.4.0
    sha: 404a3b8c486f205c87fe7f23ab6894d84a4ad76d6e4671ae1981ba7def87c599
  - kind: registry
    name: icu_normalizer_data
    version: 2.4.0
    sha: 20f0088bfb7441f7a37fa0c9e20cb1e9cba1cac6b9ce8cd2a6dc44294f8e8cbc
  - kind: registry
    name: icu_properties
    version: 2.4.0
    sha: 2ea83d991c56158f7cf898bf86436c1dfe7c07ee82fe88951f2695c9f37a379f
  - kind: registry
    name: icu_properties_data
    version: 2.4.0
    sha: b98f29af82d02b163fe50161388350e743bb3107cc8e8c2f7314cb505faddfcf
  - kind: registry
    name: icu_provider
    version: 2.4.0
    sha: 413099315636c588ee8f011190b329b971a09a8fae9d157e01dcae8379468514
  - kind: registry
    name: idna
    version: 1.1.0
    sha: 3b0875f23caa03898994f6ddc501886a45c7d3d62d04d2d90788d47be1b1e4de
  - kind: registry
    name: idna_adapter
    version: 1.2.2
    sha: cb68373c0d6620ef8105e855e7745e18b0d00d3bdb07fb532e434244cdb9a714
  - kind: registry
    name: itertools
    version: 0.14.0
    sha: 2b192c782037fadd9cfa75548310488aabdbf3d2da73885b31bd0abd03351285
  - kind: registry
    name: itoa
    version: 1.0.18
    sha: 8f42a60cbdf9a97f5d2305f08a87dc4e09308d1276d28c869c684d7777685682
  - kind: registry
    name: litemap
    version: 0.8.3
    sha: 47d9d19d1d6efa0109d2f65ff4c85cddd50bd572e5a00127ab10987290bcefae
  - kind: registry
    name: memchr
    version: 2.8.3
    sha: cf8baf1c55e62ffcace7a9f06f4bd9cd3f0c4beb022d3b367256b91b87513d98
  - kind: registry
    name: percent-encoding
    version: 2.3.2
    sha: 9b4f627cb1b25917193a259e49bdad08f671f8d9708acfd5fe0a8c1455d87220
  - kind: registry
    name: potential_utf
    version: 0.1.6
    sha: d83eb9bc6d8e5cf568e7a1101d60ee05e81ed50ea106026f3d18deeb046d7661
  - kind: registry
    name: proc-macro2
    version: 1.0.107
    sha: 985e7ec9bb745e6ce6535b544d84d6cd6f7ad8bd711c398938ae983b91a766d9
  - kind: registry
    name: psl
    version: 2.1.247
    sha: bcf03dc0cd8c65e109a7848e3b4adf06236a181d937af94bff66966e3876b1aa
  - kind: registry
    name: psl-types
    version: 2.0.11
    sha: 33cb294fe86a74cbcf50d4445b37da762029549ebeea341421c7c70370f86cac
  - kind: registry
    name: quote
    version: 1.0.47
    sha: 1fbf4db142a473a8d80c26bbf18454ed458bf8d26c8219c331daecfdbd079001
  - kind: registry
    name: regex
    version: 1.13.1
    sha: f020237b6c8eed93db2e2cb53c00c60a8e1bc73da7d073199a1180401450218d
  - kind: registry
    name: regex-automata
    version: 0.4.18
    sha: ad8553b9b26413251cbf30e620595c7a41b3887f03da04579c0e6b0d6a06b4b2
  - kind: registry
    name: regex-syntax
    version: 0.8.11
    sha: d6f6ff9a378485b298a5286656da665ba74413d36db0979633275d2e708145d4
  - kind: registry
    name: rustc-hash
    version: 2.1.3
    sha: 6b1e7f9a428571be2dc5bc0505c13fb6bf936822b894ec87abf8a08a4e51742d
  - kind: registry
    name: rustc_version
    version: 0.4.1
    sha: cfcb3a22ef46e85b45de6ee7e79d063319ebb6594faafcf1c225ea92ab6e9b92
  - kind: registry
    name: seahash
    version: 4.1.0
    sha: 1c107b6f4780854c8b126e228ea8869f4d7b71260f962fefb57b996b8959ba6b
  - kind: registry
    name: semver
    version: 1.0.28
    sha: 8a7852d02fc848982e0c167ef163aaff9cd91dc640ba85e263cb1ce46fae51cd
  - kind: registry
    name: serde
    version: 1.0.229
    sha: 4148590afebada386688f18773da617792bf2ef03ffc1e4cbd2b1d45b023e0ba
  - kind: registry
    name: serde_core
    version: 1.0.229
    sha: 67dca2c9c51e58a4791a4b1ed58308b39c64224d349a935ab5039aa360942a48
  - kind: registry
    name: serde_derive
    version: 1.0.229
    sha: e7a5d71263a5a7d47b41f6b3f06ba276f10cc18b0931f1799f710578e2309348
  - kind: registry
    name: serde_json
    version: 1.0.154
    sha: e7e9cc8b1b85264074fbcc02a88680c4096b1e47df8f739dceb03bf482f04bd6
  - kind: registry
    name: smallvec
    version: 1.16.4
    sha: d0d5d4b1981b8bbbb7aed204cae5726d683d5d6ac7e74ec54122ea28f315e7c8
  - kind: registry
    name: stable_deref_trait
    version: 1.2.1
    sha: 6ce2be8dc25455e1f91df71bfa12ad37d7af1092ae736f3a6cd0e37bc7810596
  - kind: registry
    name: syn
    version: 2.0.119
    sha: 872831b642d1a07999a962a351ed35b955ea2cfc8f3862091e2a240a84f17297
  - kind: registry
    name: syn
    version: 3.0.9
    sha: d78c8dee4c7bf0e14673097256fed6142ce9d3b85a408189d07482442145823b
  - kind: registry
    name: synstructure
    version: 0.14.0
    sha: 901704edd0dfe137f1987838ee4f259e4e063c31371bdb423f7ae38ec6f77f02
  - kind: registry
    name: thiserror
    version: 1.0.69
    sha: b6aaf5339b578ea85b50e080feb250a3e8ae8cfcdff9a461c9ec2904bc923f52
  - kind: registry
    name: thiserror-impl
    version: 1.0.69
    sha: 4fee6c4efc90059e10f81e6d42c60a18f76588c3d74cb83a0b242a2b6c7504c1
  - kind: registry
    name: tinystr
    version: 0.8.5
    sha: abc840c238154d58f9e86b2792261edfde565a17696e1cda1a449de27979801a
  - kind: registry
    name: unicode-ident
    version: 1.0.27
    sha: a2c754d6c33795a1c324727428e5a7dedb5b06195f9890bdbcba760d3e246563
  - kind: registry
    name: utf8_iter
    version: 1.1.0
    sha: af3bd9d3e571c26fcce9d033b87ea5ab061b8d2ffe9b7a5675d810d68f03edf0
  - kind: registry
    name: utf_types
    version: 1.0.0
    sha: 3a3b425286980a367278453f3b6d28cdcb134b574e5a35824a6ff5eebad50bb6
  - kind: registry
    name: writeable
    version: 0.6.4
    sha: 3ad82d2a33cdc9674dc7465672f271e096168fcdbe0f799d9e6db8c5892679dc
  - kind: registry
    name: yoke
    version: 0.8.4
    sha: 417ef3fcf6c300b7dbd25c85531a746931c02ad536f3cf4786ed1e88223340b3
  - kind: registry
    name: yoke-derive
    version: 0.8.4
    sha: ec8ebde2db3681e8c9980cc27822030e68752690ddfa9473e739aeb4dbde6d71
  - kind: registry
    name: zerofrom
    version: 0.1.8
    sha: 0ec05a11813ea801ff6d75110ad09cd0824ddba17dfe17128ea0d5f68e6c5272
  - kind: registry
    name: zerofrom-derive
    version: 0.1.8
    sha: f75b4683f6c7f45248d4d64056a24298c6281e0993356d7d1b4a1a962ef10d4a
  - kind: registry
    name: zerotrie
    version: 0.2.5
    sha: 4ea269c3bd32f0a32c321907a2ae912ba6f4649bb0fc764a15627e99a7095a3f
  - kind: registry
    name: zerovec
    version: 0.11.9
    sha: f58a2799cfe9a1670c7ea8edbd52ef8edb93cb37a7f83bf31ba9e35d9dae6a40
  - kind: registry
    name: zerovec-derive
    version: 0.11.7
    sha: c3743ddbf47738d929cd1ae2e199d40d0162979dfe31aef8ae646d2bf00bf97a
  - kind: registry
    name: zmij
    version: 1.0.23
    sha: 29666d0abbfad1e3dc4dcf6144730dd3a3ab225bbbdac83319345b1b44ccfc1b
