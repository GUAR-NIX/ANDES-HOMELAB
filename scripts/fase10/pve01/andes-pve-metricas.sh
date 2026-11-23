#!/bin/bash
# Fase 10.2 - Metricas de capacidad de PVE01 que node_exporter no ve (colector textfile, cada 5 min).
# Instalado en PVE01: /usr/local/sbin/andes-pve-metricas.sh (temporizador andes-pve-metricas.timer).
set -euo pipefail
DIR=/var/lib/prometheus/node-exporter
TMP=$(mktemp "$DIR/.andes-pve.XXXX")
{
  echo "# HELP andes_pve_thinpool_percent Uso del thin pool local-lvm (pve/data), datos y metadatos"
  echo "# TYPE andes_pve_thinpool_percent gauge"
  read -r datos meta < <(lvs --noheadings --nosuffix -o data_percent,metadata_percent pve/data | tr -s ' ' | sed 's/^ //')
  echo "andes_pve_thinpool_percent{tipo=\"datos\"} ${datos}"
  echo "andes_pve_thinpool_percent{tipo=\"metadatos\"} ${meta}"
  echo "# HELP andes_pve_thinpool_asignado_bytes Suma de los tamanos virtuales de los discos thin frente al tamano del pool"
  echo "# TYPE andes_pve_thinpool_asignado_bytes gauge"
  echo "andes_pve_thinpool_asignado_bytes{tipo=\"discos\"} $(lvs --noheadings --units b --nosuffix -o lv_size -S 'pool_lv=data' | awk '{s+=$1} END {printf "%.0f", s}')"
  echo "andes_pve_thinpool_asignado_bytes{tipo=\"pool\"} $(lvs --noheadings --units b --nosuffix -o lv_size pve/data | tr -d ' ')"
  pvesh get /nodes/"$(hostname)"/qemu --output-format json | python3 -c '
import json, sys
vms = [v for v in json.load(sys.stdin) if not v.get("template")]
print("# HELP andes_pve_vm_ram_bytes RAM asignada a las VM (maxmem) por estado")
print("# TYPE andes_pve_vm_ram_bytes gauge")
print("# HELP andes_pve_vms Numero de VM por estado")
print("# TYPE andes_pve_vms gauge")
for estado in ("running", "stopped"):
    sel = [v for v in vms if v.get("status") == estado]
    ram = sum(v.get("maxmem", 0) for v in sel)
    etiqueta = "{estado=\"" + estado + "\"}"
    print("andes_pve_vm_ram_bytes" + etiqueta, ram)
    print("andes_pve_vms" + etiqueta, len(sel))
'
} > "$TMP"
chmod 644 "$TMP"
mv "$TMP" "$DIR/andes-pve.prom"
