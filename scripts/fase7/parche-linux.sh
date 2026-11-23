#!/bin/bash
# Fase 7.4 - Ventana de cambio CHG-7.4-01: parches de Ubuntu y limpieza de kernels viejos
# Uso: sudo bash parche-linux.sh     (se puede repetir; despues del reinicio quita el kernel anterior)
set -uo pipefail
LOG=/var/log/parche-7.4.log
exec > >(tee -a "$LOG") 2>&1
export DEBIAN_FRONTEND=noninteractive
APT="apt-get -y -q -o DPkg::Lock::Timeout=300 -o Dpkg::Options::=--force-confold"
kernels() { dpkg -l 'linux-image-[0-9]*' | awk '/^ii/{print "   " $2}'; }

echo "== $(hostname): inicio $(date -u +%FT%TZ)"
echo "Kernel en uso: $(uname -r)"
echo "Kernels instalados ANTES:"; kernels
$APT update >/dev/null
$APT full-upgrade
$APT autoremove --purge
echo "Kernels instalados DESPUES:"; kernels
echo "Paquetes retenidos (deben ser solo wazuh-agent):"; apt-mark showhold | sed 's/^/   /'
if [ -f /var/run/reboot-required ]; then echo ">> REINICIO NECESARIO"; else echo ">> Sin reinicio pendiente"; fi
echo "== $(hostname): fin $(date -u +%FT%TZ)"
