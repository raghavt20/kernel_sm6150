### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers
## violet (Redmi Note 7 Pro): kernel + DTB into boot, then dtbo.
## Non-A/B, boot header v2: the DTB lives in boot and the ramdisk is left untouched.

### AnyKernel setup
# global properties
properties() { '
kernel.string=KernelSU-Next kernel for violet (4.14)
do.devicecheck=1
do.modules=0
do.systemless=0
do.cleanup=1
do.cleanuponabort=0
device.name1=violet
device.name2=
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties


### AnyKernel install
# boot shell variables
BLOCK=boot;
IS_SLOT_DEVICE=0;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh;

# boot install: replace the kernel (Image.gz) and DTB (dtb), keep the ramdisk as-is
split_boot;

flash_boot;

# dtbo partition (dtbo.img)
flash_generic dtbo;
## end boot install
