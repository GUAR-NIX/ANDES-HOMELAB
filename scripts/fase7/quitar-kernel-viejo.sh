#!/bin/bash
# Fase 7.4 - CHG-7.4-01, despues del reinicio: purga los kernels que no estan en uso.
# El rollback queda cubierto por el snapshot pre_chg_7_4 de Proxmox.
# Uso: sudo bash quitar-kernel-viejo.sh
set -euo pipefail
ACT=$(uname -r)                 # ej.: 6.8.0-151-generic
VER=${ACT%-generic}             # ej.: 6.8.0-151
NUEVO=$(dpkg -l 'linux-image-[0-9]*' | awk '/^ii/{print $2}' | sort -V | tail -1)
if [ "$NUEVO" != "linux-image-$ACT" ]; then
  echo "ABORTO en $(hostname): arranco con $ACT pero el kernel mas nuevo es $NUEVO. Reinicia primero."; exit 1
fi
VIEJOS=$(dpkg-query -W -f='${db:Status-Abbrev} ${Package}\n' 'linux-image-[0-9]*' 'linux-modules-[0-9]*' \
          'linux-headers-[0-9]*' 'linux-tools-[0-9]*' 2>/dev/null | awk '$1 ~ /^ii/{print $2}' | grep -v -- "$VER" || true)
echo "== $(hostname): kernel en uso $ACT"
if [ -n "$VIEJOS" ]; then
  echo "Se purgan:"; echo "$VIEJOS" | sed 's/^/   /'
  DEBIAN_FRONTEND=noninteractive apt-get -y -q -o DPkg::Lock::Timeout=300 purge $VIEJOS >/dev/null
else
  echo "No hay kernels viejos."
fi
echo "Kernels instalados:"; dpkg -l 'linux-image-[0-9]*' | awk '/^ii/{print "   " $2}'
# Fuerza un inventario nuevo para Wazuh (SRV-SIEM01 no tiene agente: es el manager)
if systemctl list-unit-files wazuh-agent.service >/dev/null 2>&1 && systemctl cat wazuh-agent >/dev/null 2>&1; then
  systemctl restart wazuh-agent
  echo "== $(hostname): wazuh-agent $(systemctl is-active wazuh-agent), fin $(date -u +%FT%TZ)"
else
  echo "== $(hostname): sin wazuh-agent, fin $(date -u +%FT%TZ)"
fi
