#!/usr/bin/env bash
# Pack a built violet 4.14 kernel into an AnyKernel3 flashable zip.
#
# Run after ./build-violet.sh. violet is non-A/B with a boot header v2 image
# that carries the DTB, plus a separate dtbo partition, so the zip ships
# Image.gz, dtb and dtbo.img: the kernel and DTB in boot are replaced and the
# ramdisk is left untouched (split_boot + flash_boot), then dtbo is flashed.
# See anykernel/anykernel.sh.
#
# Usage:
#   ./flashable-zip-gen.sh                  # uses ./out
#   KOUT=/path/out ./flashable-zip-gen.sh   # kernel output dir from build-violet.sh
#   ZIP_NAME=foo.zip ./flashable-zip-gen.sh # override zip file name
#
# Flash: adb reboot sideload && adb sideload <zip>  (or install from recovery)
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
TC="${TC:-$HOME/tc}"
# Not $OUT: after `lunch` that is the ROM product dir.
KOUT="${KOUT:-$SRC_DIR/out}"
BOOT="$KOUT/arch/arm64/boot"
IMAGE="$BOOT/Image.gz"
DTBO="$BOOT/dtbo.img"
# Pinned AnyKernel3, cached under $TC.
AK3_URL="${AK3_URL:-https://github.com/osm0sis/AnyKernel3}"
AK3_COMMIT="${AK3_COMMIT:-41f04bdb4ee30a44e429c2c1131d5e8bb32b15f1}"
AK3_DIR="$TC/AnyKernel3"

for f in "$IMAGE" "$DTBO"; do
    [ -f "$f" ] || { echo "ERROR: $f not found; run ./build-violet.sh first" >&2; exit 1; }
done
# Same as the ROM's dtb.img (TARGET_DTB_LIST_WILDCARD defaults to *): every
# built .dtb, sorted and concatenated.
mapfile -t DTBS < <(find "$BOOT/dts" -type f -name '*.dtb' | sort)
[ "${#DTBS[@]}" -gt 0 ] || { echo "ERROR: no .dtb under $BOOT/dts" >&2; exit 1; }
command -v zip >/dev/null || { echo "ERROR: zip not installed" >&2; exit 1; }

mkdir -p "$TC"
if [ ! -d "$AK3_DIR/.git" ]; then
    git clone -q "$AK3_URL" "$AK3_DIR"
fi
if ! git -C "$AK3_DIR" cat-file -e "$AK3_COMMIT^{commit}" 2>/dev/null; then
    git -C "$AK3_DIR" fetch -q origin
fi

STAGE="$KOUT/anykernel"
rm -rf "$STAGE"
mkdir -p "$STAGE"
git -C "$AK3_DIR" archive "$AK3_COMMIT" | tar -x -C "$STAGE"
rm -rf "$STAGE/README.md" "$STAGE/modules" "$STAGE/patch" "$STAGE/ramdisk"
cp "$SRC_DIR/anykernel/anykernel.sh" "$STAGE/anykernel.sh"
cp "$IMAGE" "$STAGE/Image.gz"
cat "${DTBS[@]}" > "$STAGE/dtb"
cp "$DTBO" "$STAGE/dtbo.img"

ZIP_NAME="${ZIP_NAME:-ksu-violet-4.14-$(git -C "$SRC_DIR" rev-parse --short=12 HEAD)-$(date -u +%Y%m%d-%H%M).zip}"
ZIP="$KOUT/$ZIP_NAME"
rm -f "$ZIP"
(cd "$STAGE" && zip -qr9 "$ZIP" . -x '.git*')

echo "[done] zip: $ZIP"
echo "       sha256: $(sha256sum "$ZIP" | cut -d' ' -f1)"
echo "       flash: adb reboot sideload && adb sideload $ZIP_NAME"
