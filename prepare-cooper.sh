#!/bin/bash
# Prepara un arbol AOSP gingerbread para compilar cooper (Galaxy Ace GT-S5830).
# Ejecutar desde la raiz del arbol AOSP, DESPUES de repo sync.
set -e

echo ">>> 0/3  Agregando build/target/product/full_base.mk"
# device_cooper.mk hace: $(call inherit-product, $(SRC_TARGET_DIR)/product/full_base.mk)
# Ese archivo NO existe en AOSP puro (build/target/product/ solo trae full.mk).
# full_base.mk es una separacion que hizo CyanogenMod en su propio fork de
# build/ para reusar la base sin el bloque de PRODUCT_NAME := full de full.mk.
# Sin este archivo el build corta con:
#   "build/target/product/full_base.mk" does not exist. Stop.
#   Don't have a product spec for: 'cooper'
# Es contenido con licencia AOSP (cabecera Apache original), y sus 3
# dependencias (OriginalAudio.mk, all_pico_languages.mk, languages_full.mk)
# ya existen en el arbol AOSP real, asi que es seguro copiarlo tal cual.
cat > build/target/product/full_base.mk <<'EOF'
#
# Copyright (C) 2009 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# This is a build configuration for a full-featured build of the
# Open-Source part of the tree. This is a base configuration to
# bes used for AOSP builds on various target devices.

PRODUCT_PACKAGES := \
    OpenWnn \
    PinyinIME \
    VoiceDialer \
    libWnnEngDic \
    libWnnJpnDic \
    libwnndict

# Additional settings used in all AOSP builds
PRODUCT_PROPERTY_OVERRIDES := \
    keyguard.no_require_sim=true

# Put en_US first in the list, to make it default.
PRODUCT_LOCALES := en_US

# Pick up some sounds - stick with the short list to save space
# on smaller devices.
$(call inherit-product-if-exists, frameworks/base/data/sounds/OriginalAudio.mk)

# Get the TTS language packs
$(call inherit-product-if-exists, external/svox/pico/lang/all_pico_languages.mk)

# Get the list of languages.
$(call inherit-product, $(SRC_TARGET_DIR)/product/languages_full.mk)

$(call inherit-product, $(SRC_TARGET_DIR)/product/generic.mk)
EOF

echo ">>> 1/5  Agregando la variante de arquitectura armv6-vfp"
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

echo ">>> 2/5  Sacando paquetes que solo existen en CyanogenMod"
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

echo ">>> 3/5  Perdonando modulos viejos de hardware/msm7k sin LOCAL_MODULE_TAGS"
# hardware/msm7k se sincroniza porque el manifest default de AOSP lo trae para
# otros telefonos msm7k viejos (Nexus One, HTC Dream). Cooper NO lo usa para
# nada en runtime (usa copybit.cooper, gralloc.cooper propios), PERO su propio
# device/samsung/cooper/libcopybit SI necesita los headers de
# hardware/msm7k/libgralloc para compilar (ver LOCAL_C_INCLUDES en su Android.mk).
#
# Por eso: NO borrar ni tocar hardware/msm7k. La forma correcta de arreglar el
# error "user tag detected on new module" de copybit.msm7k es "perdonarlo" en
# la lista GRANDFATHERED_USER_MODULES (mismo mecanismo que ya usa AOSP para
# copybit.qsd8k). Esto no cambia si el modulo se instala o no -- copybit.cooper
# se sigue resolviendo primero en runtime via ro.product.board -- solo hace
# que "make" no aborte al parsear su Android.mk.
#
# Si aparecen mas errores iguales para otros modulos de hardware/msm7k
# (libcamera, libaudio, etc.), agregalos a esta misma lista.
UT=build/core/user_tags.mk
cp -n $UT $UT.orig
python3 - "$UT" <<'PYEOF'
import sys
path = sys.argv[1]
with open(path) as f:
    content = f.read()
marker = "\tcopybit.qsd8k \\\n"
# Lista de modulos de hardware/msm7k que van apareciendo sin tag al ir
# avanzando el build. Agregar mas nombres a esta tupla cuando el log de
# Actions muestre un nuevo "*** Module name: X".
faltantes = ["copybit.msm7k", "lights.msm7k"]
extra = marker + "".join(f"\t{m} \\\n" for m in faltantes if m not in content)
if extra != marker:
    content = content.replace(marker, extra, 1)
    with open(path, "w") as f:
        f.write(content)
    print(f"    agregados a GRANDFATHERED_USER_MODULES: {[m for m in faltantes if m in extra]}")
else:
    print("    nada nuevo para agregar")
PYEOF

echo ">>> 4/5  Aligerando el build para maquinas con poca RAM"
# Solo se aplica si se corre con LOW_RAM=1, para no tocar nada en el runner
# de GitHub Actions (que tiene 16 GB y no lo necesita).
if [ "${LOW_RAM:-0}" = "1" ]; then
    echo "    - Sacando Browser de core.mk (evita compilar/linkear external/webkit,"
    echo "      el modulo que mas RAM pide en todo el arbol)"
    sed -i '/^    Browser \\$/d' build/target/product/core.mk

    echo "    - Achicando la lista de idiomas a uno solo (en_US)"
    sed -i \
      's|\$(call inherit-product, \$(SRC_TARGET_DIR)/product/languages_full.mk)|\$(call inherit-product, \$(SRC_TARGET_DIR)/product/languages_small.mk)|' \
      build/target/product/full_base.mk

    echo "    - Sin Browser habilitado (evita OOM en el link de webkit)"
else
    echo "    (LOW_RAM no esta en 1, no se toca nada; usar LOW_RAM=1 bash prepare-cooper.sh en PCs con <4 GB de RAM)"
fi

echo ">>> 5/5  Listo. Paquetes removidos de PRODUCT_PACKAGES:"
diff $DEV.orig $DEV || true

cat <<'EOF'

Siguiente paso en una PC potente / runner de Actions:
  . build/envsetup.sh
  lunch cooper-eng
  make -j$(nproc) otapackage

Siguiente paso en una PC con poca RAM (ej. Pentium E5400 + 2 GB):
  export LOW_RAM=1 && bash prepare-cooper.sh   # si todavia no lo corriste asi
  . build/envsetup.sh
  lunch cooper-user       # variant "user", no "eng": menos paquetes de debug
  make -j1 systemimage bootimage   # sin otapackage: no arma recovery ni firma OTA

Si falla por "libOmxCore" o "libOmxVidEnc", sacalos tambien de
device/samsung/cooper/device_cooper.mk: son modulos que CM construia desde su
fork de hardware/msm7k y los blobs ya los copian igual.
EOF
