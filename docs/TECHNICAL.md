# Technical notes — native Flowgorithm on Apple Silicon

## Goal

Run Flowgorithm's official .NET/WinForms executable without translating any x86 code: both the Wine engine **and** the .NET runtime (Wine Mono) are ARM64.
`Flowgorithm.exe` is a PE32 i386 image, but its CLR header is `ILONLY` without `32BITREQUIRED` (AnyCPU): it is IL bytecode that an ARM64 Mono can run.

## Components

| | |
|---|---|
| Engine | Wine 11.10, fork [citi94/wine-macos-arm64](https://github.com/citi94/wine-macos-arm64) (`macos-arm64-port`), `aarch64`-only build |
| PE toolchain | llvm-mingw 20260922 |
| .NET | Wine Mono 11.3.0 arm64 (first release with an ARM64 port of Mono) |
| Fonts | FreeType 2.14.3 built for macOS 14 |
| Launcher | Swift (`launcher/`) |

No ready-made native ARM64 Wine engine was available (Gcenx/WineHQ: x86_64 only; CrossOver ARM64: proprietary).

## Problem 1 — the x18 register

Windows on ARM64 uses **x18** as the TEB pointer; the macOS kernel zeroes it on every exception and context switch.
Without a fix, `wineboot` spins at 100% CPU (PE code dereferences a NULL TEB).

According to the XNU sources (`osfmk/arm64/machine_task.c`, `pcb.c`, `locore.s`) the kernel preserves x18:
- for processes linked against an **SDK older than 13.0** (the "legacy" override, present in macOS 14 `xnu-10002/10063`, 15 `xnu-11215/11417` and 26 `xnu-12377`);
- on macOS 26.4+, with the `com.apple.security.custom-x18-abi-toggle` entitlement and the public `os_set_custom_x18_abi_enabled()` API (`<os/arch/arm64.h>`).

Fix: the Wine loader is marked with SDK 12.3 (`vtool -set-build-version macos 11.0 12.3`) and signed with the entitlement; patch 0003 also enables the API when it is available.
Tests in `tests/`: without the fix x18 is lost 100% of the time; with the legacy SDK or the entitlement, never.

## Wine patches (`patches/`)

| Patch | What it does |
|---|---|
| 0001 | mscoree/appwiz from upstream: Wine Mono 11.3.0, `libmono-2.0-arm64.dll` |
| 0002 | wineserver: on an aarch64-only build, accept **IL-only AnyCPU** PE32 i386 images (as Windows on ARM64 does), including COR header 2.0 (Mono's `Accessibility.dll`) |
| 0003 | ntdll: detect x18 preservation (bit 48 of `TPIDR_EL0` on macOS 26, a syscall probe on 14/15) and in that case skip the fork's trampoline, which **clobbered x16** when returning from signals and crashed Mono's JIT (jump into an empty page → illegal instruction); enable the custom-x18 API per thread |
| 0004 | Uniscribe: `ScriptShape` returns `USP_E_SCRIPT_NOT_IN_FONT` when the font has no glyphs for the run → Thai uses font linking instead of boxes |
| 0005 | comdlg32 (`IFileDialog::Show`): when `MACGORITHM_FILE_PANEL` points to a helper, show the native `NSOpenPanel`/`NSSavePanel` through `__wine_unix_spawnvp`, set the result and call `OnFileOk` (required by WinForms); otherwise use Wine's dialog |

## App layout

```
Flowgorithm.app/Contents/
  MacOS/Flowgorithm                    Swift launcher (LSUIElement, receives .fprg files from the Finder)
  Resources/Engine/Flowgorithm.app/    "engine": nested bundle carrying Flowgorithm's name and icon
      Contents/MacOS/wine -> ../Resources/wine/lib/wine/aarch64-unix/wine
      Contents/Resources/wine/         Wine + Wine Mono + FreeType
  Resources/FilePanel.app/             native Open/Save panel helper
  Resources/Flowgorithm/Flowgorithm.exe
```

- The Flowgorithm process is started through the symlink inside the "engine" bundle: AppKit associates it with that bundle, so the Dock and menu bar show "Flowgorithm" instead of "wine". (A bundle whose executable is a symlink cannot be signed on its own: it is sealed as a resource of the app, while the loader is signed individually with its entitlements.)
- The launcher stays alive (invisible) while any Flowgorithm window is open, to receive documents opened from the Finder.
- On first launch it creates the prefix and sets up font fallbacks (`FontLink\SystemLink` to Hiragino Sans GB, Apple SD Gothic Neo, Ayuthaya, Tamil Sangam MN, Kohinoor, Arial Unicode). The `.reg` file is written as UTF-16LE with a BOM: in ANSI files Wine mangles `hex(7)` data.
- FreeType is bundled and found through the `@loader_path/../../` rpath of the unix modules (as in Gcenx's builds): without it Wine only has bitmap fonts and text is unreadable.

## Build notes

- flowgorithm.org serves an invalid TLS certificate: `scripts/common.sh` retries downloads without TLS verification, which is safe because every file is checked against the pinned SHA-256.
- The build was verified from a clean clone: the rebuilt DMG contains exactly the same files as the published one.

## Harmless messages in the log

- `map_fixed_area … 0x400000 / 0x10000000`: nothing can be mapped below 4 GB on arm64 macOS, so images are relocated.
- `193` errors from the x86 helpers in Mono's MSI: they cannot run on an ARM64-only engine and are not needed.

## Ideas for the future

- Submit patches 0002/0004 to WineHQ (with tests), and 0003 plus the x16 bug to the fork.
- GitHub Actions CI on arm64 `macos` runners: build, headless launch test (`vmmap` → Code Type ARM64), DMG as a Release asset.
- Developer ID signing + notarization.
