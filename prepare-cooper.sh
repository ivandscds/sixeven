#!/bin/bash
# Prepara un arbol AOSP gingerbread para compilar cooper (Galaxy Ace GT-S5830).
# Ejecutar desde la raiz del arbol AOSP, DESPUES de repo sync.
set -e

echo ">>> 0/6  Agregando build/target/product/full_base.mk"
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

echo ">>> 1/6  Agregando la variante de arquitectura armv6-vfp"
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

echo ">>> 2/6  Sacando paquetes que solo existen en CyanogenMod"
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

echo ">>> 3/6  Silenciando el chequeo de tags para TODO hardware/msm7k"
# hardware/msm7k se sincroniza de arrastre porque el manifest default de AOSP
# lo trae para otros telefonos msm7k viejos (Nexus One, HTC Dream). Cooper NO
# usa en runtime NINGUN modulo de esa carpeta (usa copybit.cooper,
# lights.cooper, gralloc.cooper propios), pero SI necesita que la carpeta siga
# estando en el arbol, porque su propio device/samsung/cooper/libcopybit
# incluye headers de hardware/msm7k/libgralloc para compilar.
#
# El problema es que hardware/msm7k es una carpeta vieja con VARIOS modulos
# (copybit, lights, gralloc, camara, audio...) que nunca declaran
# LOCAL_MODULE_TAGS, y el "user_tags.mk" original solo perdona algunos de
# ellos por nombre (ej. copybit.qsd8k), asi que van saltando de a uno segun
# el orden en que "make" los va parseando.
#
# En vez de ir agregando nombres a mano cada vez que aparece un error nuevo,
# parcheamos build/core/base_rules.mk para que perdone TODO lo que venga con
# LOCAL_PATH bajo hardware/msm7k, ademas de lo que ya estaba perdonado por
# nombre. Esto no cambia si esos modulos se instalan o no -- ninguno esta en
# PRODUCT_PACKAGES de cooper, asi que nunca terminan en el system.img -- solo
# evita que "make" aborte al parsear sus Android.mk.
BR=build/core/base_rules.mk
cp -n $BR $BR.orig
python3 - "$BR" <<'PYEOF'
import sys
path = sys.argv[1]
with open(path) as f:
    content = f.read()
old = "  ifeq ($(filter $(GRANDFATHERED_USER_MODULES),$(LOCAL_MODULE)),)"
new = "  ifeq ($(or $(filter $(GRANDFATHERED_USER_MODULES),$(LOCAL_MODULE)),$(filter hardware/msm7k%,$(LOCAL_PATH))),)"
n = content.count(old)
if n == 1:
    content = content.replace(old, new, 1)
    with open(path, "w") as f:
        f.write(content)
    print("    parche aplicado: hardware/msm7k queda exento del chequeo de tags")
elif new in content:
    print("    ya estaba parcheado, no se toca")
else:
    print(f"    ADVERTENCIA: no encontre el patron esperado ({n} coincidencias)."
          " Revisar build/core/base_rules.mk a mano.", file=sys.stderr)
    sys.exit(1)
PYEOF

echo ">>> 4/6  Haciendo que las definiciones de Samsung ganen sobre hardware/msm7k"
# Ademas del problema de tags, hay modulos con el MISMO NOMBRE definidos dos
# veces: device/samsung/cooper/libaudio define "libaudiopolicy" y "libaudio",
# y hardware/msm7k tiene sus propias variantes de audio (libaudio,
# libaudio-qdsp5v2, libaudio-qsd8k, libaudio_wince, segun la version que se
# sincronice) que declaran EXACTAMENTE los mismos nombres. "make" no permite
# dos definiciones del mismo LOCAL_MODULE y corta con:
#   MODULE.TARGET.SHARED_LIBRARIES.libaudiopolicy already defined by
#   hardware/msm7k/libaudio. Stop.
#
# Solucion: escanear que modulos define el propio device/samsung/cooper, y
# deshabilitar (renombrar el Android.mk) cualquier carpeta de hardware/msm7k
# que redefina alguno de esos mismos nombres. Asi Samsung siempre gana, sin
# tener que adivinar de antemano cuales carpetas de msm7k van a chocar.
#
# Esto NO borra archivos ni carpetas (los headers que cooper pueda necesitar,
# como los de hardware/msm7k/libgralloc, siguen estando disponibles), solo
# evita que "make" registre un modulo por segunda vez.
python3 - <<'PYEOF'
import re, os

def extract_modules(mk_path):
    mods = set()
    try:
        with open(mk_path, errors="ignore") as f:
            text = f.read()
    except FileNotFoundError:
        return mods
    for line in text.splitlines():
        m = re.match(r'\s*LOCAL_MODULE\s*[:+]?=\s*(.+?)\s*$', line)
        if m:
            val = m.group(1).strip()
            if '$(' in val:
                val = val.replace('$(TARGET_BOOTLOADER_BOARD_NAME)', 'cooper')
                val = val.replace('$(TARGET_BOARD_PLATFORM)', 'msm7k')
                val = val.replace('$(TARGET_DEVICE)', 'cooper')
            if '$(' not in val:
                mods.add(val)
    return mods

cooper_root = "device/samsung/cooper"
msm7k_root = "hardware/msm7k"

cooper_modules = set()
for root, dirs, files in os.walk(cooper_root):
    if "Android.mk" in files:
        cooper_modules |= extract_modules(os.path.join(root, "Android.mk"))

if not os.path.isdir(msm7k_root):
    print(f"    {msm7k_root} no existe, no hay nada que deshabilitar")
else:
    disabled_any = False
    for root, dirs, files in os.walk(msm7k_root):
        if "Android.mk" in files:
            mkpath = os.path.join(root, "Android.mk")
            overlap = extract_modules(mkpath) & cooper_modules
            if overlap:
                os.rename(mkpath, mkpath + ".disabled-by-cooper")
                print(f"    deshabilitado {mkpath} (choca en: {sorted(overlap)})")
                disabled_any = True
    if not disabled_any:
        print("    ningun choque de nombres encontrado, no se toco nada")
PYEOF

echo ">>> 5/6  Aligerando el build para maquinas con poca RAM"
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

echo ">>> 6/6  Listo. Paquetes removidos de PRODUCT_PACKAGES:"
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
