#!/bin/bash
# Fase 9 - Ventana diaria de copias (22:00, temporizador andes-ventana-backup.timer en PVE01).
# PBS (2 GB) y SRV-SIEM01 (6 GB) no caben a la vez con todo encendido: el SIEM se apaga ~15 min cada dia,
# se enciende PBS, se copian todas las VM (cifradas, verificadas al terminar), PBS hace su mantenimiento y se
# vuelve al estado normal. Pase lo que pase (trap EXIT), PBS se apaga y el SIEM se vuelve a encender.
# Instalado en PVE01: /usr/local/sbin/andes-ventana-backup.sh   Log: /var/log/andes-ventana-backup.log
set -uo pipefail
exec >>/var/log/andes-ventana-backup.log 2>&1
SIEM=140; PBS=160; EXCLUIR=160,301,9000
rc=0
log(){ echo "$(date '+%F %T') $*"; }
estado(){ qm status "$1" | awk '{print $2}'; }

volver(){
  log "fin de la ventana: apagando PBS y arrancando el SIEM"
  if [ "$(estado $PBS)" = running ]; then qm shutdown $PBS --timeout 180 || qm stop $PBS; fi
  [ "$(estado $SIEM)" = running ] || qm start $SIEM
  log "PBS: $(estado $PBS) | SIEM: $(estado $SIEM) | resultado: $([ $rc -eq 0 ] && echo OK || echo CON ERRORES)"
  log "=================================================="
}
trap volver EXIT

# Si el PC estaba apagado a las 22:00, systemd lanza la ventana al arrancar: dejar que arranquen las VM antes
while [ "$(cut -d. -f1 /proc/uptime)" -lt 600 ]; do sleep 30; done

log "=== inicio de la ventana de copias"
if [ "$(estado $SIEM)" = running ]; then
  qm shutdown $SIEM --timeout 300 || qm stop $SIEM
fi
log "SIEM: $(estado $SIEM)"

[ "$(estado $PBS)" = running ] || qm start $PBS
for _ in $(seq 1 60); do curl -sk -m 5 -o /dev/null https://10.10.60.10:8007/ && break; sleep 5; done
pvesm status --storage pbs01 | grep -q ' active ' && log "PBS disponible" || { log "ERROR: PBS no responde"; rc=1; exit 1; }

if vzdump --all 1 --exclude $EXCLUIR --storage pbs01 --mode snapshot --notes-template '{{guestname}}' >/dev/null 2>&1; then
  log "copia de las VM: OK"
else
  log "ERROR en la copia de alguna VM (ver: journalctl -u andes-ventana-backup / Tasks de Proxmox)"; rc=1
fi

# Mantenimiento de PBS: la clave solo puede ejecutar ese script (command forzado en authorized_keys de PBS)
ssh -i /root/.ssh/pbs-mantenimiento -o BatchMode=yes -o ConnectTimeout=10 root@10.10.60.10 \
  || { log "ERROR en el mantenimiento de PBS"; rc=1; }

exit $rc
