#!/bin/bash
# Prepara un arbol AOSP gingerbread para compilar cooper (Galaxy Ace GT-S5830).
# Ejecutar desde la raiz del arbol AOSP, DESPUES de repo sync.
set -e

echo ">>> 1/3  Agregando la variante de arquitectura armv6-vfp"
# AOSP gingerbread solo trae armv4t, armv5te, armv5te-vfp, armv7-a y armv7-a-neon.
# El Ace declara TARGET_ARCH_VARIANT := armv6-vfp, que lo agrego CyanogenMod.
# Sin este archivo el build muere con "Cannot locate config makefile for
# product arch variant armv6-vfp".
cat > build/core/combo/arch/arm/armv6-vfp.mk <<'EOF'
# Configuration for Linux on ARM.
# Generating binaries for the ARMv6 architecture (arm1136jf-s) with VFP.
#
ARCH_ARM_HAVE_THUMB_SUPPORT     := true
ARCH_ARM_HAVE_FAST_INTERWORKING := true
ARCH_ARM_HAVE_64BIT_DATA        := true
ARCH_ARM_HAVE_HALFWORD_MULTIPLY := true
ARCH_ARM_HAVE_CLZ               := true
ARCH_ARM_HAVE_FFS               := true
ARCH_ARM_HAVE_VFP               := true

ifeq ($(strip $(TARGET_ARCH_VARIANT_FPU)),)
TARGET_ARCH_VARIANT_FPU         := vfp
endif
ifeq ($(strip $(TARGET_ARCH_VARIANT_CPU)),)
TARGET_ARCH_VARIANT_CPU         := arm1136jf-s
endif

arch_variant_cflags := \
    -mcpu=$(TARGET_ARCH_VARIANT_CPU) \
    -mfloat-abi=softfp \
    -mfpu=$(TARGET_ARCH_VARIANT_FPU) \
    -D__ARM_ARCH_5__ \
    -D__ARM_ARCH_5T__ \
    -D__ARM_ARCH_5E__ \
    -D__ARM_ARCH_5TE__
EOF

echo ">>> 2/3  Sacando paquetes que solo existen en CyanogenMod"
# Estas apps/binarios viven en repos de CM (packages/apps/FM, Torch,
# SamsungServiceMode, system/extras/rzscontrol). En AOSP puro no existen y el
# build falla con "Module not defined".
DEV=device/samsung/cooper/device_cooper.mk
cp -n $DEV $DEV.orig
for pkg in FM Torch rzscontrol SamsungServiceMode screencap; do
    sed -i "/^[[:space:]]*${pkg}[[:space:]]*\\\\\?$/d" $DEV
done
# BOARD_USE_SCREENCAP es un hook de CM, en AOSP no hace nada pero lo sacamos
sed -i 's/^BOARD_USE_SCREENCAP/#BOARD_USE_SCREENCAP/' device/samsung/cooper/BoardConfig.mk

echo ">>> 3/3  Listo. Paquetes removidos de PRODUCT_PACKAGES:"
diff $DEV.orig $DEV || true

cat <<'EOF'

Siguiente paso:
  . build/envsetup.sh
  lunch cooper-eng
  make -j$(nproc) otapackage

Si falla por "libOmxCore" o "libOmxVidEnc", sacalos tambien de
device/samsung/cooper/device_cooper.mk: son modulos que CM construia desde su
fork de hardware/msm7k y los blobs ya los copian igual.
EOF
