#!/usr/bin/env python3
"""Fase 10 - Inventario regenerable del laboratorio.

Cruza la API de Proxmox (todas las VM: recursos, VLAN, arranque, etiquetas) con los facts de Ansible (sistema, kernel,
IP, memoria y disco reales de los Linux) y escribe docs/inventario/inventario.md y docs/inventario/vms.csv.
Se ejecuta en ADM-ANS01:  source ~/.secrets/pve-terraform.env && python3 scripts/inventario.py
"""
import csv
import json
import os
import re
import ssl
import subprocess
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
SALIDA = RAIZ / "docs" / "inventario"
API = "https://pve01.corp.lab.internal:8006/api2/json"
TOKEN = os.environ["TF_VAR_pve_api_token"]          # rol minimo de Terraform; nunca se escribe en disco
VLAN = {10: "MGMT", 20: "SERVERS", 30: "USERS", 40: "SEC", 50: "DMZ", 60: "BKP"}


def pve(ruta):
    req = urllib.request.Request(API + ruta, headers={"Authorization": f"PVEAPIToken={TOKEN}"})
    with urllib.request.urlopen(req, context=ssl.create_default_context(), timeout=20) as r:
        return json.load(r)["data"]


def facts():
    """Facts de los Linux con Ansible (los apagados simplemente no aparecen)."""
    filtro = ("ansible_distribution*,ansible_kernel,ansible_default_ipv4,ansible_memtotal_mb,"
              "ansible_processor_vcpus,ansible_uptime_seconds,ansible_mounts,ansible_hostname")
    p = subprocess.run(["ansible", "linux", "-m", "ansible.builtin.setup", "-a", f"filter={filtro}", "-o"],
                       cwd=RAIZ / "ansible", capture_output=True, text=True, check=False)
    datos = {}
    for linea in p.stdout.splitlines():
        m = re.match(r"^(\S+) \| SUCCESS => (\{.*\})$", linea)
        if m:
            datos[m.group(1)] = json.loads(m.group(2))["ansible_facts"]
    return datos


def disco_raiz(f):
    for m in f.get("ansible_mounts", []):
        if m.get("mount") == "/":
            usado = 100 * (1 - m["size_available"] / m["size_total"])
            return f'{m["size_total"] / 2**30:.0f} GB ({usado:.0f} % usado)'
    return "-"


def main():
    vms = []
    for v in sorted(pve("/nodes/pve01/qemu"), key=lambda v: v["vmid"]):
        c = pve(f'/nodes/pve01/qemu/{v["vmid"]}/config')
        tag = re.search(r"tag=(\d+)", c.get("net0", ""))
        discos = [f'{k}={re.search(r"size=([^,]+)", c[k]).group(1)}' for k in sorted(c)
                  if re.fullmatch(r"(scsi|sata|virtio)\d+", k) and "size=" in c[k]]
        vms.append({
            "vmid": v["vmid"], "nombre": v["name"], "estado": v["status"],
            "plantilla": "si" if c.get("template") else "no",
            "vcpu": c.get("cores", 1), "ram_mb": c.get("memory", ""), "balloon_mb": c.get("balloon", "-"),
            "vlan": f'{tag.group(1)} {VLAN.get(int(tag.group(1)), "")}' if tag else ("WAN + troncal" if v["vmid"] == 100 else "-"),
            "discos": " ".join(discos), "arranque": "si" if c.get("onboot") else "no",
            "etiquetas": c.get("tags", "").replace(";", " "),
        })

    f = facts()
    linux = []
    for host, d in sorted(f.items()):
        linux.append({
            "host": host,
            "ip": d.get("ansible_default_ipv4", {}).get("address", "-"),
            "so": f'{d.get("ansible_distribution", "")} {d.get("ansible_distribution_version", "")}',
            "kernel": d.get("ansible_kernel", "-"),
            "vcpu": d.get("ansible_processor_vcpus", "-"),
            "ram": f'{d.get("ansible_memtotal_mb", 0) / 1024:.1f} GB',
            "disco": disco_raiz(d),
            "uptime": f'{d.get("ansible_uptime_seconds", 0) // 86400} d {d.get("ansible_uptime_seconds", 0) % 86400 // 3600} h',
        })

    nodo = pve("/nodes/pve01/status")
    almacen = pve("/nodes/pve01/storage")
    SALIDA.mkdir(parents=True, exist_ok=True)
    with open(SALIDA / "vms.csv", "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=list(vms[0].keys()))
        w.writeheader()
        w.writerows(vms)

    ahora = datetime.now(timezone.utc).astimezone().strftime("%Y-%m-%d %H:%M %Z")
    md = [f"# Inventario del laboratorio\n",
          f"Generado automáticamente el {ahora} con `scripts/inventario.py` (API de Proxmox + facts de Ansible). "
          "No editar a mano: regenerar.\n",
          "## Anfitrión PVE01\n",
          f'Proxmox VE {pve("/version")["version"]} · {nodo["cpuinfo"]["cpus"]} vCPU · '
          f'RAM {nodo["memory"]["total"] / 2**30:.1f} GB (libre {nodo["memory"]["free"] / 2**30:.1f} GB) · '
          f'kernel {nodo["kversion"].split()[1]}\n',
          "| Almacenamiento | Tipo | Usado | Total |", "|---|---|---|---|"]
    for s in almacen:
        if s.get("total"):
            md.append(f'| {s["storage"]} | {s["type"]} | {s["used"] / 2**30:.0f} GB ({100 * s["used"] / s["total"]:.0f} %) '
                      f'| {s["total"] / 2**30:.0f} GB |')
    md += ["\n## Máquinas virtuales\n",
           "| VMID | Nombre | Estado | vCPU | RAM (MB) | Balloon | VLAN | Discos | Arranque | Etiquetas |",
           "|---|---|---|---|---|---|---|---|---|---|"]
    md += [f'| {v["vmid"]} | {v["nombre"]} | {v["estado"]} | {v["vcpu"]} | {v["ram_mb"]} | {v["balloon_mb"]} | '
           f'{v["vlan"]} | {v["discos"]} | {v["arranque"]} | {v["etiquetas"]} |' for v in vms]
    md += ["\n## Servidores Linux (facts de Ansible)\n",
           "| Host | IP | Sistema | Kernel | vCPU | RAM | Disco / | Encendido |", "|---|---|---|---|---|---|---|---|"]
    md += [f'| {x["host"]} | {x["ip"]} | {x["so"]} | {x["kernel"]} | {x["vcpu"]} | {x["ram"]} | {x["disco"]} | {x["uptime"]} |'
           for x in linux]
    md.append("\nLos servidores apagados en el momento de generar el inventario no aparecen en esta segunda tabla.")
    (SALIDA / "inventario.md").write_text("\n".join(md) + "\n", encoding="utf-8")
    print(f"inventario: {len(vms)} VM, {len(linux)} Linux con facts -> {SALIDA}")


if __name__ == "__main__":
    main()
