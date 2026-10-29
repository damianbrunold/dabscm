;; The fonts of the dabscm-fonts package (see package-fonts.scm and
;; (scm fonts)): free fonts, as their projects release them, each file
;; pinned by URL (a tagged commit or release) and SHA-256.
;;
;;   (version v)                     the package's version (its own, not
;;                                   dabscm's)
;;   (archive name url sha256)       a release zip that files come from
;;   (family name directory
;;     (source text)                 where it is from, for the README
;;     (license name file source sha256)
;;     (face weight italic? file source sha256) ...)
;;
;; A source is (url "...") or (archive name "path in the zip"). Only
;; static TrueType files (glyf outlines): (scm truetype) reads no CFF and
;; only the default instance of a variable font.

(version "1.1.0")
(archive inter "https://github.com/rsms/inter/releases/download/v4.1/Inter-4.1.zip"
         "9883fdd4a49d4fb66bd8177ba6625ef9a64aa45899767dde3d36aa425756b11e")
(archive roboto "https://github.com/googlefonts/roboto-3-classic/releases/download/v3.016/Roboto_v3.016.zip"
         "1653dbe12f248da8fb0b9920db7b9496cd677ed3981154f6f15285c8bd4e334f")

(family "Inter" "inter"
  (source "Inter 4.1, https://github.com/rsms/inter")
  (license "SIL Open Font License 1.1" "LICENSE.txt"
    (archive inter "LICENSE.txt")
    "262481e844521b326f5ecd053e59b98c8b2da78c8ee1bdbb6e8174305e54935a")
  (face 400 #f "Inter-Regular.ttf"
    (archive inter "extras/ttf/Inter-Regular.ttf")
    "40d692fce188e4471e2b3cba937be967878f631ad3ebbbdcd587687c7ebe0c82")
  (face 700 #f "Inter-Bold.ttf"
    (archive inter "extras/ttf/Inter-Bold.ttf")
    "288316099b1e0a47a4716d159098005eef7c0066921f34e3200393dbdb01947f")
  (face 900 #f "Inter-Black.ttf"
    (archive inter "extras/ttf/Inter-Black.ttf")
    "6342d3ea6dc088b43867f615e807d898adf100c93edb978b8e52c5eb71a264da")
  (face 400 #t "Inter-Italic.ttf"
    (archive inter "extras/ttf/Inter-Italic.ttf")
    "bbc051dd204b5019a1aa0bc0ae2aa8a05ab13e7a3f979fa357631dc7feb6833a")
  (face 700 #t "Inter-BoldItalic.ttf"
    (archive inter "extras/ttf/Inter-BoldItalic.ttf")
    "948405a16cdc62701da5f4005ed068ca5f4d27061d98f7974ccfc37831d9581d")
)

(family "Roboto" "roboto"
  (source "Roboto 3.016 (unhinted), https://github.com/googlefonts/roboto-3-classic")
  (license "SIL Open Font License 1.1" "OFL.txt"
    (url "https://raw.githubusercontent.com/googlefonts/roboto-3-classic/5166f3d07889bf7d3732fb72e09623d7e52f862b/OFL.txt")
    "061402327a96aadb0bfb694a960ed289ecd38d383e396243831ab81feb109c41")
  (face 400 #f "Roboto-Regular.ttf"
    (archive roboto "unhinted/static/Roboto-Regular.ttf")
    "39548fd9d6250717a5fcfe00b1b0ade234c1f5be8a40818c37e995c13c844df1")
  (face 700 #f "Roboto-Bold.ttf"
    (archive roboto "unhinted/static/Roboto-Bold.ttf")
    "15216b8c5fd9ccfe4ecfc316eb8038ecb556814cea2f1eabda4c9d41e434becb")
  (face 400 #t "Roboto-Italic.ttf"
    (archive roboto "unhinted/static/Roboto-Italic.ttf")
    "7dd5804207cd9750ae8067caf99805a21700af8dab31cbc1f58f6f30fdfd8193")
  (face 700 #t "Roboto-BoldItalic.ttf"
    (archive roboto "unhinted/static/Roboto-BoldItalic.ttf")
    "167b87944777eb55f93324df8b08384df639168255c88319df5c48089917ff91")
)

(family "Roboto Slab" "roboto-slab"
  (source "Roboto Slab 2.002, https://github.com/googlefonts/robotoslab")
  (license "Apache License 2.0" "LICENSE.txt"
    (url "https://raw.githubusercontent.com/googlefonts/robotoslab/67af3ce9c4ca574419e1295b6165a2eeee112e6e/LICENSE.txt")
    "cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30")
  (face 400 #f "RobotoSlab-Regular.ttf"
    (url "https://raw.githubusercontent.com/googlefonts/robotoslab/67af3ce9c4ca574419e1295b6165a2eeee112e6e/fonts/ttf/RobotoSlab-Regular.ttf")
    "fd4d98f8403041d58d67735f4549a42ac7cfc79464d4fac5f02345e1404dd2ca")
  (face 700 #f "RobotoSlab-Bold.ttf"
    (url "https://raw.githubusercontent.com/googlefonts/robotoslab/67af3ce9c4ca574419e1295b6165a2eeee112e6e/fonts/ttf/RobotoSlab-Bold.ttf")
    "09cd9e359296e2f9482e2445ba921041913b55e652645df083079a85a272fce4")
)

(family "Source Serif 4" "source-serif-4"
  (source "Source Serif 4.005, https://github.com/adobe-fonts/source-serif")
  (license "SIL Open Font License 1.1" "LICENSE.md"
    (url "https://raw.githubusercontent.com/adobe-fonts/source-serif/2823e993c53fca27c5c8749f529b56a5a7c77b6b/LICENSE.md")
    "75784a295293a8992f5a8d99210566e0064a012e6dab6731305e3787f15896c7")
  (face 400 #f "SourceSerif4-Regular.ttf"
    (url "https://raw.githubusercontent.com/adobe-fonts/source-serif/2823e993c53fca27c5c8749f529b56a5a7c77b6b/TTF/SourceSerif4-Regular.ttf")
    "e5a4ee6a3d87bb9024796be390c6771e2a0eb1883dae25effaf57ca01668e24b")
  (face 700 #f "SourceSerif4-Bold.ttf"
    (url "https://raw.githubusercontent.com/adobe-fonts/source-serif/2823e993c53fca27c5c8749f529b56a5a7c77b6b/TTF/SourceSerif4-Bold.ttf")
    "7cf4f4e1ad74f45058d5bc61716b82560442fbdcd9d3654d2dea96bf6c683d86")
  (face 400 #t "SourceSerif4-It.ttf"
    (url "https://raw.githubusercontent.com/adobe-fonts/source-serif/2823e993c53fca27c5c8749f529b56a5a7c77b6b/TTF/SourceSerif4-It.ttf")
    "9d2950a8f1da66e21502c35d646a1d2148e79f9ea43fd2158cf02f5232e7f430")
  (face 700 #t "SourceSerif4-BoldIt.ttf"
    (url "https://raw.githubusercontent.com/adobe-fonts/source-serif/2823e993c53fca27c5c8749f529b56a5a7c77b6b/TTF/SourceSerif4-BoldIt.ttf")
    "7b215b37f8873f5579f3f8d2ded3ca7c588e2f435cd996605ebfc5befe2cd5eb")
)

(family "JetBrains Mono" "jetbrains-mono"
  (source "JetBrains Mono 2.304, https://github.com/JetBrains/JetBrainsMono")
  (license "SIL Open Font License 1.1" "OFL.txt"
    (url "https://raw.githubusercontent.com/JetBrains/JetBrainsMono/cd5227bd1f61dff3bbd6c814ceaf7ffd95e947d9/OFL.txt")
    "30f0c136e3c88e422d0791acd97238870f9054a9729bc34cf2ff0d4ed8cac4ad")
  (face 400 #f "JetBrainsMono-Regular.ttf"
    (url "https://raw.githubusercontent.com/JetBrains/JetBrainsMono/cd5227bd1f61dff3bbd6c814ceaf7ffd95e947d9/fonts/ttf/JetBrainsMono-Regular.ttf")
    "a0bf60ef0f83c5ed4d7a75d45838548b1f6873372dfac88f71804491898d138f")
  (face 700 #f "JetBrainsMono-Bold.ttf"
    (url "https://raw.githubusercontent.com/JetBrains/JetBrainsMono/cd5227bd1f61dff3bbd6c814ceaf7ffd95e947d9/fonts/ttf/JetBrainsMono-Bold.ttf")
    "5590990c82e097397517f275f430af4546e1c45cff408bde4255dad142479dcb")
  (face 400 #t "JetBrainsMono-Italic.ttf"
    (url "https://raw.githubusercontent.com/JetBrains/JetBrainsMono/cd5227bd1f61dff3bbd6c814ceaf7ffd95e947d9/fonts/ttf/JetBrainsMono-Italic.ttf")
    "9d0a1f7a708e6af183f1193b7e81d40da294f5c67682c085d8401c60aac8ded4")
  (face 700 #t "JetBrainsMono-BoldItalic.ttf"
    (url "https://raw.githubusercontent.com/JetBrains/JetBrainsMono/cd5227bd1f61dff3bbd6c814ceaf7ffd95e947d9/fonts/ttf/JetBrainsMono-BoldItalic.ttf")
    "4039d5ce0ed225bf9c8b2c8c6436290ae2f356b7e90d70fa666227238324aa3b")
)

(family "Noto Sans" "noto-sans"
  (source "Noto Sans (unhinted), https://github.com/notofonts/latin-greek-cyrillic")
  (license "SIL Open Font License 1.1" "OFL.txt"
    (url "https://raw.githubusercontent.com/notofonts/latin-greek-cyrillic/0ef94805d19e98ed658543a7c48c0a4f19cc0ac0/OFL.txt")
    "cee9892f9f0cc8fe882c9e9537ee6a89621d86ee7ceaf70b02e2b2b1c25c061a")
  (face 400 #f "NotoSans-Regular.ttf"
    (url "https://raw.githubusercontent.com/notofonts/notofonts.github.io/c1d3718e2a0eb25c2567a694ee017061fdaa5f51/fonts/NotoSans/unhinted/ttf/NotoSans-Regular.ttf")
    "f3961a9cde016d41a4879aecda1474d3a36d6bf54fa0e4643de029cc2248b0e8")
  (face 700 #f "NotoSans-Bold.ttf"
    (url "https://raw.githubusercontent.com/notofonts/notofonts.github.io/c1d3718e2a0eb25c2567a694ee017061fdaa5f51/fonts/NotoSans/unhinted/ttf/NotoSans-Bold.ttf")
    "87cb2d84472a7d66da659ee47b6cdb9552326e8c128245231f191b6ac72529d9")
  (face 400 #t "NotoSans-Italic.ttf"
    (url "https://raw.githubusercontent.com/notofonts/notofonts.github.io/c1d3718e2a0eb25c2567a694ee017061fdaa5f51/fonts/NotoSans/unhinted/ttf/NotoSans-Italic.ttf")
    "678288f868807d4d64a6f3b51466871d117d915780381ce9d0ed4b3bcbd06d37")
  (face 700 #t "NotoSans-BoldItalic.ttf"
    (url "https://raw.githubusercontent.com/notofonts/notofonts.github.io/c1d3718e2a0eb25c2567a694ee017061fdaa5f51/fonts/NotoSans/unhinted/ttf/NotoSans-BoldItalic.ttf")
    "3d367743f371f28671d2764e911a53d7c20ec9b6aa8791d059e7090389fc52a5")
)

(family "Noto Serif" "noto-serif"
  (source "Noto Serif (unhinted), https://github.com/notofonts/latin-greek-cyrillic")
  (license "SIL Open Font License 1.1" "OFL.txt"
    (url "https://raw.githubusercontent.com/notofonts/latin-greek-cyrillic/0ef94805d19e98ed658543a7c48c0a4f19cc0ac0/OFL.txt")
    "cee9892f9f0cc8fe882c9e9537ee6a89621d86ee7ceaf70b02e2b2b1c25c061a")
  (face 400 #f "NotoSerif-Regular.ttf"
    (url "https://raw.githubusercontent.com/notofonts/notofonts.github.io/c1d3718e2a0eb25c2567a694ee017061fdaa5f51/fonts/NotoSerif/unhinted/ttf/NotoSerif-Regular.ttf")
    "a15cfbbc1539d707115111d672d590a3d70d4f74b4c0a315956da20ae19a14e1")
  (face 700 #f "NotoSerif-Bold.ttf"
    (url "https://raw.githubusercontent.com/notofonts/notofonts.github.io/c1d3718e2a0eb25c2567a694ee017061fdaa5f51/fonts/NotoSerif/unhinted/ttf/NotoSerif-Bold.ttf")
    "24ad531e6b05ddad8c3d89572d2c93eb86a6b74e652ce7ee3c3e171de68e84c3")
  (face 400 #t "NotoSerif-Italic.ttf"
    (url "https://raw.githubusercontent.com/notofonts/notofonts.github.io/c1d3718e2a0eb25c2567a694ee017061fdaa5f51/fonts/NotoSerif/unhinted/ttf/NotoSerif-Italic.ttf")
    "c4b3c971741ecdb40f5a443bce754e8fe91efe761b6ea10c92be7c3597cdadc4")
  (face 700 #t "NotoSerif-BoldItalic.ttf"
    (url "https://raw.githubusercontent.com/notofonts/notofonts.github.io/c1d3718e2a0eb25c2567a694ee017061fdaa5f51/fonts/NotoSerif/unhinted/ttf/NotoSerif-BoldItalic.ttf")
    "1bc4f86502eaa368718f6192bee022ea9a703d5af1c18b7d291212657b63074a")
)

(family "Carlito" "carlito"
  (source "Carlito 1.104 (metric-compatible with Calibri), https://github.com/googlefonts/carlito")
  (license "SIL Open Font License 1.1" "OFL.txt"
    (url "https://raw.githubusercontent.com/googlefonts/carlito/3a810cab78ebd6e2e4eed42af9e8453c4f9b850a/OFL.txt")
    "58402f82a7c332a700294988fe7554fbb0a63a8d27ccc1ee3bbc640311990a00")
  (face 400 #f "Carlito-Regular.ttf"
    (url "https://raw.githubusercontent.com/googlefonts/carlito/3a810cab78ebd6e2e4eed42af9e8453c4f9b850a/fonts/ttf/Carlito-Regular.ttf")
    "f6418f708baede9789daef5d458c0f53d2a888af9820e8062934e504fedc6595")
  (face 700 #f "Carlito-Bold.ttf"
    (url "https://raw.githubusercontent.com/googlefonts/carlito/3a810cab78ebd6e2e4eed42af9e8453c4f9b850a/fonts/ttf/Carlito-Bold.ttf")
    "bb5d20f79b82599ec72983597437373a80f2d2085fa91fc144fd74e876a594db")
  (face 400 #t "Carlito-Italic.ttf"
    (url "https://raw.githubusercontent.com/googlefonts/carlito/3a810cab78ebd6e2e4eed42af9e8453c4f9b850a/fonts/ttf/Carlito-Italic.ttf")
    "0b019225e58d702bfedcbd35c21696769f8ee115cb6343f84c2f240312450d1c")
  (face 700 #t "Carlito-BoldItalic.ttf"
    (url "https://raw.githubusercontent.com/googlefonts/carlito/3a810cab78ebd6e2e4eed42af9e8453c4f9b850a/fonts/ttf/Carlito-BoldItalic.ttf")
    "b32928186c119599e03ca6a1ffc680fdcb7fac95772f4b95d989cf6cd3861517"))

(family "IBM Plex Sans" "ibm-plex-sans"
  (source "IBM Plex (@ibm/plex-sans 1.1.0 tree), https://github.com/IBM/plex")
  (license "SIL Open Font License 1.1" "LICENSE.txt"
    (url "https://raw.githubusercontent.com/IBM/plex/1da12f02587b630c07e92692d21492d722f53614/LICENSE.txt")
    "7e6b2818edbd8f6a01ae80641cc8f16a51080d08fb4e532be3a0b6f74adb07da")
  (face 400 #f "IBMPlexSans-Regular.ttf"
    (url "https://raw.githubusercontent.com/IBM/plex/1da12f02587b630c07e92692d21492d722f53614/packages/plex-sans/fonts/complete/ttf/IBMPlexSans-Regular.ttf")
    "975dcda37d80f038dcd143c22e33ca2d97a0cc5a929aace1c749153b0fe1afa5")
  (face 700 #f "IBMPlexSans-Bold.ttf"
    (url "https://raw.githubusercontent.com/IBM/plex/1da12f02587b630c07e92692d21492d722f53614/packages/plex-sans/fonts/complete/ttf/IBMPlexSans-Bold.ttf")
    "9e6c74a889a700d707613d24548fe4ffa6bc59559a0689d2cf9e133bdcdafb2f")
  (face 400 #t "IBMPlexSans-Italic.ttf"
    (url "https://raw.githubusercontent.com/IBM/plex/1da12f02587b630c07e92692d21492d722f53614/packages/plex-sans/fonts/complete/ttf/IBMPlexSans-Italic.ttf")
    "a9c6ef9942c49e49d11e11a6dacc0b3a087978757e9b22a06b8ac22a6400fb15")
  (face 700 #t "IBMPlexSans-BoldItalic.ttf"
    (url "https://raw.githubusercontent.com/IBM/plex/1da12f02587b630c07e92692d21492d722f53614/packages/plex-sans/fonts/complete/ttf/IBMPlexSans-BoldItalic.ttf")
    "0e3142ba2ef31fe5c02f0c6c36424f251609cd6b73880076e21c2e81931ba2b9")
)

(family "IBM Plex Serif" "ibm-plex-serif"
  (source "IBM Plex (@ibm/plex-sans 1.1.0 tree), https://github.com/IBM/plex")
  (license "SIL Open Font License 1.1" "LICENSE.txt"
    (url "https://raw.githubusercontent.com/IBM/plex/1da12f02587b630c07e92692d21492d722f53614/LICENSE.txt")
    "7e6b2818edbd8f6a01ae80641cc8f16a51080d08fb4e532be3a0b6f74adb07da")
  (face 400 #f "IBMPlexSerif-Regular.ttf"
    (url "https://raw.githubusercontent.com/IBM/plex/1da12f02587b630c07e92692d21492d722f53614/packages/plex-serif/fonts/complete/ttf/IBMPlexSerif-Regular.ttf")
    "3764f5ddda8c687a765d0105e2a31cd311fca244239b878cb59fedb069a14dbb")
  (face 700 #f "IBMPlexSerif-Bold.ttf"
    (url "https://raw.githubusercontent.com/IBM/plex/1da12f02587b630c07e92692d21492d722f53614/packages/plex-serif/fonts/complete/ttf/IBMPlexSerif-Bold.ttf")
    "acb1a816c739eaf36081cb261fe150b1e346276c05c97290fc3cd47e3d011866")
  (face 400 #t "IBMPlexSerif-Italic.ttf"
    (url "https://raw.githubusercontent.com/IBM/plex/1da12f02587b630c07e92692d21492d722f53614/packages/plex-serif/fonts/complete/ttf/IBMPlexSerif-Italic.ttf")
    "5a7cbdf597f07afe86e9079de2c460602cfc414eb9e757c0d4b05848212b1e51")
  (face 700 #t "IBMPlexSerif-BoldItalic.ttf"
    (url "https://raw.githubusercontent.com/IBM/plex/1da12f02587b630c07e92692d21492d722f53614/packages/plex-serif/fonts/complete/ttf/IBMPlexSerif-BoldItalic.ttf")
    "a34a88576d3226c582e8d9cd0de7f592c056d974074934b94873ae2149113aed")
)

(family "IBM Plex Mono" "ibm-plex-mono"
  (source "IBM Plex (@ibm/plex-sans 1.1.0 tree), https://github.com/IBM/plex")
  (license "SIL Open Font License 1.1" "LICENSE.txt"
    (url "https://raw.githubusercontent.com/IBM/plex/1da12f02587b630c07e92692d21492d722f53614/LICENSE.txt")
    "7e6b2818edbd8f6a01ae80641cc8f16a51080d08fb4e532be3a0b6f74adb07da")
  (face 400 #f "IBMPlexMono-Regular.ttf"
    (url "https://raw.githubusercontent.com/IBM/plex/1da12f02587b630c07e92692d21492d722f53614/packages/plex-mono/fonts/complete/ttf/IBMPlexMono-Regular.ttf")
    "fe11304a5fe956d5744e9b6a246cc83d90425245e75a62230044966ca96a7f50")
  (face 700 #f "IBMPlexMono-Bold.ttf"
    (url "https://raw.githubusercontent.com/IBM/plex/1da12f02587b630c07e92692d21492d722f53614/packages/plex-mono/fonts/complete/ttf/IBMPlexMono-Bold.ttf")
    "ca403c56931baef307d20ba64b69acb71abcad61f75e66414661d57484b690ec")
  (face 400 #t "IBMPlexMono-Italic.ttf"
    (url "https://raw.githubusercontent.com/IBM/plex/1da12f02587b630c07e92692d21492d722f53614/packages/plex-mono/fonts/complete/ttf/IBMPlexMono-Italic.ttf")
    "8ebe04c8c6cc82f0be19896ddc61d9935cdd0f027b0173c1945b8d247d7dfc2a")
  (face 700 #t "IBMPlexMono-BoldItalic.ttf"
    (url "https://raw.githubusercontent.com/IBM/plex/1da12f02587b630c07e92692d21492d722f53614/packages/plex-mono/fonts/complete/ttf/IBMPlexMono-BoldItalic.ttf")
    "0e45a5a540992163229d2a29662553f313fab391757ca2ab3dc8f4e0d9be0979"))
