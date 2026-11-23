#!/bin/bash
# Fase 9.3 - Copia 2 de la regla 3-2-1: datastore EXTRAIBLE ds-usb.
# La "USB" es un disco virtual de VMware cuyo archivo vive en una carpeta del Windows anfitrion
# (C:\Lab\USB-PBS\usb-pbs.vmdk), fuera del almacenamiento de Proxmox. PVE01 lo pasa a la VM 160 como scsi2.
# Se ejecuta desde ADM-ANS01:  ssh root@10.10.60.10 'bash -s' < scripts/fase9/pbs-usb.sh
# AVISO (incidencia 22/11/2026): PVE01 usa BIOS clasica. Al anadir el disco SCSI en VMware, la BIOS lo pone por delante
# del NVMe de Proxmox y en el siguiente reinicio PVE01 no arranca (o arranca una ISO conectada). Tras anadirlo:
# VM -> Energia -> Encender en el firmware -> Boot -> Hard Drive -> NVMe el primero (tecla +) -> F10. Y en CD/DVD,
# desmarcar "Conectar al encender". NUNCA aceptar un instalador de Proxmox que aparezca al arrancar.
set -euo pipefail
DEV=/dev/sdc
ok(){ echo "[OK] $*"; }

# 1. Seguridad: solo se toca el disco de 64 GiB, y solo si su particion aun no tiene sistema de archivos
size=$(lsblk -bdno SIZE "$DEV")
[ "$size" -eq $((64*1024**3)) ] || { echo "ABORTO: $DEV no mide 64 GiB ($size bytes)"; exit 1; }
if [ -z "$(blkid -s UUID -o value "${DEV}1" 2>/dev/null)" ]; then   # sin UUID = sin sistema de archivos
  if [ "$(lsblk -no NAME "$DEV" | wc -l)" -eq 1 ]; then      # sin particiones: crearla
    sgdisk -q -n1:0:0 -t1:8300 -c1:usb-pbs "$DEV"
  fi
  partx -u "$DEV" 2>/dev/null || partx -a "$DEV"; udevadm settle; sleep 1   # que el kernel publique /dev/sdc1
  mkfs.ext4 -q -L usb-pbs "${DEV}1"
  ok "particion y ext4 creados en ${DEV}1"
fi
UUID=$(blkid -s UUID -o value "${DEV}1")
ok "UUID del 'USB': $UUID"

# 2. Datastore extraible: se identifica por el UUID, se monta solo cuando hace falta
if ! proxmox-backup-manager datastore list --output-format json | grep -q '"ds-usb"'; then
  proxmox-backup-manager datastore create ds-usb ds-usb --backing-device "$UUID" \
    --comment "Copia 2 (3-2-1): disco extraible en C:\\Lab\\USB-PBS del anfitrion"
fi
ok "datastore extraible ds-usb"

# 3. Sincronizacion semanal ds-main -> ds-usb: solo copias cifradas y verificadas, espejo de la
#    retencion de ds-main, se lanza al montar el disco y lo desmonta al terminar (como una USB real)
proxmox-backup-manager sync-job list --output-format json | grep -q '"sync-usb"' || \
  proxmox-backup-manager sync-job create sync-usb --store ds-usb --remote-store ds-main \
    --schedule 'sat 03:00' --encrypted-only true --verified-only true --remove-vanished true \
    --run-on-mount true --unmount-on-done true --comment "Copia 2 semanal al disco extraible"
ok "sync-job sync-usb (sabados 03:00, al montar, desmonta al terminar)"
