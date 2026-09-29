#!/bin/bash
# Assembles Flowgorithm.app (Apple Silicon) and the distribution DMG in dist/.
# Requires: scripts/build-wine.sh (engine in work/wine-install).
source "$(dirname "$0")/common.sh"

BUNDLE_ID=com.macgorithm.flowgorithm
INST="$WORK/wine-install"
[ -x "$INST/bin/wine" ] || { echo "!! run scripts/build-wine.sh first" >&2; exit 1; }
STAGE="$WORK/stage"; APP="$STAGE/Flowgorithm.app"
C="$APP/Contents"; RES="$C/Resources"
ENGINE="$RES/Engine/Flowgorithm.app"; EW="$ENGINE/Contents/Resources/wine"
rm -rf "$STAGE"; mkdir -p "$C/MacOS" "$RES/Flowgorithm" "$ENGINE/Contents/MacOS" "$EW"

subst() { sed "s#@VERSION@#$APP_VERSION#g; s#@MIN_MACOS@#$MIN_MACOS#g; s#@BUNDLE_ID@#$BUNDLE_ID#g; s#@PREFIX@#prefix-arm64#g" "$1" > "$2"; }

# --- Wine engine (nested bundle: the Flowgorithm process takes its name and icon from it)
rsync -a --exclude '*.a' "$INST/bin" "$INST/lib" "$INST/share" "$EW/"
f=$(fetch "$MONO_URL" "$MONO_SHA"); mkdir -p "$EW/share/wine/mono"; tar -xf "$f" -C "$EW/share/wine/mono"
cp "$WORK/deps/lib/libfreetype.6.dylib" "$EW/lib/"
find "$EW/lib/wine/aarch64-windows" -type f -exec "$WORK/toolchain/bin/llvm-strip" --strip-debug {} + 2>/dev/null || true
for so in "$EW"/lib/wine/aarch64-unix/*.so; do
  strip -S "$so" 2>/dev/null || true
  otool -l "$so" | grep -q '@loader_path/../../ ' || install_name_tool -add_rpath @loader_path/../../ "$so" 2>/dev/null
done
LOADER="$EW/lib/wine/aarch64-unix/wine"
strip -S "$LOADER" "$EW/bin/wineserver" 2>/dev/null || true
# x18: the kernel preserves it for binaries built with SDK < 13 ("legacy" override, macOS 13-26)
vtool -set-build-version macos 11.0 12.3 -replace -output "$LOADER.tmp" "$LOADER" 2>/dev/null && mv "$LOADER.tmp" "$LOADER"
chmod +x "$LOADER"
ln -s ../Resources/wine/lib/wine/aarch64-unix/wine "$ENGINE/Contents/MacOS/wine"
subst "$ROOT/resources/Engine-Info.plist.in" "$ENGINE/Contents/Info.plist"
cp "$ROOT/resources/Flowgorithm.icns" "$ENGINE/Contents/Resources/"

# --- native launcher and file panel
SWIFTFLAGS=(-O -target "arm64-apple-macos$MIN_MACOS")
swiftc "${SWIFTFLAGS[@]}" -o "$C/MacOS/Flowgorithm" "$ROOT/launcher/Launcher.swift"
FP="$RES/FilePanel.app/Contents"; mkdir -p "$FP/MacOS" "$FP/Resources"
swiftc "${SWIFTFLAGS[@]}" -o "$FP/MacOS/FilePanel" "$ROOT/launcher/FilePanel.swift"
subst "$ROOT/resources/FilePanel-Info.plist.in" "$FP/Info.plist"
cp "$ROOT/resources/Flowgorithm.icns" "$FP/Resources/"

# --- Flowgorithm (official, unmodified executable), metadata, licenses
f=$(fetch "$FLOWGORITHM_URL" "$FLOWGORITHM_SHA"); unzip -q -o "$f" -d "$RES/Flowgorithm"
subst "$ROOT/resources/Info.plist.in" "$C/Info.plist"
cp "$ROOT/resources/Flowgorithm.icns" "$ROOT/resources/NOTICE.txt" "$RES/"
cp -R "$ROOT/licenses" "$RES/licenses"
cp "$ROOT/LICENSE" "$RES/licenses/Wrapper-LICENSE.txt"

# --- ad-hoc signing: each Mach-O on its own, the loader with its entitlements, then the bundles
xattr -cr "$APP"
find "$EW" -type f \( -perm +111 -o -name '*.so' -o -name '*.dylib' \) -print0 | while IFS= read -r -d '' f; do
  if file -b "$f" | grep -q Mach-O; then codesign -f -s - "$f" 2>/dev/null; fi
done
codesign -f -s - --entitlements "$ROOT/resources/wine.entitlements" "$LOADER"
codesign -f -s - "$RES/FilePanel.app"
codesign -f -s - "$APP"
codesign --verify --strict "$APP" && echo ">> signature OK"

# --- DMG: drag Flowgorithm to Applications
DMG="$ROOT/dist/Flowgorithm-$APP_VERSION-AppleSilicon.dmg"; mkdir -p "$ROOT/dist"; rm -f "$DMG"
ln -s /Applications "$STAGE/Applications"
hdiutil create -quiet -volname "Flowgorithm $APP_VERSION" -srcfolder "$STAGE" -fs HFS+ -format ULMO "$DMG"
rm "$STAGE/Applications"
( cd "$(dirname "$DMG")" && shasum -a 256 "$(basename "$DMG")" | tee "$(basename "$DMG").sha256" )
echo "OK: $DMG"
