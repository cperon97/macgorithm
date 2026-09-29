# Third-party components

The DMG published in the GitHub Releases redistributes the following components. License texts are in `licenses/` (also copied inside the app, in `Contents/Resources/licenses`).

| Component | Version | License | Source |
|---|---|---|---|
| Flowgorithm (Windows executable, unmodified) | 4.5 | Freeware © Devin Cook — [EULA](licenses/Flowgorithm-EULA.pdf): free to use, no commercial redistribution | https://www.flowgorithm.org |
| Wine (macOS ARM64 fork) + `patches/` | 11.10, commit `0cc8848b607572cfeacf3e550ef696bd63a43955` | LGPL 2.1 or later | https://github.com/citi94/wine-macos-arm64 + `patches/` in this repository |
| Wine Mono | 11.3.0 (arm64) | MIT / LGPL / others (see `licenses/WineMono-COPYING`) | https://github.com/wine-mono/wine-mono/releases/tag/wine-mono-11.3.0 |
| FreeType | 2.14.3 | FreeType License (FTL) or GPLv2 | https://download.savannah.gnu.org/releases/freetype/ |

**Corresponding Wine source (LGPL):** the bundled engine can be rebuilt exactly from the commit above by applying the patches in `patches/` with `scripts/build-wine.sh`.

The launcher (`launcher/Launcher.swift`) and the file panel (`launcher/FilePanel.swift`) are part of this repository (MIT license, `LICENSE`).
