#!/usr/bin/env python3
"""Fase 10.2 - Revision de accesos trimestral (ADM-ANS01).

Compara los accesos reales con la linea base esperada (ESPERADO) y marca lo que no cuadra:
  - miembros de los grupos privilegiados de AD (leidos con SSSD desde SRV-APP01, unido al dominio)
  - usuarios, 2FA, tokens y permisos de Proxmox (API, con el token de rol minimo)
  - claves SSH autorizadas en todos los Linux (y en PBS si esta encendido), con sus restricciones
Lo que no se puede leer automaticamente (OPNsense, Wazuh, Grafana, WireGuard) queda como lista de comprobacion.
Escribe docs/operacion/accesos/revision-accesos-AAAA-Tn.md. No guarda correos ni ningun secreto.
Uso: source ~/.secrets/pve-terraform.env && python3 scripts/revision-accesos.py
"""
import json
import os
import re
import shlex
import ssl
import subprocess
import urllib.request
from datetime import datetime
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
API = "https://pve01.corp.lab.internal:8006/api2/json"
TOKEN = os.environ["TF_VAR_pve_api_token"]

# Linea base aprobada. Cambiarla es un cambio (docs/cambios) con su justificacion.
ESPERADO = {
    "ad": {
        "admins. del dominio": {"administrador", "adm-erick"},
        "administradores de empresas": {"administrador"},
        "administradores de esquema": {"administrador"},
        "gg-linux-admins": {"erick"},
        "gg-helpdesk": {"hd.rojas"},
    },
    "pve_usuarios": {"root@pam", "guarnix@pve", "terraform@pve"},
    "pve_tokens": {"terraform@pve!tf"},
    # comentario de la clave -> donde puede estar (usuario@host); '*' = en todos los Linux
    "ssh": {
        "erick@adm-ans01": {"labadmin@*", "root@srv-pbs01"},
        "erick@laptop": {"labadmin@adm-ans01"},                     # portatil del administrador (entra por la VPN)
        "adm-ans01 deploy andes-config": {"(github)"},
        "pve01-ventana-backup": {"root@srv-pbs01"},
    },
}
hallazgos = []


def sh(cmd, timeout=120):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout, check=False).stdout


def pve(ruta):
    req = urllib.request.Request(API + ruta, headers={"Authorization": f"PVEAPIToken={TOKEN}"})
    with urllib.request.urlopen(req, context=ssl.create_default_context(), timeout=20) as r:
        return json.load(r)["data"]


def ad():
    lineas = ["| Grupo | Miembros | Estado |", "|---|---|---|"]
    for grupo, esperado in ESPERADO["ad"].items():
        remoto = shlex.join(["getent", "group", f"{grupo}@corp.lab.internal"])
        out = sh(f"ssh -o BatchMode=yes 10.10.20.30 {shlex.quote(remoto)}").strip()
        reales = {m.split("@")[0] for m in out.split(":")[-1].split(",") if m} if out else set()
        sobran, faltan = reales - esperado, esperado - reales
        estado = "OK" if not (sobran or faltan) else "REVISAR"
        if sobran:
            hallazgos.append(f"AD '{grupo}': miembros no aprobados: {', '.join(sorted(sobran))}")
        if faltan:
            hallazgos.append(f"AD '{grupo}': faltan miembros esperados: {', '.join(sorted(faltan))}")
        lineas.append(f"| {grupo} | {', '.join(sorted(reales)) or '(vacío o sin respuesta)'} | {estado} |")
    return lineas


def proxmox():
    lineas = ["| Usuario | Habilitado | 2FA | Caduca | Estado |", "|---|---|---|---|---|"]
    for u in sorted(pve("/access/users"), key=lambda u: u["userid"]):
        uid = u["userid"]
        tfa = "sí" if u.get("keys") or u.get("totp-locked") is not None else "no"
        ok = uid in ESPERADO["pve_usuarios"]
        if not ok:
            hallazgos.append(f"Proxmox: usuario no aprobado {uid}")
        if u.get("enable") and tfa == "no" and not uid.startswith("terraform@"):
            hallazgos.append(f"Proxmox: {uid} sin segundo factor")
        caduca = datetime.fromtimestamp(u["expire"]).strftime("%Y-%m-%d") if u.get("expire") else "nunca"
        lineas.append(f'| {uid} | {"sí" if u.get("enable") else "no"} | {tfa} | {caduca} | {"OK" if ok else "REVISAR"} |')
    lineas += ["", "| Ruta | Usuario/grupo/token | Rol | Hereda |", "|---|---|---|---|"]
    for a in sorted(pve("/access/acl"), key=lambda a: (a["path"], a["ugid"])):
        lineas.append(f'| {a["path"]} | {a["ugid"]} ({a["type"]}) | {a["roleid"]} | {"sí" if a.get("propagate") else "no"} |')
        if a["type"] == "token" and a["ugid"] not in ESPERADO["pve_tokens"]:
            hallazgos.append(f'Proxmox: token con permisos no aprobado {a["ugid"]}')
    return lineas


LEER_CLAVES = r"""#!/bin/bash
# Una linea por clave: usuario|huella|restricciones|comentario
for f in /root/.ssh/authorized_keys /home/*/.ssh/authorized_keys; do
  [ -f "$f" ] || continue
  u=$(stat -c %U "$f")
  while read -r l; do
    case "$l" in ''|'#'*) continue ;; esac
    fp=$(ssh-keygen -lf - <<<"$l" 2>/dev/null | awk '{print $2}')
    opts=$(grep -oE '^(restrict|command|from|no-)[^ ]*' <<<"$l")
    echo "$u|$fp|$opts|$(awk '{print $NF}' <<<"$l")"
  done < "$f"
done
"""


def ssh_keys():
    guion = Path("/tmp/andes-leer-claves.sh")
    guion.write_text(LEER_CLAVES)
    out = sh(f"cd ansible && ansible linux -b -o -m ansible.builtin.script -a {guion}", timeout=300)
    pbs = sh(f"timeout 20 ssh -o BatchMode=yes -o ConnectTimeout=5 root@10.10.60.10 'bash -s' < {guion} 2>/dev/null", timeout=30)
    guion.unlink()
    filas = []
    for l in out.splitlines():
        m = re.match(r"^(\S+) \| CHANGED => (\{.*\})$", l)
        if m:
            for e in json.loads(m.group(2)).get("stdout_lines", []):
                if e.count("|") == 3:
                    filas.append((m.group(1), *e.split("|")))
    filas += [("srv-pbs01", *e.split("|")) for e in pbs.splitlines() if e.count("|") == 3]
    if not [f for f in filas if f[0] != "srv-pbs01"]:
        hallazgos.append("SSH: no se pudo leer ninguna clave de los servidores Linux (la revisión no es válida)")
    lineas = ["| Servidor | Usuario | Clave (comentario) | Huella | Restricciones | Estado |", "|---|---|---|---|---|---|"]
    for host, usuario, huella, restr, comentario in sorted(filas):
        permitido = ESPERADO["ssh"].get(comentario, set())
        ok = f"{usuario}@{host}" in permitido or f"{usuario}@*" in permitido
        if not ok:
            hallazgos.append(f"SSH: clave '{comentario}' de {usuario}@{host} fuera de la línea base")
        lineas.append(f"| {host} | {usuario} | {comentario} | `{huella[:20]}…` | {restr or '-'} | {'OK' if ok else 'REVISAR'} |")
    if not pbs:
        lineas.append("| srv-pbs01 | - | (apagado: se revisa en la ventana de copias o encendiéndolo) | | | PENDIENTE |")
    return lineas


def main():
    hoy = datetime.now()
    trimestre = f"{hoy.year}-T{(hoy.month - 1) // 3 + 1}"
    secciones = [("1. Grupos privilegiados de AD", ad), ("2. Proxmox: usuarios, 2FA y permisos", proxmox),
                 ("3. Claves SSH autorizadas", ssh_keys)]
    cuerpo = []
    for titulo, f in secciones:
        try:
            cuerpo += [f"## {titulo}\n", *f(), ""]
        except Exception as e:
            cuerpo += [f"## {titulo}\n", f"Error al generar esta sección: {e}", ""]
            hallazgos.append(f"sección '{titulo}' no generada")
    cuerpo += ["## 4. Comprobación manual\n",
               "- [ ] OPNsense (Sistema → Acceso → Usuarios): solo `root` y `backup-api`; `backup-api` sin shell y solo con "
               "privilegios de copia (Configuration History y Backups).",
               "- [ ] OPNsense (VPN → WireGuard → Peers): solo los equipos de administración aprobados.",
               "- [ ] Wazuh y Grafana: solo la cuenta `admin`; contraseñas en el gestor, no compartidas.",
               "- [ ] PBS (Configuración → Control de acceso): `pve-backup@pbs` y su token `pve01`, solo DatastoreBackup en ds-main.",
               "- [ ] Cuentas de servicio de AD (OU=Servicio): `svc-adjoin` sin grupos y con delegación solo en OU=Linux.",
               "- [ ] Bajas del trimestre (RB-01): ninguna cuenta habilitada de personas que ya no trabajan.", ""]
    cab = [f"# Revisión de accesos {trimestre}\n",
           f"Generada el {hoy:%Y-%m-%d %H:%M} con `scripts/revision-accesos.py` contra la línea base aprobada. "
           "Revisor: ______  Fecha de aprobación: ______\n", "## Hallazgos\n"]
    cab += ([f"- ⚠ {h}" for h in hallazgos] if hallazgos else ["Sin desviaciones respecto a la línea base."]) + [""]
    destino = RAIZ / "docs" / "operacion" / "accesos"
    destino.mkdir(parents=True, exist_ok=True)
    (destino / f"revision-accesos-{trimestre}.md").write_text("\n".join(cab + cuerpo) + "\n", encoding="utf-8")
    print(f"revisión de accesos {trimestre}: {len(hallazgos)} hallazgo(s)")
    return 1 if hallazgos else 0


if __name__ == "__main__":
    raise SystemExit(main())
