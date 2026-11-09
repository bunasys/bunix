kind: manual
description: |
  dms -- DMS (Dux Modular Shell), the desktop shell: bar, launcher,
  notifications, control centre, lock screen (https://duxlabs.dev/docs/dms).
  One Go program, its Quickshell UI (QML) embedded in it (-tags withshell);
  it runs that UI with Quickshell's `qs`.  Pure Go, no cgo.

  Built offline from the release tarball, its dux-qml-common widget library
  (a git submodule, so not in the tarball: the commit the tag pins), and
  the Go modules it needs as a file module proxy (tools/go-modules.py
  prints those sources; Go also checks them against go.sum).  Not the
  go_module source plugin: it clones each module's git repository and
  vendors it, where the proxy's files are what go.sum describes.

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst
- desktop/go-1.27.bst

# Runs its embedded UI with Quickshell's qs
depends:
- desktop/quickshell.bst

sources:
- kind: tar
  url: github:duxlabs-dev/dux-shell/archive/refs/tags/v2.1.2.tar.gz
  ref: 4990fcd6c359b63b8ce32d97c8b09e3dddb0f71096abec6f1a535445b0039a7f
- kind: tar
  url: github:duxlabs-dev/dux-qml-common/archive/0877466a25b8e191a865bf75d0e500de6351ae04.tar.gz
  directory: dux-qml-common
  ref: fb33a74d647978e40846475205e5b1fec89ab4cdfa6a4c6da662f98e5c5c9f7b
# tools/go-modules.py <dux-shell v2.1.2>/core ./cmd/dms withshell (Go 1.27)
- kind: remote
  url: goproxy:filippo.io/edwards25519/@v/v1.2.0.mod
  directory: goproxy/filippo.io/edwards25519/@v
  filename: v1.2.0.mod
  ref: 7492c767dc361b86e96933ca1790d492c2f7c368c3ec0e00e1050eddad7baa7d
- kind: remote
  url: goproxy:filippo.io/edwards25519/@v/v1.2.0.zip
  directory: goproxy/filippo.io/edwards25519/@v
  filename: v1.2.0.zip
  ref: 98f2d3ca9b88daa031b0fb2fb521b7ea386af1fed61b6f445a20bef7fa381c17
- kind: remote
  url: goproxy:github.com/!proton!mail/go-crypto/@v/v1.5.2.mod
  directory: goproxy/github.com/!proton!mail/go-crypto/@v
  filename: v1.5.2.mod
  ref: ed1f85c71a923884ce7d473567633be6029daa68cc80f277ff15278756943635
- kind: remote
  url: goproxy:github.com/!proton!mail/go-crypto/@v/v1.5.2.zip
  directory: goproxy/github.com/!proton!mail/go-crypto/@v
  filename: v1.5.2.zip
  ref: 6ce5df4da97350b69637df5918fa1431816180ca1ab3a9850b3f69c14575a7e8
- kind: remote
  url: goproxy:github.com/!wifx/gonetworkmanager/v2/@v/v2.2.0.mod
  directory: goproxy/github.com/!wifx/gonetworkmanager/v2/@v
  filename: v2.2.0.mod
  ref: abc3cacae5e9d20bee340ff3f8a52cc3f6e24bf9b5df4aab9b7ff5549a9f6823
- kind: remote
  url: goproxy:github.com/!wifx/gonetworkmanager/v2/@v/v2.2.0.zip
  directory: goproxy/github.com/!wifx/gonetworkmanager/v2/@v
  filename: v2.2.0.zip
  ref: 18ade00b4f176832df17d82c4877c7ddd415631f2e5622a83fd82efc98e30693
- kind: remote
  url: goproxy:github.com/alecthomas/chroma/v2/@v/v2.27.0.mod
  directory: goproxy/github.com/alecthomas/chroma/v2/@v
  filename: v2.27.0.mod
  ref: eeaef52bd74315d588d6799990ba08cc209a70e748473c3a4333349944871a10
- kind: remote
  url: goproxy:github.com/alecthomas/chroma/v2/@v/v2.27.0.zip
  directory: goproxy/github.com/alecthomas/chroma/v2/@v
  filename: v2.27.0.zip
  ref: 8eb074aaf4a7b4cf406e81062cf5d6b54c32797be53f5287d88ef570fa73625f
- kind: remote
  url: goproxy:github.com/atotto/clipboard/@v/v0.1.4.mod
  directory: goproxy/github.com/atotto/clipboard/@v
  filename: v0.1.4.mod
  ref: 871822cbc7df3792f78a100886b7f499f73555938e336b918682119688ea8ad0
- kind: remote
  url: goproxy:github.com/atotto/clipboard/@v/v0.1.4.zip
  directory: goproxy/github.com/atotto/clipboard/@v
  filename: v0.1.4.zip
  ref: d67b2c36c662751309fd2ec351df3651584bea840bd27be9a90702c3a238b43f
- kind: remote
  url: goproxy:github.com/aymanbagabas/go-osc52/v2/@v/v2.0.1.mod
  directory: goproxy/github.com/aymanbagabas/go-osc52/v2/@v
  filename: v2.0.1.mod
  ref: 4646f9f19a822aebf4296bce24d5f2b7b2700ea1c44f5cc978300263cb7b5611
- kind: remote
  url: goproxy:github.com/aymanbagabas/go-osc52/v2/@v/v2.0.1.zip
  directory: goproxy/github.com/aymanbagabas/go-osc52/v2/@v
  filename: v2.0.1.zip
  ref: 939ebf2a5481f2172e1a5e0c318d05aef5b6d950a960556216c3da7879a927f8
- kind: remote
  url: goproxy:github.com/charmbracelet/bubbles/@v/v1.0.0.mod
  directory: goproxy/github.com/charmbracelet/bubbles/@v
  filename: v1.0.0.mod
  ref: a324490b2998811be8fa0a3cbb7fac4d65e3c18e75942ca0ce9a86f07e16b031
- kind: remote
  url: goproxy:github.com/charmbracelet/bubbles/@v/v1.0.0.zip
  directory: goproxy/github.com/charmbracelet/bubbles/@v
  filename: v1.0.0.zip
  ref: b245dafe1f179d4f0ce17b950ce12ac884ab0c7f69fd2d2f282be68e373d5468
- kind: remote
  url: goproxy:github.com/charmbracelet/bubbletea/@v/v1.3.10.mod
  directory: goproxy/github.com/charmbracelet/bubbletea/@v
  filename: v1.3.10.mod
  ref: 903f2904b09b37dd74092f437ad306794e7633329ddc5af7b201d469e2d937fb
- kind: remote
  url: goproxy:github.com/charmbracelet/bubbletea/@v/v1.3.10.zip
  directory: goproxy/github.com/charmbracelet/bubbletea/@v
  filename: v1.3.10.zip
  ref: 8afc524c11d18878b0ac3426fd3318fdf05ad576e65883c597996296c1b27117
- kind: remote
  url: goproxy:github.com/charmbracelet/colorprofile/@v/v0.4.3.mod
  directory: goproxy/github.com/charmbracelet/colorprofile/@v
  filename: v0.4.3.mod
  ref: 4da50dc5179ea48dc7c55db78f05b4911047341ef749027b3969130edf1fd43b
- kind: remote
  url: goproxy:github.com/charmbracelet/colorprofile/@v/v0.4.3.zip
  directory: goproxy/github.com/charmbracelet/colorprofile/@v
  filename: v0.4.3.zip
  ref: 656472ff48f01a098418a31667f3253cf34e04d4e1cb6c1a0a80f76ad370b689
- kind: remote
  url: goproxy:github.com/charmbracelet/lipgloss/@v/v1.1.0.mod
  directory: goproxy/github.com/charmbracelet/lipgloss/@v
  filename: v1.1.0.mod
  ref: 97aa7725695c07aa23c191e2b9d2d3931f367b8a6923ce4a60d969c026138672
- kind: remote
  url: goproxy:github.com/charmbracelet/lipgloss/@v/v1.1.0.zip
  directory: goproxy/github.com/charmbracelet/lipgloss/@v
  filename: v1.1.0.zip
  ref: 22512fd8c211302255bb6f57d8018eed9b8d8f6dd51310512901240bde9b061a
- kind: remote
  url: goproxy:github.com/charmbracelet/log/@v/v1.0.0.mod
  directory: goproxy/github.com/charmbracelet/log/@v
  filename: v1.0.0.mod
  ref: 1514c72ec9685561cae28226d96588c1b88d1c764e3885c5f35e77db4daff7b6
- kind: remote
  url: goproxy:github.com/charmbracelet/log/@v/v1.0.0.zip
  directory: goproxy/github.com/charmbracelet/log/@v
  filename: v1.0.0.zip
  ref: 564622bb814b4c9fc5e18b677d0f3af6b0f532ef0ae862d4c3f0500564c6160a
- kind: remote
  url: goproxy:github.com/charmbracelet/x/ansi/@v/v0.11.9.mod
  directory: goproxy/github.com/charmbracelet/x/ansi/@v
  filename: v0.11.9.mod
  ref: 37eb859ba45ddd27690bfa8d617e8744c37b090e121c03a3b8c8d72b1a3437f5
- kind: remote
  url: goproxy:github.com/charmbracelet/x/ansi/@v/v0.11.9.zip
  directory: goproxy/github.com/charmbracelet/x/ansi/@v
  filename: v0.11.9.zip
  ref: 9815535699efc21636755cc84dbc92250182246e876e4ea83e87464d871cbf82
- kind: remote
  url: goproxy:github.com/charmbracelet/x/cellbuf/@v/v0.0.15.mod
  directory: goproxy/github.com/charmbracelet/x/cellbuf/@v
  filename: v0.0.15.mod
  ref: 5867c27bb93af066945f3c7b5487f721c1f6dc05a382a9e83af0de7ee9ac00f2
- kind: remote
  url: goproxy:github.com/charmbracelet/x/cellbuf/@v/v0.0.15.zip
  directory: goproxy/github.com/charmbracelet/x/cellbuf/@v
  filename: v0.0.15.zip
  ref: 2c5c421edef869c7f4b7b3fa29530a66897134764d95a750eed59ed5886d84f7
- kind: remote
  url: goproxy:github.com/charmbracelet/x/term/@v/v0.2.2.mod
  directory: goproxy/github.com/charmbracelet/x/term/@v
  filename: v0.2.2.mod
  ref: 6df18166815b45f523a79580acfa95f12990a1568e6325f9d60b5825df952962
- kind: remote
  url: goproxy:github.com/charmbracelet/x/term/@v/v0.2.2.zip
  directory: goproxy/github.com/charmbracelet/x/term/@v
  filename: v0.2.2.zip
  ref: 0452a430f7e6882393f81ba19a70a63709960acb9743e1199a7b04d908e6b506
- kind: remote
  url: goproxy:github.com/clipperhouse/displaywidth/@v/v0.11.0.mod
  directory: goproxy/github.com/clipperhouse/displaywidth/@v
  filename: v0.11.0.mod
  ref: 643bf909351d7bc8ff29a8a7bb44cca11efe181ed66e5efe57d695bb023effb3
- kind: remote
  url: goproxy:github.com/clipperhouse/displaywidth/@v/v0.11.0.zip
  directory: goproxy/github.com/clipperhouse/displaywidth/@v
  filename: v0.11.0.zip
  ref: 27830c91cdfb2a648748db21f7a2734dcb50d21c620edde51d488ba4e7967e3d
- kind: remote
  url: goproxy:github.com/clipperhouse/uax29/v2/@v/v2.7.0.mod
  directory: goproxy/github.com/clipperhouse/uax29/v2/@v
  filename: v2.7.0.mod
  ref: f3c5f4e4f9e7fb16aea5fd9dc5f24c3ff9c157b1a67576c0f2140117589507a0
- kind: remote
  url: goproxy:github.com/clipperhouse/uax29/v2/@v/v2.7.0.zip
  directory: goproxy/github.com/clipperhouse/uax29/v2/@v
  filename: v2.7.0.zip
  ref: 67b1278f1ffb4e4d783a390e48fe7396864650138e785d4b4bfca5914333f761
- kind: remote
  url: goproxy:github.com/cloudflare/circl/@v/v1.6.5.mod
  directory: goproxy/github.com/cloudflare/circl/@v
  filename: v1.6.5.mod
  ref: 79b9daccc7f033377bcbc70524418d999a1677849924d7b5e488e646c4cf00d7
- kind: remote
  url: goproxy:github.com/cloudflare/circl/@v/v1.6.5.zip
  directory: goproxy/github.com/cloudflare/circl/@v
  filename: v1.6.5.zip
  ref: aa6391f45b543ee70c2d57e137c426e318fb98be81f61aa07ab5663fcf667708
- kind: remote
  url: goproxy:github.com/coder/websocket/@v/v1.8.15.mod
  directory: goproxy/github.com/coder/websocket/@v
  filename: v1.8.15.mod
  ref: 0cab443e389cef98e63828bd7ce82224bf192732a18795581314766eb14ea275
- kind: remote
  url: goproxy:github.com/coder/websocket/@v/v1.8.15.zip
  directory: goproxy/github.com/coder/websocket/@v
  filename: v1.8.15.zip
  ref: 4f1d890bc5131f335737bbb6241e3958758c8774b3e6d1c905f713f604af6209
- kind: remote
  url: goproxy:github.com/danielgtaylor/huma/v2/@v/v2.39.1.mod
  directory: goproxy/github.com/danielgtaylor/huma/v2/@v
  filename: v2.39.1.mod
  ref: e1f1e8cc76532f71155a749473e9b2089bc4d82e566137952750c45f5ea82755
- kind: remote
  url: goproxy:github.com/danielgtaylor/huma/v2/@v/v2.39.1.zip
  directory: goproxy/github.com/danielgtaylor/huma/v2/@v
  filename: v2.39.1.zip
  ref: 1a1d36528096e0660312ae467f803ac623087e9a9236a23b957f904b6f9fb301
- kind: remote
  url: goproxy:github.com/dlclark/regexp2/v2/@v/v2.9.1.mod
  directory: goproxy/github.com/dlclark/regexp2/v2/@v
  filename: v2.9.1.mod
  ref: 369b6fa60dfc57254cc1baee2becffe594ec1b4ec4f63f46a3c714fb1e2eb107
- kind: remote
  url: goproxy:github.com/dlclark/regexp2/v2/@v/v2.9.1.zip
  directory: goproxy/github.com/dlclark/regexp2/v2/@v
  filename: v2.9.1.zip
  ref: a2d0cc692915eb3a0558fe4afae2596d8d86497ad95d59f589f4d57306dbb76d
- kind: remote
  url: goproxy:github.com/duxlabs-dev/dux-go/@v/v1.6.3-0.20261104145443-699311effba8.mod
  directory: goproxy/github.com/duxlabs-dev/dux-go/@v
  filename: v1.6.3-0.20261104145443-699311effba8.mod
  ref: 9b3d0a550be7d0a1320e716b3308fc6afab708b0956a1c8f2933c1c1900ccfc5
- kind: remote
  url: goproxy:github.com/duxlabs-dev/dux-go/@v/v1.6.3-0.20261104145443-699311effba8.zip
  directory: goproxy/github.com/duxlabs-dev/dux-go/@v
  filename: v1.6.3-0.20261104145443-699311effba8.zip
  ref: 6086ae08cd5bf5da301d8964663c3c9f6405a45e7ade681ccbfb3cd0bb00f873
- kind: remote
  url: goproxy:github.com/duxlabs-dev/dux-gop/@v/v1.6.3-0.20261104203851-b2331e7fc9b7.mod
  directory: goproxy/github.com/duxlabs-dev/dux-gop/@v
  filename: v1.6.3-0.20261104203851-b2331e7fc9b7.mod
  ref: c16f8fbb1313131d8969faa9335e68217d8780884b1b9ad39c7e5295c0a1dace
- kind: remote
  url: goproxy:github.com/duxlabs-dev/dux-gop/@v/v1.6.3-0.20261104203851-b2331e7fc9b7.zip
  directory: goproxy/github.com/duxlabs-dev/dux-gop/@v
  filename: v1.6.3-0.20261104203851-b2331e7fc9b7.zip
  ref: 71f0b6807e8dc03fab965920c4ef493c89b70f4697f0e626bf807606dc205d0f
- kind: remote
  url: goproxy:github.com/emirpasic/gods/@v/v1.18.1.mod
  directory: goproxy/github.com/emirpasic/gods/@v
  filename: v1.18.1.mod
  ref: 0e157c7ef1975139b752696ba9058a5e96f51fc828e1e72a0942b1900652ce8e
- kind: remote
  url: goproxy:github.com/emirpasic/gods/@v/v1.18.1.zip
  directory: goproxy/github.com/emirpasic/gods/@v
  filename: v1.18.1.zip
  ref: 1d75e291ac15cf9ca2fcd8bd24e2f7203abad319cd3622cd1b19db5c4fb9daa5
- kind: remote
  url: goproxy:github.com/fogleman/gg/@v/v1.3.0.mod
  directory: goproxy/github.com/fogleman/gg/@v
  filename: v1.3.0.mod
  ref: 4bad40c896fc9d7d557ba4f711d8c3b7312a6c9ad57ff5bf1116a70d427b68dd
- kind: remote
  url: goproxy:github.com/fogleman/gg/@v/v1.3.0.zip
  directory: goproxy/github.com/fogleman/gg/@v
  filename: v1.3.0.zip
  ref: 792f7a3ea9eea31b7947dabaf9d5a307389245069078e4bf435d76cb0505439c
- kind: remote
  url: goproxy:github.com/fsnotify/fsnotify/@v/v1.10.1.mod
  directory: goproxy/github.com/fsnotify/fsnotify/@v
  filename: v1.10.1.mod
  ref: 7f66141649a948423ba88d648bf44b111bdf72f556cd55d01dea8a50fcbe287f
- kind: remote
  url: goproxy:github.com/fsnotify/fsnotify/@v/v1.10.1.zip
  directory: goproxy/github.com/fsnotify/fsnotify/@v
  filename: v1.10.1.zip
  ref: b2c6a334e0d518da2e046066bdd9da34cb26bad6df9f17701802d3de522ab016
- kind: remote
  url: goproxy:github.com/fxamacker/cbor/v2/@v/v2.9.6.mod
  directory: goproxy/github.com/fxamacker/cbor/v2/@v
  filename: v2.9.6.mod
  ref: 20fec9531f1696f504d546afb81608ec39648d1e9de31d4921f26f9839449b79
- kind: remote
  url: goproxy:github.com/fxamacker/cbor/v2/@v/v2.9.6.zip
  directory: goproxy/github.com/fxamacker/cbor/v2/@v
  filename: v2.9.6.zip
  ref: f336ba6592c33671f7c331f3182ed60dbcc5e946c9cc9aef7818344634486652
- kind: remote
  url: goproxy:github.com/go-git/gcfg/v2/@v/v2.0.2.mod
  directory: goproxy/github.com/go-git/gcfg/v2/@v
  filename: v2.0.2.mod
  ref: 692df35c1e03884842b3e2e78a979f7a2ac77c515c1bba85c098051a6fcbe58f
- kind: remote
  url: goproxy:github.com/go-git/gcfg/v2/@v/v2.0.2.zip
  directory: goproxy/github.com/go-git/gcfg/v2/@v
  filename: v2.0.2.zip
  ref: ef81d26f3e5d3d35c1c01c72fab206406234d66e0ce71d026d05c1e3187d22f9
- kind: remote
  url: goproxy:github.com/go-git/go-billy/v6/@v/v6.0.0-beta.1.mod
  directory: goproxy/github.com/go-git/go-billy/v6/@v
  filename: v6.0.0-beta.1.mod
  ref: 720cca6c187e5d869281cb84a6ec0ec2b2bb2529dd5a82d2f12b172e56285217
- kind: remote
  url: goproxy:github.com/go-git/go-billy/v6/@v/v6.0.0-beta.1.zip
  directory: goproxy/github.com/go-git/go-billy/v6/@v
  filename: v6.0.0-beta.1.zip
  ref: 446581bd14403cc302d4cbc2362a4b19dc0a6f5d12c8347e274c7fc00e6f9fd5
- kind: remote
  url: goproxy:github.com/go-git/go-git/v6/@v/v6.0.0-beta.1.mod
  directory: goproxy/github.com/go-git/go-git/v6/@v
  filename: v6.0.0-beta.1.mod
  ref: 184a0ec2349e2f976e712600fedab736718266c1299afddc30a8f7bc4ae5a3b7
- kind: remote
  url: goproxy:github.com/go-git/go-git/v6/@v/v6.0.0-beta.1.zip
  directory: goproxy/github.com/go-git/go-git/v6/@v
  filename: v6.0.0-beta.1.zip
  ref: 2d5ea038d470765ff92ab32ee964e42dc103d31b22ad73ae1daa903d2b83505c
- kind: remote
  url: goproxy:github.com/go-json-experiment/json/@v/v0.0.0-20260820222146-c27c302e5fc3.mod
  directory: goproxy/github.com/go-json-experiment/json/@v
  filename: v0.0.0-20260820222146-c27c302e5fc3.mod
  ref: 64ddb6e13b6f1d3d6fb44c9a938b485b2c2d5c6fe6d897370a3900dff5a4b1f1
- kind: remote
  url: goproxy:github.com/go-json-experiment/json/@v/v0.0.0-20260820222146-c27c302e5fc3.zip
  directory: goproxy/github.com/go-json-experiment/json/@v
  filename: v0.0.0-20260820222146-c27c302e5fc3.zip
  ref: 7cde0df93446eb825784b1af82c0af1fe0306008abf343342b9857df4250698e
- kind: remote
  url: goproxy:github.com/go-logfmt/logfmt/@v/v0.6.1.mod
  directory: goproxy/github.com/go-logfmt/logfmt/@v
  filename: v0.6.1.mod
  ref: 0b2156771924d6013115a2e80b391afc2ff9d6a22f1bd83a03acf621be39ee4c
- kind: remote
  url: goproxy:github.com/go-logfmt/logfmt/@v/v0.6.1.zip
  directory: goproxy/github.com/go-logfmt/logfmt/@v
  filename: v0.6.1.zip
  ref: 20f61151ffe33e64602b3a0db4eaed9ef60a84398a4a495a7434ffb90635751b
- kind: remote
  url: goproxy:github.com/godbus/dbus/v5/@v/v5.2.4.mod
  directory: goproxy/github.com/godbus/dbus/v5/@v
  filename: v5.2.4.mod
  ref: d008ac84f404c6fbc7a1f378099dd21794843d10d6cdc129cfc403d39656f5a6
- kind: remote
  url: goproxy:github.com/godbus/dbus/v5/@v/v5.2.4.zip
  directory: goproxy/github.com/godbus/dbus/v5/@v
  filename: v5.2.4.zip
  ref: 2a3a2996c274cbb735aa7f634dbcc0b292c0dff154447896d3a95955d078fb83
- kind: remote
  url: goproxy:github.com/golang/freetype/@v/v0.0.0-20170609003504-e2365dfdc4a0.mod
  directory: goproxy/github.com/golang/freetype/@v
  filename: v0.0.0-20170609003504-e2365dfdc4a0.mod
  ref: 26d471ad5950334d990718ffb46734113226ef134f19fbb87354e3d87dd34853
- kind: remote
  url: goproxy:github.com/golang/freetype/@v/v0.0.0-20170609003504-e2365dfdc4a0.zip
  directory: goproxy/github.com/golang/freetype/@v
  filename: v0.0.0-20170609003504-e2365dfdc4a0.zip
  ref: cdcb9e6a14933dcbf167b44dcd5083fc6a2e52c4fae8fb79747c691efeb7d84e
- kind: remote
  url: goproxy:github.com/hdevalence/ed25519consensus/@v/v0.2.0.mod
  directory: goproxy/github.com/hdevalence/ed25519consensus/@v
  filename: v0.2.0.mod
  ref: be371084b2cd094b627c56090e34606cfe27d37ed694953e1496fe93d33095e1
- kind: remote
  url: goproxy:github.com/hdevalence/ed25519consensus/@v/v0.2.0.zip
  directory: goproxy/github.com/hdevalence/ed25519consensus/@v
  filename: v0.2.0.zip
  ref: 111cafade3ba9c7c3adf66b6a424386e30829c46c60b80dabe288e1837d30e33
- kind: remote
  url: goproxy:github.com/holoplot/go-evdev/@v/v0.0.0-20260909133534-d873ed210bda.mod
  directory: goproxy/github.com/holoplot/go-evdev/@v
  filename: v0.0.0-20260909133534-d873ed210bda.mod
  ref: 5480e9def29d77e7408648ce0667f46398c88a382244ac5713b96ac2169dd7fe
- kind: remote
  url: goproxy:github.com/holoplot/go-evdev/@v/v0.0.0-20260909133534-d873ed210bda.zip
  directory: goproxy/github.com/holoplot/go-evdev/@v
  filename: v0.0.0-20260909133534-d873ed210bda.zip
  ref: c72823a2bd07ad479ecf2dd9b7754cb7e962a7c5fcc818620991eb7dcc2ea8a8
- kind: remote
  url: goproxy:github.com/jsimonetti/rtnetlink/@v/v1.4.2.mod
  directory: goproxy/github.com/jsimonetti/rtnetlink/@v
  filename: v1.4.2.mod
  ref: 0aa4bc0b8d1d10b3224d1cf4733e579d3d231d59d8089cb52c0908e0079d499b
- kind: remote
  url: goproxy:github.com/jsimonetti/rtnetlink/@v/v1.4.2.zip
  directory: goproxy/github.com/jsimonetti/rtnetlink/@v
  filename: v1.4.2.zip
  ref: 08662e20c1a178734d79053305748f108c49f07fb8eae1a60b034165d21bd709
- kind: remote
  url: goproxy:github.com/kevinburke/ssh_config/@v/v1.6.0.mod
  directory: goproxy/github.com/kevinburke/ssh_config/@v
  filename: v1.6.0.mod
  ref: 2a786cf387e46473d733cc5f3036ec692b1e882edd2709d9589c32808ea09275
- kind: remote
  url: goproxy:github.com/kevinburke/ssh_config/@v/v1.6.0.zip
  directory: goproxy/github.com/kevinburke/ssh_config/@v
  filename: v1.6.0.zip
  ref: cb3e2a23c10382dac238ea51ed1162c75cb7e986532d1ce92a2051469ca24e44
- kind: remote
  url: goproxy:github.com/klauspost/compress/@v/v1.20.3.mod
  directory: goproxy/github.com/klauspost/compress/@v
  filename: v1.20.3.mod
  ref: 0d4e90d99acbc19eea5706e7390f8c925b26b1f5861385bb4f1321d454a1d48c
- kind: remote
  url: goproxy:github.com/klauspost/compress/@v/v1.20.3.zip
  directory: goproxy/github.com/klauspost/compress/@v
  filename: v1.20.3.zip
  ref: 1eb710a814c44bf21332a512a19f496fb5c489ca8eb72244bb9c49f80900848f
- kind: remote
  url: goproxy:github.com/lucasb-eyer/go-colorful/@v/v1.4.1.mod
  directory: goproxy/github.com/lucasb-eyer/go-colorful/@v
  filename: v1.4.1.mod
  ref: 84f9c38e9884ab013c837cb16aee139500d3d5c6ccab02439881db2ecf28f660
- kind: remote
  url: goproxy:github.com/lucasb-eyer/go-colorful/@v/v1.4.1.zip
  directory: goproxy/github.com/lucasb-eyer/go-colorful/@v
  filename: v1.4.1.zip
  ref: 399a71ecf3e3aaa0af96a779f1c106688b095dbfd0a85455a7c706d3d7ff9ebd
- kind: remote
  url: goproxy:github.com/mattn/go-isatty/@v/v0.0.24.mod
  directory: goproxy/github.com/mattn/go-isatty/@v
  filename: v0.0.24.mod
  ref: 41b885f68c2fa4dfb26a8ffa30d095a931b27699b6b2b1974af3949400dc060f
- kind: remote
  url: goproxy:github.com/mattn/go-isatty/@v/v0.0.24.zip
  directory: goproxy/github.com/mattn/go-isatty/@v
  filename: v0.0.24.zip
  ref: 4fcffec0bae0ad4af7bf96e2497a817d85de64af19ffe31d82bda362148234b8
- kind: remote
  url: goproxy:github.com/mattn/go-runewidth/@v/v0.0.31.mod
  directory: goproxy/github.com/mattn/go-runewidth/@v
  filename: v0.0.31.mod
  ref: 9091c793e255036ba8ced617fa3225972a745eaee5cad4cf264c1576e5c1347e
- kind: remote
  url: goproxy:github.com/mattn/go-runewidth/@v/v0.0.31.zip
  directory: goproxy/github.com/mattn/go-runewidth/@v
  filename: v0.0.31.zip
  ref: 96e004d61b6755f0190ae250c3ce8aa2d2e73968d0b31236f4dc54477d65bc00
- kind: remote
  url: goproxy:github.com/mdlayher/netlink/@v/v1.11.2.mod
  directory: goproxy/github.com/mdlayher/netlink/@v
  filename: v1.11.2.mod
  ref: 03043d103416a189dedb5a884419baa70de9af754238056f1d8fab7e58da7064
- kind: remote
  url: goproxy:github.com/mdlayher/netlink/@v/v1.11.2.zip
  directory: goproxy/github.com/mdlayher/netlink/@v
  filename: v1.11.2.zip
  ref: 2fbb8a5962c22dfdeaecd18bc2a1215e863bfcfa2ba1a28a3703ce0ae014ba4a
- kind: remote
  url: goproxy:github.com/mdlayher/socket/@v/v0.8.0.mod
  directory: goproxy/github.com/mdlayher/socket/@v
  filename: v0.8.0.mod
  ref: 1d4ccd713def09e3bd5470a0f04ac74a2d08c122d1b7567253fc055c83215a6b
- kind: remote
  url: goproxy:github.com/mdlayher/socket/@v/v0.8.0.zip
  directory: goproxy/github.com/mdlayher/socket/@v
  filename: v0.8.0.zip
  ref: 6e13014a2a6704f8b216b55071ce565415b90d44234b4b2c63be3ed057242efb
- kind: remote
  url: goproxy:github.com/mitchellh/go-ps/@v/v1.0.0.mod
  directory: goproxy/github.com/mitchellh/go-ps/@v
  filename: v1.0.0.mod
  ref: 4c9cf17f3fdf28ca0f95c15e1bf976e3b5065bebec1e76a8052373f32a9846c4
- kind: remote
  url: goproxy:github.com/mitchellh/go-ps/@v/v1.0.0.zip
  directory: goproxy/github.com/mitchellh/go-ps/@v
  filename: v1.0.0.zip
  ref: f2f0400b1d5e136419daed275c27a930b0f5447ac12bb8acd3ddbe39547b2834
- kind: remote
  url: goproxy:github.com/muesli/ansi/@v/v0.0.0-20230316100256-276c6243b2f6.mod
  directory: goproxy/github.com/muesli/ansi/@v
  filename: v0.0.0-20230316100256-276c6243b2f6.mod
  ref: 2b1bf9e02f09e84b49a2a5e350911428530150f4c4fabf74da62114df33dbbc1
- kind: remote
  url: goproxy:github.com/muesli/ansi/@v/v0.0.0-20230316100256-276c6243b2f6.zip
  directory: goproxy/github.com/muesli/ansi/@v
  filename: v0.0.0-20230316100256-276c6243b2f6.zip
  ref: 59c0d420908d51df3c701510337fbe42bfb4d48fcc5f490b5eb2f36fc25f91b9
- kind: remote
  url: goproxy:github.com/muesli/cancelreader/@v/v0.2.2.mod
  directory: goproxy/github.com/muesli/cancelreader/@v
  filename: v0.2.2.mod
  ref: 4343f36dcc06d4ce4e170190062b5d224ff5be831f742531ec27a3d709378fe1
- kind: remote
  url: goproxy:github.com/muesli/cancelreader/@v/v0.2.2.zip
  directory: goproxy/github.com/muesli/cancelreader/@v
  filename: v0.2.2.zip
  ref: f0654e7f8f8a49b02ff10a75ccaa0eb08a65aaacbc45f5ba93305276e2ac7f61
- kind: remote
  url: goproxy:github.com/muesli/termenv/@v/v0.16.0.mod
  directory: goproxy/github.com/muesli/termenv/@v
  filename: v0.16.0.mod
  ref: 07581751f5b61fdae253960c3992898b64b6ad5573a69ba22ad249d7f0a889c1
- kind: remote
  url: goproxy:github.com/muesli/termenv/@v/v0.16.0.zip
  directory: goproxy/github.com/muesli/termenv/@v
  filename: v0.16.0.zip
  ref: ba02d3ebd9c1d87e2c2133b1f2bb61a7001b3765196e8016029ce9fe54c5c0fc
- kind: remote
  url: goproxy:github.com/pilebones/go-udev/@v/v0.10.0.mod
  directory: goproxy/github.com/pilebones/go-udev/@v
  filename: v0.10.0.mod
  ref: 0f44b064bec60da7043355f0c33ba0ae53f2b3700aa3abf92438725a23cc43dc
- kind: remote
  url: goproxy:github.com/pilebones/go-udev/@v/v0.10.0.zip
  directory: goproxy/github.com/pilebones/go-udev/@v
  filename: v0.10.0.zip
  ref: 54fc7dff4cd838d6dd19936ebb2c2bd653a15a40b3586983a308544d04930aa3
- kind: remote
  url: goproxy:github.com/pjbgf/sha1cd/@v/v0.7.0.mod
  directory: goproxy/github.com/pjbgf/sha1cd/@v
  filename: v0.7.0.mod
  ref: 3eeda8551e3e293424ee4cc529d10432d06d7a68b77d90aa534f64ba54cc5454
- kind: remote
  url: goproxy:github.com/pjbgf/sha1cd/@v/v0.7.0.zip
  directory: goproxy/github.com/pjbgf/sha1cd/@v
  filename: v0.7.0.zip
  ref: 5d641862b1f2ba4f19d99089a973663378dc446b1b42d6d381c5be8300fe5bd6
- kind: remote
  url: goproxy:github.com/pkg/errors/@v/v0.9.1.mod
  directory: goproxy/github.com/pkg/errors/@v
  filename: v0.9.1.mod
  ref: df28c6a823f181d76179697177c0c5943c6ffb38f3c10b2dc53be360ee7d4589
- kind: remote
  url: goproxy:github.com/pkg/errors/@v/v0.9.1.zip
  directory: goproxy/github.com/pkg/errors/@v
  filename: v0.9.1.zip
  ref: d4c36b8bcd0616290a3913215e0f53b931bd6e00670596f2960df1b44af2bd07
- kind: remote
  url: goproxy:github.com/rivo/uniseg/@v/v0.4.7.mod
  directory: goproxy/github.com/rivo/uniseg/@v
  filename: v0.4.7.mod
  ref: a1e174890fc9f252450211fadeb53756f9cf5ab7b19697765f9fb255f81ea898
- kind: remote
  url: goproxy:github.com/rivo/uniseg/@v/v0.4.7.zip
  directory: goproxy/github.com/rivo/uniseg/@v
  filename: v0.4.7.zip
  ref: b995e4aa0cc1e5779cc61138ac925cb8c1e963e40c80e4b93ee8553812ebb792
- kind: remote
  url: goproxy:github.com/sblinch/kdl-go/@v/v0.0.0-20260121213736-8b7053306ca6.mod
  directory: goproxy/github.com/sblinch/kdl-go/@v
  filename: v0.0.0-20260121213736-8b7053306ca6.mod
  ref: 2890c7a09e2a16f2d7e6501130f0f9fb70a307f1a16e92a8db02eed186639ee9
- kind: remote
  url: goproxy:github.com/sblinch/kdl-go/@v/v0.0.0-20260121213736-8b7053306ca6.zip
  directory: goproxy/github.com/sblinch/kdl-go/@v
  filename: v0.0.0-20260121213736-8b7053306ca6.zip
  ref: c2093f820c504766aa58d3f2fa56c716f91ad5ab5e2717482f90820efa3e80ff
- kind: remote
  url: goproxy:github.com/sergi/go-diff/@v/v1.4.0.mod
  directory: goproxy/github.com/sergi/go-diff/@v
  filename: v1.4.0.mod
  ref: 1eb393c3f9006362fe3044798890e578af6ae6d69270aaf3eb9bfe819ce654db
- kind: remote
  url: goproxy:github.com/sergi/go-diff/@v/v1.4.0.zip
  directory: goproxy/github.com/sergi/go-diff/@v
  filename: v1.4.0.zip
  ref: 63aef1860b251af1421ba0a014a6bb08a60833f13f948f3d88d66754bb484f53
- kind: remote
  url: goproxy:github.com/shirou/gopsutil/v4/@v/v4.26.9.mod
  directory: goproxy/github.com/shirou/gopsutil/v4/@v
  filename: v4.26.9.mod
  ref: 8006a6ff0ea18693af58dc5a5993a52f4ae0f1e63840038a1b5c7a2bed2eb1c6
- kind: remote
  url: goproxy:github.com/shirou/gopsutil/v4/@v/v4.26.9.zip
  directory: goproxy/github.com/shirou/gopsutil/v4/@v
  filename: v4.26.9.zip
  ref: 2206a841e6e5ca18b4b88d10f90a05c0714528cdec5bdd0801b9c02ed76e0ab6
- kind: remote
  url: goproxy:github.com/spf13/afero/@v/v1.15.0.mod
  directory: goproxy/github.com/spf13/afero/@v
  filename: v1.15.0.mod
  ref: b9ecbcbeeccb9da252f2b75a7f05a10c21f874a448a5e1294f115e47ba893e22
- kind: remote
  url: goproxy:github.com/spf13/afero/@v/v1.15.0.zip
  directory: goproxy/github.com/spf13/afero/@v
  filename: v1.15.0.zip
  ref: d03a0bbce87eeaa1c23f0c0276707bb2d59f46efee875d7d7f1d570201be6e1f
- kind: remote
  url: goproxy:github.com/spf13/cobra/@v/v1.10.2.mod
  directory: goproxy/github.com/spf13/cobra/@v
  filename: v1.10.2.mod
  ref: cc6098fd1118fb3bb349c72bcd6e9c665d3a1b2a516ea9807ee24521ad2ddf8c
- kind: remote
  url: goproxy:github.com/spf13/cobra/@v/v1.10.2.zip
  directory: goproxy/github.com/spf13/cobra/@v
  filename: v1.10.2.zip
  ref: a00aae6fcd631e0fde52c98604452ff70e1b73c3b8a560d68db15aff5e26872d
- kind: remote
  url: goproxy:github.com/spf13/pflag/@v/v1.0.10.mod
  directory: goproxy/github.com/spf13/pflag/@v
  filename: v1.0.10.mod
  ref: 16c6dfc0eb58eb3c9113ce197d460c6725c647e4688ac26d31c8ed69f1ebbc68
- kind: remote
  url: goproxy:github.com/spf13/pflag/@v/v1.0.10.zip
  directory: goproxy/github.com/spf13/pflag/@v
  filename: v1.0.10.zip
  ref: a246b8c9d3daa87d6c634cdfee1bdf7fa53d5817eeef4fa0c6da43edd12de4ca
- kind: remote
  url: goproxy:github.com/srwiley/oksvg/@v/v0.0.0-20221011165216-be6e8873101c.mod
  directory: goproxy/github.com/srwiley/oksvg/@v
  filename: v0.0.0-20221011165216-be6e8873101c.mod
  ref: 96a29c57ae5fe2d5526e16cd8ed51f339e2183830d30b5d1fe22da00f4806866
- kind: remote
  url: goproxy:github.com/srwiley/oksvg/@v/v0.0.0-20221011165216-be6e8873101c.zip
  directory: goproxy/github.com/srwiley/oksvg/@v
  filename: v0.0.0-20221011165216-be6e8873101c.zip
  ref: d8e517dd8a48583bc32892a7c430dda165f79907b1fc9e3d49fe59a2894f587b
- kind: remote
  url: goproxy:github.com/srwiley/rasterx/@v/v0.0.0-20220730225603-2ab79fcdd4ef.mod
  directory: goproxy/github.com/srwiley/rasterx/@v
  filename: v0.0.0-20220730225603-2ab79fcdd4ef.mod
  ref: cbe6e21779a22eb4ac36cd26a00e5c40f72dca84bcd2b98333c72e4f3b68f679
- kind: remote
  url: goproxy:github.com/srwiley/rasterx/@v/v0.0.0-20220730225603-2ab79fcdd4ef.zip
  directory: goproxy/github.com/srwiley/rasterx/@v
  filename: v0.0.0-20220730225603-2ab79fcdd4ef.zip
  ref: 4e76d6b2bd959c0ab7be2fbe1d9c454817e17d3d64ee49a7d78b1bddb7790a75
- kind: remote
  url: goproxy:github.com/tklauser/go-sysconf/@v/v0.4.0.mod
  directory: goproxy/github.com/tklauser/go-sysconf/@v
  filename: v0.4.0.mod
  ref: 29bd839dcc5736ea8ebc4c2f4013db82c57cacd15a010d389579cde04f3336ae
- kind: remote
  url: goproxy:github.com/tklauser/go-sysconf/@v/v0.4.0.zip
  directory: goproxy/github.com/tklauser/go-sysconf/@v
  filename: v0.4.0.zip
  ref: 61e89253bc4d7091170601be12633dc02e94a3bc30470b081a2449944fa18784
- kind: remote
  url: goproxy:github.com/tklauser/numcpus/@v/v0.12.0.mod
  directory: goproxy/github.com/tklauser/numcpus/@v
  filename: v0.12.0.mod
  ref: 03fbc174711500112a8ab1675893ecdbea2e155f3dcd5e357fb4a5619ed6b0d4
- kind: remote
  url: goproxy:github.com/tklauser/numcpus/@v/v0.12.0.zip
  directory: goproxy/github.com/tklauser/numcpus/@v
  filename: v0.12.0.zip
  ref: 56c22a112976df3a4d8db776b41288658070650ae6382ec86d0a32fc07af0276
- kind: remote
  url: goproxy:github.com/x448/float16/@v/v0.8.4.mod
  directory: goproxy/github.com/x448/float16/@v
  filename: v0.8.4.mod
  ref: f8a8238aa734c1d2463d48f8808e35124546bd5222b13e4c097746ded5a57e1e
- kind: remote
  url: goproxy:github.com/x448/float16/@v/v0.8.4.zip
  directory: goproxy/github.com/x448/float16/@v
  filename: v0.8.4.zip
  ref: 73b24a41037ea999ab66851e3798a0973dbb1f214925915b01f0820f7b2f1500
- kind: remote
  url: goproxy:github.com/xo/terminfo/@v/v1.2.0.mod
  directory: goproxy/github.com/xo/terminfo/@v
  filename: v1.2.0.mod
  ref: 12b94fc7704c723ed862da212257099bacb248ad07eeeb03da5d7cba9f8871e4
- kind: remote
  url: goproxy:github.com/xo/terminfo/@v/v1.2.0.zip
  directory: goproxy/github.com/xo/terminfo/@v
  filename: v1.2.0.zip
  ref: 90294795cef18ff941af0d4bf314a685c864818308212d7594716b4d682bb07b
- kind: remote
  url: goproxy:github.com/yeqown/go-qrcode/v2/@v/v2.3.0.mod
  directory: goproxy/github.com/yeqown/go-qrcode/v2/@v
  filename: v2.3.0.mod
  ref: 1e8f692da0a3d3d2caf99c79417f71b92a0f65b82194ff2e14c8810292b1b4eb
- kind: remote
  url: goproxy:github.com/yeqown/go-qrcode/v2/@v/v2.3.0.zip
  directory: goproxy/github.com/yeqown/go-qrcode/v2/@v
  filename: v2.3.0.zip
  ref: 44ee91217ea9fc65a2c53f90d0bc9738c95695e53164bd643a2f71b898ed19cf
- kind: remote
  url: goproxy:github.com/yeqown/go-qrcode/writer/standard/@v/v1.4.0.mod
  directory: goproxy/github.com/yeqown/go-qrcode/writer/standard/@v
  filename: v1.4.0.mod
  ref: b5ee76aee48b6688f28efb5d76f5bd2de8b9fc081da3bcca91d79d48be09e343
- kind: remote
  url: goproxy:github.com/yeqown/go-qrcode/writer/standard/@v/v1.4.0.zip
  directory: goproxy/github.com/yeqown/go-qrcode/writer/standard/@v
  filename: v1.4.0.zip
  ref: ad55ec182757627c19590f9d8310376bf45d544675be9a21e4db157be670708c
- kind: remote
  url: goproxy:github.com/yeqown/reedsolomon/@v/v1.0.0.mod
  directory: goproxy/github.com/yeqown/reedsolomon/@v
  filename: v1.0.0.mod
  ref: 23974aad79e4df8a121d9801933d992863e00af4f52080e656611a46cd5ebc07
- kind: remote
  url: goproxy:github.com/yeqown/reedsolomon/@v/v1.0.0.zip
  directory: goproxy/github.com/yeqown/reedsolomon/@v
  filename: v1.0.0.zip
  ref: a834afc29e46619d86583af9115a16bb16b6e4617211a2d02d01a5d39b5bb2f7
- kind: remote
  url: goproxy:github.com/yuin/goldmark/@v/v1.8.6.mod
  directory: goproxy/github.com/yuin/goldmark/@v
  filename: v1.8.6.mod
  ref: b78e60b0c300e7d48dcc234a7e0103eeb8d6cf40ca9cde9d01e6a3a7f1086045
- kind: remote
  url: goproxy:github.com/yuin/goldmark/@v/v1.8.6.zip
  directory: goproxy/github.com/yuin/goldmark/@v
  filename: v1.8.6.zip
  ref: 6cb11723302ba0dd45f8d7a26f7fa3c48be23523622c18293783ce82a3c5de46
- kind: remote
  url: goproxy:go.etcd.io/bbolt/@v/v1.5.0.mod
  directory: goproxy/go.etcd.io/bbolt/@v
  filename: v1.5.0.mod
  ref: 3acf3f97a95e4028c1bbe27e58a1a6ba4ec8fc510e17d3166c47c50f601b4a2e
- kind: remote
  url: goproxy:go.etcd.io/bbolt/@v/v1.5.0.zip
  directory: goproxy/go.etcd.io/bbolt/@v
  filename: v1.5.0.zip
  ref: 2c350ca36afba707b917529a8049b001c71915c99c152d5e2600ed4bac6fbc37
- kind: remote
  url: goproxy:go4.org/mem/@v/v0.0.0-20240501181205-ae6ca9944745.mod
  directory: goproxy/go4.org/mem/@v
  filename: v0.0.0-20240501181205-ae6ca9944745.mod
  ref: 4caf98eb924c6539689fe4851b2acdff647b72ed38f95faad5442ea0c6efd105
- kind: remote
  url: goproxy:go4.org/mem/@v/v0.0.0-20240501181205-ae6ca9944745.zip
  directory: goproxy/go4.org/mem/@v
  filename: v0.0.0-20240501181205-ae6ca9944745.zip
  ref: 9b5037a57122457fdc5c2c0a31e3996b44cf9dfcdee5c53ed72adfd88d077795
- kind: remote
  url: goproxy:go4.org/netipx/@v/v0.0.0-20260823151212-3075585bcbeb.mod
  directory: goproxy/go4.org/netipx/@v
  filename: v0.0.0-20260823151212-3075585bcbeb.mod
  ref: 567ffe55c30a5346e382d4e54ef8a82a80704c9a3979e30bb66309a9a244a70b
- kind: remote
  url: goproxy:go4.org/netipx/@v/v0.0.0-20260823151212-3075585bcbeb.zip
  directory: goproxy/go4.org/netipx/@v
  filename: v0.0.0-20260823151212-3075585bcbeb.zip
  ref: 6d0c289f57693a2a5b7a64b4a7f79f0954ce8f7d451528fe602ea594fbcdffff
- kind: remote
  url: goproxy:golang.org/x/crypto/@v/v0.58.0.mod
  directory: goproxy/golang.org/x/crypto/@v
  filename: v0.58.0.mod
  ref: 938883ec4a74e7fc05c46269e924dda334c2b7ca7ca219e4d27ca56d1891ccd3
- kind: remote
  url: goproxy:golang.org/x/crypto/@v/v0.58.0.zip
  directory: goproxy/golang.org/x/crypto/@v
  filename: v0.58.0.zip
  ref: b0a45594cda20ddb4264d84aeff9b588b8570bf6a2833c51a0b821734a298d95
- kind: remote
  url: goproxy:golang.org/x/exp/@v/v0.0.0-20261014143641-f0251eb4aa3e.mod
  directory: goproxy/golang.org/x/exp/@v
  filename: v0.0.0-20261014143641-f0251eb4aa3e.mod
  ref: 8f61285796e27bf67ad94362a2e8c5391a714e08fdbc6c4c961edcb07b5c764b
- kind: remote
  url: goproxy:golang.org/x/exp/@v/v0.0.0-20261014143641-f0251eb4aa3e.zip
  directory: goproxy/golang.org/x/exp/@v
  filename: v0.0.0-20261014143641-f0251eb4aa3e.zip
  ref: 59f56c3ee46a87131794a9ccd90d9f6430702377e76bdeed0b5a726ab0dce59e
- kind: remote
  url: goproxy:golang.org/x/image/@v/v0.47.0.mod
  directory: goproxy/golang.org/x/image/@v
  filename: v0.47.0.mod
  ref: 4283357bab40f12031f2b0c9605b1bdf5afb077319b090a572ee50a843f477dd
- kind: remote
  url: goproxy:golang.org/x/image/@v/v0.47.0.zip
  directory: goproxy/golang.org/x/image/@v
  filename: v0.47.0.zip
  ref: 3666e9fe5b8d6110471d649641e680bb117c86495d0aa2c4d8673e87d9ac6c3c
- kind: remote
  url: goproxy:golang.org/x/net/@v/v0.61.0.mod
  directory: goproxy/golang.org/x/net/@v
  filename: v0.61.0.mod
  ref: 7bbcec6b6af859939ec01bbe5234e556c867bf80e171abc23ad16c2c8e3951fe
- kind: remote
  url: goproxy:golang.org/x/net/@v/v0.61.0.zip
  directory: goproxy/golang.org/x/net/@v
  filename: v0.61.0.zip
  ref: f6843a98d608298e48a6ca287292c9a6fae066284050ce174d5ffb781c9b3dcf
- kind: remote
  url: goproxy:golang.org/x/sync/@v/v0.24.0.mod
  directory: goproxy/golang.org/x/sync/@v
  filename: v0.24.0.mod
  ref: febf4fed5dc12c0de24528f7065bf071cc74a2424070194aaf24617b91066cda
- kind: remote
  url: goproxy:golang.org/x/sync/@v/v0.24.0.zip
  directory: goproxy/golang.org/x/sync/@v
  filename: v0.24.0.zip
  ref: ca3fcf3ea8259e75891f7947e1a816a5b89402c542d45d8bbbd9e061b0c58019
- kind: remote
  url: goproxy:golang.org/x/sys/@v/v0.49.0.mod
  directory: goproxy/golang.org/x/sys/@v
  filename: v0.49.0.mod
  ref: 9522f4c9806d1c26586ea80fa56292929bd295865e71981927f52996c6b1c831
- kind: remote
  url: goproxy:golang.org/x/sys/@v/v0.49.0.zip
  directory: goproxy/golang.org/x/sys/@v
  filename: v0.49.0.zip
  ref: e73a06591ca0d7016ce3ccb45c36a8ed7128468aecc1a357f94d815c760c6b31
- kind: remote
  url: goproxy:golang.org/x/text/@v/v0.43.0.mod
  directory: goproxy/golang.org/x/text/@v
  filename: v0.43.0.mod
  ref: 63270b8ca6290a720212e1d6e58b8d12a8aa315a1cb960411d7ec2998c0aab59
- kind: remote
  url: goproxy:golang.org/x/text/@v/v0.43.0.zip
  directory: goproxy/golang.org/x/text/@v
  filename: v0.43.0.zip
  ref: b75131f628f6e2e4892fd638d33127e952a5027775e0162b94ba069cb4e13863
- kind: remote
  url: goproxy:gopkg.in/yaml.v3/@v/v3.0.1.mod
  directory: goproxy/gopkg.in/yaml.v3/@v
  filename: v3.0.1.mod
  ref: 21579860a20306fcf43b1bd234d1fba319499c77611b71c05f9bf3ba90dab939
- kind: remote
  url: goproxy:gopkg.in/yaml.v3/@v/v3.0.1.zip
  directory: goproxy/gopkg.in/yaml.v3/@v
  filename: v3.0.1.zip
  ref: aab8fbc4e6300ea08e6afe1caea18a21c90c79f489f52c53e2f20431f1a9a015
- kind: remote
  url: goproxy:tailscale.com/@v/v1.104.1.mod
  directory: goproxy/tailscale.com/@v
  filename: v1.104.1.mod
  ref: 2b33219e6719b71387e0829efbb2e71605ffb4b0aadf5ef66dceb354751c5f33
- kind: remote
  url: goproxy:tailscale.com/@v/v1.104.1.zip
  directory: goproxy/tailscale.com/@v
  filename: v1.104.1.zip
  ref: 648ad9fb1ecb2e4075fa46be7a0e01568d666cc1161d02c76ace48d8e41da6c4

environment:
  PATH: "%{prefix}/lib/go-1.27/bin:/usr/bin"
  GOPROXY: "file://%{build-root}/goproxy"
  GOMODCACHE: "%{build-root}/.gomodcache"
  GOCACHE: "%{build-root}/.gocache"
  # go.sum is the check: no checksum database to ask offline
  GOSUMDB: "off"

config:
  configure-commands:
  # The UI's revision key, .dankrev, is a hash of the UI's files, which the
  # Makefile writes while it lists them: whether it hashes .dankrev itself
  # depends on timing, so equal sources gave different binaries.  Leave it
  # out of the list.
  - |
    sed -i 's/find \. -type f -print0 | LC_ALL=C sort -z/find . -type f ! -name .dankrev -print0 | LC_ALL=C sort -z/' core/Makefile
    grep -q 'find . -type f ! -name .dankrev -print0' core/Makefile

  build-commands:
  # The version and commit, which the Makefile asks git for (the tarball has
  # no .git), and a fixed build time, so equal sources give an equal binary
  - make -C core build VERSION=2.1.2 COMMIT=v2.1.2 BUILD_TIME=v2.1.2

  install-commands:
  # Not `make install`: it would also write a systemd unit into the
  # builder's home (this element installs DMS's unit itself, below), and
  # its icon and desktop targets refresh the icon and MIME caches, which
  # would clash with other packages' should those tools ever be in the
  # sandbox
  - make install-bin install-completions PREFIX=%{prefix} DESTDIR=%{install-root}
  - |
    install -D -m 0644 assets/dev.duxlabs.shell.svg %{install-root}%{datadir}/icons/hicolor/scalable/apps/dev.duxlabs.shell.svg
    for entry in dms-open dev.duxlabs.shell dev.duxlabs.shell.notepad; do
      install -D -m 0644 assets/$entry.desktop %{install-root}%{datadir}/applications/$entry.desktop
    done

  # DMS in the niri session (desktop/niri.bst), as `dms setup` would set it
  # up -- which cannot do it here: it asks questions, and asks for root.
  #
  # 1. Its niri configuration, kept in /usr/share/dms/niri: config.kdl and
  #    the dms/*.kdl files it includes (keys, layout, colours, alt-tab,
  #    input), with Ghostty as the terminal, and US and Arabic keyboards
  #    (Alt+Shift switches, as on the login screen).
  - |
    embedded=core/internal/config/embedded
    niri=%{install-root}%{datadir}/dms/niri
    install -D -m 0644 $embedded/niri.kdl $niri/config.kdl
    for part in binds layout colors alttab input; do
      install -D -m 0644 $embedded/niri-$part.kdl $niri/dms/$part.kdl
    done
    sed -i 's/{{TERMINAL_COMMAND}}/ghostty/g' $niri/config.kdl $niri/dms/binds.kdl
    sed -i '/^        xkb {$/a\            layout "us,ara"\n            options "grp:alt_shift_toggle"' $niri/config.kdl
    if grep -rq '{{' $niri; then echo "a template left unfilled in $niri" >&2; exit 1; fi
    grep -q '^            layout "us,ara"$' $niri/config.kdl
  # 2. A new user's ~/.config/niri gets that configuration before niri
  #    first starts (niri would otherwise write its own, without DMS's
  #    keys).  An existing configuration is never touched.
  - |
    units=%{install-root}%{prefix}/lib/systemd/user
    mkdir -p $units/niri.service.wants
    cat > $units/dms-niri-config.service <<'UNIT'
    [Unit]
    Description=Copy DMS's niri configuration to a new user
    ConditionPathExists=!%h/.config/niri/config.kdl
    Before=niri.service

    [Service]
    Type=oneshot
    ExecStart=/usr/bin/mkdir -p %h/.config/niri
    ExecStart=/usr/bin/cp -r -n /usr/share/dms/niri/. %h/.config/niri/
    UNIT
    ln -s ../dms-niri-config.service $units/niri.service.wants/dms-niri-config.service
  # 3. DMS starts with niri: upstream's unit, wanted by niri.service, as
  #    `systemctl --user add-wants niri.service dms` would make it.
  - |
    units=%{install-root}%{prefix}/lib/systemd/user
    install -D -m 0644 assets/systemd/dms.service $units/dms.service
    ln -s ../dms.service $units/niri.service.wants/dms.service

  # Its build info, not the program: dms refuses to run as root, which
  # the sandbox is
  - go version -m %{install-root}%{bindir}/dms | grep -q -- '-tags=withshell'
