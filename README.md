# AOSP Gingerbread para Samsung Galaxy Ace GT-S5830 (cooper)

## Lo que verifiqué en los repos reales

| Cosa | Repo | Rama | Estado |
|---|---|---|---|
| Device tree | `CyanogenMod/android_device_samsung_cooper` | `gingerbread` | Vivo |
| Blobs propietarios | `TheMuppets/proprietary_vendor_samsung` (carpeta `cooper`, 13 MB) | `gingerbread` | Vivo |
| device/common (respaldo) | `CyanogenMod/android_device_common` | `gingerbread` | Vivo |
| Fuente AOSP | `android.googlesource.com/platform/manifest` | `gingerbread-release` | Vivo |

## Las tres cosas que importan

**1. El kernel ya viene compilado.** El device tree trae `kernel` y
`recovery_kernel` como zImage ARM prebuilt (3.3 MB cada uno) y el makefile los
copia tal cual. No necesitás fuentes del msm7x27 ni un cross-compiler ARM.

**2. El device tree es compatible con AOSP puro.** Esto era la duda grande.
`vendorsetup.sh` declara `add_lunch_combo cooper-eng` (no `cyanogen_cooper-eng`)
y `device_cooper.mk` hereda de `full_base.mk`, que es AOSP, no de
`vendor/cyanogen/products/common.mk`. Por eso `lunch cooper-eng` funciona sobre
un árbol AOSP limpio.

**3. Falta `armv6-vfp`.** AOSP gingerbread trae solo armv4t, armv5te,
armv5te-vfp, armv7-a y armv7-a-neon. El Ace declara `TARGET_ARCH_VARIANT :=
armv6-vfp`, que fue un agregado de CyanogenMod. Es un archivo de 25 líneas
autocontenido; `prepare-cooper.sh` lo escribe.

## Lo que sí hay que sacar

`device_cooper.mk` pide `FM`, `Torch`, `rzscontrol`, `SamsungServiceMode` y
`screencap`, que viven en repos de CM. El script los comenta. Si después querés
la linterna y la radio FM, agregás `CyanogenMod/android_packages_apps_Torch` y
`android_packages_apps_FM` al local_manifest y volvés a ponerlos.

Lo que **queda** y sí compila en AOSP: `libaudio`, `libcopybit`, `libgralloc`,
`liblight`, `bdaddr_read`, `setup_fs`, `toggleshutter` — todos están dentro del
propio device tree.

## Pasos

1. Repo nuevo en GitHub (público, así los minutos son ilimitados).
2. Subí `Dockerfile`, `local_manifest.xml`, `prepare-cooper.sh` y
   `.github/workflows/build-cooper.yml` respetando las rutas.
3. Actions → "Build AOSP Gingerbread para cooper" → Run workflow.
4. El artifact `cooper-gingerbread` trae el `.zip` para flashear desde CWM.

Tiempo estimado: 25-40 min de sync + 60-100 min de build en el runner de 4 vCPU.

## Alternativa para los blobs

Si los de TheMuppets te dan problemas (algunos están desactualizados respecto a
tu firmware), el device tree trae `extract-files.sh` que los saca directo del
teléfono por adb. Son 80 archivos. Lo corrés con el Ace conectado y una ROM
stock 2.3.x instalada.
