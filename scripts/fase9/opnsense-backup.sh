#!/bin/bash
# Fase 9.3 - Copia versionada y CIFRADA de la configuracion de OPNsense (alternativa a os-git-backup,
# que subiria el config.xml en claro: lleva la clave privada de Andes-Root-CA, las de WireGuard y hashes).
# ADM-ANS01 descarga config.xml por la API (usuario backup-api, clave en ~/.secrets/opnsense-api.env),
# y SOLO si cambio lo cifra con Ansible Vault y lo sube a git: cada cambio del firewall = un commit.
# Cron: /etc/cron.d/andes-opnsense-backup (diario 03:15, despues de la copia de PBS).
set -euo pipefail
umask 077
REPO=/home/labadmin/andes-config
DEST=backups/opnsense/config.xml.vault
URL=https://10.10.10.1/api/core/backup/download/this
# Certificado autofirmado de OPNsense: se fija su clave publica en vez de desactivar la comprobacion TLS
PIN='sha256//cgrD6K3xxzMiwYoxVxkU1o7FbWlsKcUg2vwefmNKjiw='
VAULT=(--vault-password-file /home/labadmin/.secrets/vault-pass)

# shellcheck disable=SC1091
. /home/labadmin/.secrets/opnsense-api.env
nuevo=$(mktemp); anterior=$(mktemp)
trap 'shred -u "$nuevo" "$anterior" 2>/dev/null || true' EXIT

curl -sSf -m 30 -k --pinnedpubkey "$PIN" -u "$OPN_KEY:$OPN_SECRET" -o "$nuevo" "$URL"
grep -q '^<opnsense>' "$nuevo" || { echo "$(date -Is) ERROR: la descarga no es un config.xml de OPNsense"; exit 1; }

cd "$REPO"
mkdir -p "$(dirname "$DEST")"
if [ -f "$DEST" ]; then
  ansible-vault view "${VAULT[@]}" "$DEST" > "$anterior"
  if cmp -s "$nuevo" "$anterior"; then echo "$(date -Is) sin cambios en OPNsense"; exit 0; fi
fi

ansible-vault encrypt "${VAULT[@]}" --output "$DEST" "$nuevo"
# Descripcion del ultimo cambio guardado en OPNsense (quien y que), para el mensaje del commit
desc=$(sed -n '/<revision>/,/<\/revision>/s/.*<description>\(.*\)<\/description>.*/\1/p' "$nuevo" | head -1 | cut -c1-120)
git add -- "$DEST"
git commit -q -m "backup(opnsense): configuracion cambiada - ${desc:-sin descripcion}" -- "$DEST"
git push -q origin main
echo "$(date -Is) nueva version cifrada guardada: $(git log --oneline -1)"
