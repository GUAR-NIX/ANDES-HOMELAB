#!/usr/bin/env python3
"""Fase 10.2 - Genera el panel de Grafana "Capacidad PVE01" (monitoring/grafana/capacidad-pve01.json)."""
import json
import sys

PCT_RAM = '100 * node_memory_MemAvailable_bytes{job="pve01"} / node_memory_MemTotal_bytes{job="pve01"}'
paneles = []


def stat(titulo, expr, unidad, x, umbrales, desc, decimales=1, w=4):
    paneles.append({
        "type": "stat", "title": titulo, "description": desc,
        "gridPos": {"h": 5, "w": w, "x": x, "y": 0},
        "targets": [{"expr": expr, "refId": "A"}],
        "fieldConfig": {"defaults": {"unit": unidad, "decimals": decimales,
                                     "thresholds": {"mode": "absolute", "steps": umbrales}}, "overrides": []},
        "options": {"reduceOptions": {"calcs": ["lastNotNull"]}, "colorMode": "background", "graphMode": "area"},
    })


def serie(titulo, consultas, unidad, x, y, w=12, desc=""):
    paneles.append({
        "type": "timeseries", "title": titulo, "description": desc,
        "gridPos": {"h": 8, "w": w, "x": x, "y": y},
        "targets": [{"expr": e, "legendFormat": l, "refId": chr(65 + i)} for i, (e, l) in enumerate(consultas)],
        "fieldConfig": {"defaults": {"unit": unidad, "custom": {"fillOpacity": 10}}, "overrides": []},
        "options": {"legend": {"displayMode": "list", "placement": "bottom"}, "tooltip": {"mode": "multi"}},
    })


VERDE, AMARILLO, ROJO = "green", "#EAB839", "red"
stat("RAM disponible", PCT_RAM, "percent", 0,
     [{"color": ROJO, "value": None}, {"color": AMARILLO, "value": 10}, {"color": VERDE, "value": 25}],
     "Memoria disponible de PVE01. Alerta CapacidadRamPVE01 por debajo del 10 %.")
stat("RAM asignada a VM encendidas", '100 * andes_pve_vm_ram_bytes{estado="running"} / on() node_memory_MemTotal_bytes{job="pve01"}',
     "percent", 4, [{"color": VERDE, "value": None}, {"color": AMARILLO, "value": 85}, {"color": ROJO, "value": 100}],
     "Suma de la RAM configurada de las VM encendidas frente a la RAM de PVE01 (KSM y RAM fija).")
stat("CPU PVE01 (5 min)", '100 - 100 * avg(rate(node_cpu_seconds_total{job="pve01",mode="idle"}[5m]))', "percent", 8,
     [{"color": VERDE, "value": None}, {"color": AMARILLO, "value": 70}, {"color": ROJO, "value": 90}], "Uso medio de las 8 vCPU.")
stat("local-lvm (thin pool)", 'andes_pve_thinpool_percent{tipo="datos"}', "percent", 12,
     [{"color": VERDE, "value": None}, {"color": AMARILLO, "value": 70}, {"color": ROJO, "value": 85}],
     "Datos escritos en el thin pool. Si llega al 100 % las VM se congelan. Alerta CapacidadThinPool por encima del 85 %.")
stat("Sobreasignación de disco", 'andes_pve_thinpool_asignado_bytes{tipo="discos"} / ignoring(tipo) andes_pve_thinpool_asignado_bytes{tipo="pool"}',
     "x", 16, [{"color": VERDE, "value": None}, {"color": AMARILLO, "value": 2}, {"color": ROJO, "value": 4}],
     "Tamaño virtual de todos los discos thin frente al tamaño real del pool.")
stat("VM encendidas / apagadas", 'andes_pve_vms{estado="running"}', "none", 20,
     [{"color": "blue", "value": None}], "VM encendidas (sin contar plantillas).", decimales=0)

serie("RAM de PVE01", [('node_memory_MemTotal_bytes{job="pve01"}', "total"),
                        ('node_memory_MemTotal_bytes{job="pve01"} - node_memory_MemAvailable_bytes{job="pve01"}', "usada"),
                        ('andes_pve_vm_ram_bytes{estado="running"}', "asignada a VM encendidas")], "bytes", 0, 5)
serie("CPU y carga de PVE01", [('100 - 100 * avg(rate(node_cpu_seconds_total{job="pve01",mode="idle"}[5m]))', "CPU %"),
                                ('100 * avg(rate(node_cpu_seconds_total{job="pve01",mode="iowait"}[5m]))', "iowait %")],
      "percent", 12, 5)
serie("Almacenamiento de PVE01", [('andes_pve_thinpool_percent{tipo="datos"}', "local-lvm datos"),
                                   ('andes_pve_thinpool_percent{tipo="metadatos"}', "local-lvm metadatos"),
                                   ('100 * (1 - node_filesystem_avail_bytes{job="pve01",mountpoint="/"} / node_filesystem_size_bytes{job="pve01",mountpoint="/"})', "raíz (local)")],
      "percent", 0, 13)
serie("Memoria por VM (uso real en el anfitrión)",
      [('100 * node_memory_MemAvailable_bytes{job="node"} / node_memory_MemTotal_bytes{job="node"}', "{{instance}} RAM libre %")],
      "percent", 12, 13, desc="RAM disponible dentro de cada Linux: indica si a una VM le sobra o le falta memoria.")

panel = {"uid": "capacidad-pve01", "title": "Capacidad PVE01", "tags": ["andes", "capacidad"], "schemaVersion": 39,
         "time": {"from": "now-7d", "to": "now"}, "refresh": "5m", "timezone": "browser", "editable": True,
         "description": "Fase 10.2 - capacidad del anfitrión. Conclusión y umbrales en docs/operacion/capacidad.md",
         "panels": [dict(p, id=i + 1) for i, p in enumerate(paneles)]}
json.dump(panel, open(sys.argv[1], "w", encoding="utf-8"), ensure_ascii=False, indent=2)
print(f"{len(paneles)} paneles -> {sys.argv[1]}")
