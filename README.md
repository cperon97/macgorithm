# Macgorithm — Flowgorithm for macOS on Apple Silicon (native ARM64)

An **unofficial** wrapper that runs [Flowgorithm](https://www.flowgorithm.org) 4.5 (the official, unmodified Windows executable) on Macs with Apple chips **without Rosetta 2**: both Wine and the .NET runtime (Wine Mono) are built for ARM64.

> Flowgorithm is freeware by Devin Cook. This project is not affiliated with or endorsed by the author.
> For Intel Macs (or as a Rosetta-based alternative) there is a separate version: [macgorithm-intel](https://github.com/cperon97/macgorithm-intel).

## Download and installation

1. Download `Flowgorithm-4.5-AppleSilicon.dmg` from the [latest release](https://github.com/cperon97/macgorithm/releases/latest) (its SHA-256 checksum is attached to the release as `Flowgorithm-4.5-AppleSilicon.dmg.sha256`).
2. Open the DMG and **drag Flowgorithm into the Applications folder**.
3. On first launch macOS blocks the app: follow [Unblocking the app on first launch](#unblocking-the-app-on-first-launch) (needed only once).
4. "Setting up Flowgorithm…" appears for a few seconds while the Wine environment is created. Later launches are immediate.

**Requirements:** a Mac with an Apple chip (M1 or later), **macOS 14 Sonoma or later**. Tested on macOS 26.5.1.

## Unblocking the app on first launch

The app is not (yet) signed with an Apple Developer certificate or notarized by Apple. On first launch macOS therefore shows a warning such as *"Apple could not verify “Flowgorithm” is free of malware"* and refuses to open it. You only need to unblock it **once**, in one of these ways.

**macOS 15 Sequoia and later**

1. Open Flowgorithm from the Applications folder. When the warning appears, click **Done** (not "Move to Trash").
2. Open **System Settings → Privacy & Security**.
3. Scroll down to the **Security** section: you will see *"“Flowgorithm” was blocked…"*. Click **Open Anyway**.
4. Confirm with your password or Touch ID, then click **Open** in the final dialog.

The **Open Anyway** button stays visible for about an hour after the blocked launch: if you can't find it, open Flowgorithm again and go back to System Settings.

**macOS 14 Sonoma**

In the Applications folder, right-click (or Control-click) Flowgorithm → **Open**, then **Open** again in the dialog. The steps above work as well.

**Alternatively, from Terminal** (any macOS version): this removes the "quarantine" attribute macOS adds to files downloaded from the internet.

```bash
xattr -dr com.apple.quarantine /Applications/Flowgorithm.app
```

> **Why is this needed?** macOS opens apps without warnings only if they are notarized by Apple, a service reserved to members of the paid Apple Developer Program. This project's code is public and the DMG can be rebuilt with the scripts in this repository. To check that you downloaded the original file, compare the output of this command with the `Flowgorithm-4.5-AppleSilicon.dmg.sha256` file attached to the release:
>
> ```bash
> shasum -a 256 ~/Downloads/Flowgorithm-4.5-AppleSilicon.dmg
> ```

## Features

- Native ARM64 execution: every process shows as "Apple" in Activity Monitor (no Rosetta).
- Double-click **`.fprg`** files in the Finder to open them in Flowgorithm (even while it is already running).
- **Native macOS Open/Save panels** instead of the Windows ones.
- Flowgorithm's name and icon in the Dock and menu bar.
- Readable UI in all 40 Flowgorithm languages (Chinese, Japanese, Korean, Thai, Tamil… through the macOS system fonts).
- The small first-launch window and error messages follow the system language (English or Italian).

## Where your data lives / uninstalling

- Wine environment and settings: `~/Library/Application Support/Flowgorithm/prefix-arm64`
- Diagnostic log: `~/Library/Logs/Flowgorithm.log`

To uninstall, delete `Flowgorithm.app` from Applications and the `~/Library/Application Support/Flowgorithm` folder.

## Known limitations

- Each file opened from the Finder opens a new Flowgorithm window (instance), with its own Dock icon.
- The mechanism that lets Wine run natively on macOS (preserving the x18 register, see [docs/TECHNICAL.md](docs/TECHNICAL.md)) is kernel behavior that Apple could change in future macOS versions.
- Not notarized (that requires an Apple Developer account).

## Building from source

Requires the Xcode Command Line Tools and Homebrew (`bison` and `flex` are installed automatically). Every input is downloaded and verified against a pinned SHA-256 (`scripts/config.sh`).

```bash
scripts/build-wine.sh   # ARM64 Wine (citi94 fork + patches/) and FreeType, about 10 minutes
scripts/make-app.sh     # assembles the app, signs it ad-hoc, creates dist/*.dmg (published as Release assets)
```

## How it works

ARM64 Wine 11.10 ([citi94/wine-macos-arm64](https://github.com/citi94/wine-macos-arm64)) with 5 patches in `patches/`, ARM64 Wine Mono 11.3.0, and a native Swift launcher (`launcher/`). Technical details, diagnosis and design choices: [docs/TECHNICAL.md](docs/TECHNICAL.md). Component licenses: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Licenses

- Code in this repository (launcher, scripts, documentation): [MIT](LICENSE).
- Wine patches (`patches/`): LGPL 2.1 or later, like Wine.
- **Flowgorithm** belongs to Devin Cook and is governed by its [EULA](licenses/Flowgorithm-EULA.pdf): freeware, free to use and install; **commercial redistribution is not allowed** (this package may not be sold or rented). By downloading and installing Flowgorithm you accept its EULA.
- Other components: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
