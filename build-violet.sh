#!/usr/bin/env bash
# Standalone build for the violet 4.14 kernel (branch: seventeen / seventeen-ksu).
#
# Sets up an AOSP Clang toolchain under $TC (default: $HOME/tc) and builds
# Image.gz + dtbs + dtbo.img with LLVM, the same way the PixelOS ROM build does
# (LLVM=1 LLVM_IAS=1); pack them with ./flashable-zip-gen.sh. Run on a Linux
# build host: a macOS checkout cannot build this kernel (case-insensitive FS,
# no Linux/ELF toolchain).
#
# Usage:
#   ./build-violet.sh                 # build with defaults
#   JOBS=48 ./build-violet.sh         # override parallelism
#   KOUT=/path/out ./build-violet.sh  # override output dir (default: ./out)
#   TC=/data/tc ./build-violet.sh     # override toolchain dir
#   CLANG_SRC=/path/to/clang-r596125 ./build-violet.sh   # copy clang from here
#   CLANG_URL=https://.../clang-r596125.tar.gz ./build-violet.sh  # or download
set -euo pipefail

# --- config (all overridable from the environment) ---
TC="${TC:-$HOME/tc}"
CLANG_VERSION="${CLANG_VERSION:-r596125}"            # PixelOS 17 default clang
CLANG_DIR="$TC/clang-$CLANG_VERSION"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 8)}"
# Not $OUT: after `lunch` that is the ROM product dir (e.g. out/target/product/violet).
KOUT="${KOUT:-$(cd "$(dirname "$0")" && pwd)/out}"
DEFCONFIG="${DEFCONFIG:-violet_defconfig}"
# An already-present AOSP clang to copy from if $CLANG_DIR is empty.
# The PixelOS build server keeps exactly this version here:
CLANG_SRC="${CLANG_SRC:-$HOME/pos/prebuilts/clang/host/linux-x86/clang-$CLANG_VERSION}"
# Optional direct tarball URL (a clang-$CLANG_VERSION.tar.gz) if no local copy.
CLANG_URL="${CLANG_URL:-}"

KROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$KROOT"

# --- toolchain setup ($TC) ---
setup_clang() {
    if [ -x "$CLANG_DIR/bin/clang" ]; then
        echo "[tc] clang $CLANG_VERSION already at $CLANG_DIR"
        return
    fi
    mkdir -p "$TC"
    if [ -x "$CLANG_SRC/bin/clang" ]; then
        echo "[tc] copying clang $CLANG_VERSION from $CLANG_SRC"
        cp -a "$CLANG_SRC" "$CLANG_DIR"
    elif [ -n "$CLANG_URL" ]; then
        echo "[tc] downloading clang $CLANG_VERSION from $CLANG_URL"
        mkdir -p "$CLANG_DIR"
        curl -L --fail "$CLANG_URL" | tar -xz -C "$CLANG_DIR"
    else
        cat >&2 <<EOF
ERROR: no clang at $CLANG_DIR, no local copy at
       $CLANG_SRC, and CLANG_URL is unset.
Provide AOSP clang $CLANG_VERSION one of these ways, then re-run:
  - set CLANG_SRC to an existing clang-$CLANG_VERSION dir, or
  - set CLANG_URL to a clang-$CLANG_VERSION.tar.gz to download.
EOF
        exit 1
    fi
    [ -x "$CLANG_DIR/bin/clang" ] || { echo "ERROR: clang still missing after setup" >&2; exit 1; }
}

setup_clang
export PATH="$CLANG_DIR/bin:$PATH"

MAKE_ARGS=(
    O="$KOUT"
    ARCH=arm64
    LLVM=1
    LLVM_IAS=1
    CROSS_COMPILE=aarch64-linux-gnu-
    CROSS_COMPILE_ARM32=arm-linux-gnueabi-   # compat vDSO (CONFIG_COMPAT_VDSO)
    CC=clang
)

echo "[build] clang:     $(clang --version | head -1)"
echo "[build] defconfig: $DEFCONFIG"
echo "[build] jobs:      $JOBS"
echo "[build] out:       $KOUT"

make "${MAKE_ARGS[@]}" "$DEFCONFIG"
make "${MAKE_ARGS[@]}" -j"$JOBS" Image.gz dtbs dtbo.img

echo
echo "[done] kernel: $KOUT/arch/arm64/boot/Image.gz"
echo "[done] dtbs:   $KOUT/arch/arm64/boot/dts/"
echo "[done] dtbo:   $KOUT/arch/arm64/boot/dtbo.img"

echo "[next] flashable zip: KOUT=$KOUT ./flashable-zip-gen.sh"
