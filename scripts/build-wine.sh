#!/bin/bash
# Builds native ARM64 Wine for macOS (citi94 fork + patches/) and FreeType, targeting macOS $MIN_MACOS.
# Output: work/wine-install (ready-to-use engine), consumed by make-app.sh
source "$(dirname "$0")/common.sh"
export MACOSX_DEPLOYMENT_TARGET="$MIN_MACOS"
JOBS="$(sysctl -n hw.ncpu)"

# 1. PE toolchain (llvm-mingw): goes at the END of PATH, its clang must not shadow Apple's
TC="$WORK/toolchain"
if [ ! -x "$TC/bin/aarch64-w64-mingw32-clang" ]; then
  f=$(fetch "$LLVM_MINGW_URL" "$LLVM_MINGW_SHA"); rm -rf "$TC"; mkdir -p "$TC"; tar -xf "$f" -C "$TC" --strip-components=1
fi
brew list bison >/dev/null 2>&1 || brew install bison flex lld
export PATH="/opt/homebrew/opt/bison/bin:/opt/homebrew/opt/flex/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:$TC/bin"

# 2. FreeType (dylib bundled in the app, loaded by Wine at runtime)
DEPS="$WORK/deps"
if [ ! -f "$DEPS/lib/libfreetype.6.dylib" ]; then
  f=$(fetch "$FREETYPE_URL" "$FREETYPE_SHA"); rm -rf "$WORK/freetype-src"; mkdir -p "$WORK/freetype-src"
  tar -xf "$f" -C "$WORK/freetype-src" --strip-components=1
  ( cd "$WORK/freetype-src" && ./configure --prefix="$DEPS" --enable-shared --disable-static \
      --without-png --without-harfbuzz --without-brotli \
      CFLAGS="-O2 -arch arm64 -mmacosx-version-min=$MIN_MACOS" LDFLAGS="-mmacosx-version-min=$MIN_MACOS" >/dev/null \
    && make -j"$JOBS" >/dev/null && make install >/dev/null )
  install_name_tool -id @rpath/libfreetype.6.dylib "$DEPS/lib/libfreetype.6.dylib"
fi

# 3. Wine sources at the pinned commit + patches
SRC="$WORK/wine-src"
if [ ! -d "$SRC/.git" ]; then
  git init -q "$SRC"; git -C "$SRC" remote add origin "$WINE_REPO"
  git -C "$SRC" fetch -q --depth 1 origin "$WINE_COMMIT"; git -C "$SRC" checkout -q FETCH_HEAD
  for p in "$ROOT"/patches/*.patch; do echo ">> patch $(basename "$p")"; git -C "$SRC" apply "$p"; done
fi

# 4. configure + build (aarch64 only: no x86, no Rosetta)
BUILD="$WORK/wine-build"; INST="$WORK/wine-install"; mkdir -p "$BUILD"
cd "$BUILD"
[ -f Makefile ] || PKG_CONFIG_PATH="$DEPS/lib/pkgconfig" "$SRC/configure" \
    --enable-archs=aarch64 --without-x --disable-tests --prefix="$INST" \
    CC="/usr/bin/clang" CFLAGS="-O2 -mmacosx-version-min=$MIN_MACOS" LDFLAGS="-mmacosx-version-min=$MIN_MACOS" > configure.log
make -j"$JOBS" > make.log 2>&1 || { tail -30 make.log; exit 1; }
rm -rf "$INST"; make install > install.log 2>&1
echo "OK: $INST"
