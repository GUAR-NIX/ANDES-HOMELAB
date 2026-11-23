#!/bin/bash
# Fase 9 - Mantenimiento de PBS al final de la ventana diaria de copias (22:00).
# PBS solo esta encendido durante la ventana (perfil de memoria), asi que sus trabajos programados no llegarian
# a ejecutarse: los lanza PVE01 por SSH con una clave cuyo comando esta FORZADO a este script (authorized_keys
# con restrict,command=...): esa clave no da shell ni ningun otro acceso.
# Instalado en SRV-PBS01: /usr/local/sbin/andes-mantenimiento-pbs.sh
set -uo pipefail
rc=0
log(){ echo "$(date '+%F %T') [pbs] $*"; }

# Retencion (last 3, daily 7, weekly 4, monthly 3). La verificacion se hace al terminar cada copia (verify-new).
proxmox-backup-manager prune-job run prune-ds-main >/dev/null 2>&1 && log "retencion aplicada" || { log "ERROR en la retencion"; rc=1; }

case "$(date +%u)" in
  6)  # sabado: copia 2 al disco extraible. Al montarlo se lanza sync-usb (run-on-mount) y se desmonta al acabar
      proxmox-backup-manager datastore mount ds-usb >/dev/null 2>&1
      for _ in $(seq 1 180); do findmnt /mnt/datastore/ds-usb >/dev/null || break; sleep 10; done
      if findmnt /mnt/datastore/ds-usb >/dev/null; then log "ERROR: ds-usb sigue montado tras 30 min"; rc=1
      else log "copia 2 sincronizada en ds-usb y desmontada"; fi ;;
  7)  # domingo: recolector de basura y re-verificacion de las copias verificadas hace mas de 30 dias
      proxmox-backup-manager garbage-collection start ds-main >/dev/null 2>&1 && log "GC terminado" || { log "ERROR en GC"; rc=1; }
      proxmox-backup-manager verify ds-main --ignore-verified true --outdated-after 30 >/dev/null 2>&1 \
        && log "re-verificacion OK" || { log "ERROR en la re-verificacion"; rc=1; } ;;
esac
df -h --output=pcent /mnt/datastore/ds-main | tail -1 | xargs -I{} echo "$(date '+%F %T') [pbs] ds-main usado: {}"
exit $rc
