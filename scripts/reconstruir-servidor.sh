#!/bin/bash
# Reconstruye un servidor gestionado desde cero solo con codigo (prueba T30 / recuperacion ante desastre):
#   terraform destroy -> terraform apply -> ansible-playbook (x2) . Cronometra cada fase.
# Uso: scripts/reconstruir-servidor.sh srv-web01 10.10.50.10
set -uo pipefail
NOMBRE=${1:?nombre del servidor (clave en servers.auto.tfvars)}
IP=${2:?IP del servidor}
RAIZ=$(cd "$(dirname "$0")/.." && pwd)
RES="proxmox_virtual_environment_vm.srv[\"$NOMBRE\"]"
LOG=$(mktemp -d /tmp/reconstruir-XXXX)
# shellcheck disable=SC1090
. ~/.secrets/pve-terraform.env
t0=$(date +%s)
marca(){ printf '[%s] +%4ss  %s\n' "$(date +%T)" $(( $(date +%s) - t0 )) "$*"; }
paso(){  # paso <nombre-log> <patron a mostrar> <comando...>: ejecuta, muestra lo relevante y para si falla
  local n=$1 pat=$2; shift 2
  "$@" >"$LOG/$n.log" 2>&1; local rc=$?
  grep -E "$pat" "$LOG/$n.log" || true
  if [ $rc -ne 0 ]; then marca "ERROR en $n (rc=$rc), log en $LOG/$n.log"; tail -20 "$LOG/$n.log"; exit $rc; fi
}

marca "INICIO: reconstruccion de $NOMBRE ($IP) desde git $(git -C "$RAIZ" log --oneline -1)"
cd "$RAIZ/terraform" || exit 1
paso destroy 'Destruction complete|Destroy complete' terraform destroy -no-color -auto-approve -target="$RES"
marca "VM destruida"
paso apply 'Creation complete|Apply complete' terraform apply -no-color -auto-approve -target="$RES"
marca "VM creada por Terraform (plantilla 9000 + cloud-init)"

ssh-keygen -R "$IP" >/dev/null 2>&1 || true          # la VM nueva tiene otra clave de host
until ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new "labadmin@$IP" \
      'cloud-init status --wait >/dev/null 2>&1; true' 2>/dev/null; do sleep 5; done
marca "SSH disponible y cloud-init terminado"

cd "$RAIZ/ansible" || exit 1
export ANSIBLE_FORCE_COLOR=0
paso ansible1 "^$NOMBRE .*ok=" ansible-playbook site.yml --limit "$NOMBRE"
marca "Ansible aplicado (common, hardening, node_exporter, wazuh_agent y el rol del servidor)"
paso ansible2 "^$NOMBRE .*ok=" ansible-playbook site.yml --limit "$NOMBRE"
marca "Segunda ejecucion de Ansible (debe ser changed=0)"
s=$(( $(date +%s) - t0 ))
marca "FIN: $NOMBRE reconstruido en $((s / 60)) min $((s % 60)) s sin pasos manuales"
