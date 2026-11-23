#!/bin/bash
# Fase 9.2 - Configuracion de SRV-PBS01 (Proxmox Backup Server 4.2 sobre Debian 13).
# Se ejecuta desde ADM-ANS01:  ssh root@10.10.60.10 'bash -s' < scripts/fase9/pbs-config.sh
# Idempotente: cada paso comprueba antes de cambiar.
set -euo pipefail
ok(){ echo "[OK] $*"; }

# 1. Hora desde OPNsense (la salida NTP a Internet esta bloqueada), sin pool de Debian
cat > /etc/chrony/sources.d/lab-gateway.sources <<'EOF'
server 10.10.60.1 iburst
EOF
sed -i -E 's/^(pool .*)/#\1/' /etc/chrony/chrony.conf
systemctl restart chrony && sleep 3 && chronyc -n sources | tail -1
ok "chrony contra 10.10.60.1"

# 2. Repositorios: enterprise (de pago, da 401) desactivado; no-subscription activado
if ! grep -q '^Enabled: no' /etc/apt/sources.list.d/pbs-enterprise.sources; then
  echo 'Enabled: no' >> /etc/apt/sources.list.d/pbs-enterprise.sources
fi
cat > /etc/apt/sources.list.d/pbs-no-subscription.sources <<'EOF'
Types: deb
URIs: http://download.proxmox.com/debian/pbs
Suites: trixie
Components: pbs-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF
ok "repositorios"

# 3. Actualizacion completa y agente QEMU (Proxmox vera la IP y podra congelar el disco en las copias)
export DEBIAN_FRONTEND=noninteractive
apt-get -q update >/dev/null
apt-get -q -y full-upgrade >/dev/null
apt-get -q -y install qemu-guest-agent >/dev/null
systemctl enable --now qemu-guest-agent >/dev/null 2>&1 || true
ok "sistema actualizado; qemu-guest-agent $(systemctl is-active qemu-guest-agent)"

# 4. Datastore ds-main en el segundo disco (sdb, 120 GB)
if ! proxmox-backup-manager datastore list --output-format json | grep -q '"ds-main"'; then
  proxmox-backup-manager disk fs create ds-main --disk sdb --filesystem ext4 --add-datastore true
fi
ok "datastore ds-main en $(findmnt -no SOURCE,SIZE /mnt/datastore/ds-main | tr -s ' ')"

# 5. Usuario de copias con el minimo privilegio: solo DatastoreBackup sobre ds-main (no Admin)
proxmox-backup-manager user list --output-format json | grep -q '"pve-backup@pbs"' || \
  proxmox-backup-manager user create pve-backup@pbs --comment "Copias desde PVE01 (Fase 9)"
proxmox-backup-manager acl update /datastore/ds-main DatastoreBackup --auth-id pve-backup@pbs
ok "usuario pve-backup@pbs con DatastoreBackup en /datastore/ds-main"

# 6. Retencion, verificacion y limpieza (plan 9.2)
proxmox-backup-manager prune-job list --output-format json | grep -q '"prune-ds-main"' || \
  proxmox-backup-manager prune-job create prune-ds-main --store ds-main --schedule 'daily' \
    --keep-last 3 --keep-daily 7 --keep-weekly 4 --keep-monthly 3
proxmox-backup-manager verify-job list --output-format json | grep -q '"verify-ds-main"' || \
  proxmox-backup-manager verify-job create verify-ds-main --store ds-main --schedule '06:00' \
    --ignore-verified true --outdated-after 30
proxmox-backup-manager datastore update ds-main --gc-schedule 'sun 05:00'
ok "prune diario (last 3, daily 7, weekly 4, monthly 3), verify diario 06:00, GC domingos 05:00"

[ -f /run/reboot-required ] && echo "[!] Hace falta reiniciar (kernel nuevo)" || true
