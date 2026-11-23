#!/usr/bin/env python3
"""Fase 10.2 - Revision semanal de operacion (ADM-ANS01, temporizador de los lunes).

Reune en un informe Markdown lo que hay que mirar cada semana: copias de seguridad, alertas de Prometheus, SLO de la app,
disco, certificados proximos a caducar, alertas importantes de Wazuh, parches pendientes y unidades caidas.
Escribe docs/operacion/informes/revision-AAAA-Wss.md y devuelve 1 si hay algo que requiera accion.
Uso: source ~/.secrets/pve-terraform.env && python3 scripts/revision-semanal.py
"""
import json
import os
import re
import shlex
import ssl
import subprocess
import time
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
PVE = "https://pve01.corp.lab.internal:8006/api2/json"
TOKEN = os.environ["TF_VAR_pve_api_token"]
CERTS = ["app.corp.lab.internal:443", "srv-web01.corp.lab.internal:443", "grafana.corp.lab.internal:443",
         "wazuh.corp.lab.internal:443", "pve01.corp.lab.internal:8006"]
avisos = []


def sh(cmd, timeout=120):
    p = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout, check=False)
    return p.stdout.strip()


def pve(ruta):
    req = urllib.request.Request(PVE + ruta, headers={"Authorization": f"PVEAPIToken={TOKEN}"})
    with urllib.request.urlopen(req, context=ssl.create_default_context(), timeout=20) as r:
        return json.load(r)["data"]


def prom(consulta):
    """Consulta a Prometheus en MON01 (solo escucha en local): por SSH."""
    # ssh une los argumentos en una linea que interpreta el shell remoto: se citan con shlex para no romper las comillas
    remoto = shlex.join(["curl", "-s", "--get", "http://127.0.0.1:9090/api/v1/query", "--data-urlencode", f"query={consulta}"])
    p = subprocess.run(["ssh", "-o", "BatchMode=yes", "10.10.10.20", remoto], capture_output=True, text=True,
                       timeout=60, check=False)
    out = p.stdout
    try:
        return json.loads(out)["data"]["result"]
    except (ValueError, KeyError):
        return []


def copias():
    lineas = ["| Fecha | Estado | Duración |", "|---|---|---|"]
    desde = time.time() - 8 * 86400
    tareas = [t for t in pve("/nodes/pve01/tasks?typefilter=vzdump&limit=50") if t["starttime"] >= desde]
    for t in sorted(tareas, key=lambda t: t["starttime"]):
        dur = (t.get("endtime", t["starttime"]) - t["starttime"])
        ini = datetime.fromtimestamp(t["starttime"], timezone(timedelta(hours=-5))).strftime("%Y-%m-%d %H:%M")
        lineas.append(f'| {ini} | {t.get("status", "en curso")} | {dur // 60} min {dur % 60} s |')
    malas = [t for t in tareas if t.get("status") not in ("OK", None)]
    dias = len({datetime.fromtimestamp(t["starttime"]).date() for t in tareas if t.get("status") == "OK"})
    if malas:
        avisos.append(f"{len(malas)} copia(s) con error esta semana")
    if dias < 6:
        avisos.append(f"solo {dias} día(s) con copia correcta en la última semana (esperado: 7)")
    return lineas + ["", f"Días con copia correcta: **{dias}/7**."]


def alertas_prometheus():
    r = prom('count by (alertname, severity) (count_over_time(ALERTS{alertstate="firing"}[7d]))')
    if not r:
        return ["Ninguna alerta disparada en los últimos 7 días."]
    lineas = ["| Alerta | Severidad | Muestras en alerta |", "|---|---|---|"]
    for a in sorted(r, key=lambda a: -float(a["value"][1])):
        lineas.append(f'| {a["metric"].get("alertname")} | {a["metric"].get("severity", "-")} | {int(float(a["value"][1]))} |')
    activas = prom('ALERTS{alertstate="firing"}')
    if activas:
        avisos.append("alertas activas ahora: " + ", ".join(a["metric"]["alertname"] for a in activas))
    return lineas


def slo():
    def v(q):
        r = prom(q)
        return float(r[0]["value"][1]) if r else float("nan")
    sli, mins, horas = v("sli:app_disponibilidad:ratio_7d"), v("slo:app_minutos_caida:7d"), v("slo:app_horas_medidas:7d")
    estado = "CUMPLIDO" if mins <= 100.8 else "INCUMPLIDO"
    if estado == "INCUMPLIDO":
        avisos.append(f"SLO de Andes App incumplido ({mins:.1f} min sin servicio)")
    return [f"Disponibilidad de Andes App: **{sli * 100:.3f} %** en {horas:.1f} h medidas; {mins:.1f} min sin servicio "
            f"(presupuesto semanal 100,8 min, objetivo 99 %): **{estado}**."]


def disco():
    r = prom('100 * (1 - node_filesystem_avail_bytes{mountpoint="/",fstype!="tmpfs"} '
             '/ node_filesystem_size_bytes{mountpoint="/",fstype!="tmpfs"})')
    lineas = ["| Servidor | Disco / usado |", "|---|---|"]
    for x in sorted(r, key=lambda x: x["metric"]["instance"]):
        pct = float(x["value"][1])
        lineas.append(f'| {x["metric"]["instance"].split(":")[0]} | {pct:.0f} %{" ⚠" if pct >= 80 else ""} |')
        if pct >= 80:
            avisos.append(f'disco de {x["metric"]["instance"]} al {pct:.0f} % (RB-04)')
    for s in pve("/nodes/pve01/storage"):
        if s.get("total"):
            pct = 100 * s["used"] / s["total"]
            lineas.append(f'| PVE01 {s["storage"]} | {pct:.0f} %{" ⚠" if pct >= 80 else ""} |')
            if pct >= 80:
                avisos.append(f'almacenamiento {s["storage"]} de PVE01 al {pct:.0f} %')
    return lineas


def certificados():
    lineas = ["| Servicio | Caduca | Días |", "|---|---|---|"]
    for c in CERTS:
        h = c.split(":")[0]
        fin = sh(f"echo | timeout 10 openssl s_client -connect {c} -servername {h} 2>/dev/null "
                 "| openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2")
        if not fin:
            lineas.append(f"| {c} | sin respuesta | - |")
            avisos.append(f"certificado de {c} no comprobado (sin respuesta)")
            continue
        caduca = datetime.strptime(fin, "%b %d %H:%M:%S %Y %Z").replace(tzinfo=timezone.utc)
        dias = (caduca - datetime.now(timezone.utc)).days
        lineas.append(f'| {c} | {fin} | {dias}{" ⚠" if dias < 30 else ""} |')
        if dias < 30:
            avisos.append(f"el certificado de {c} caduca en {dias} días (RB-02)")
    return lineas


def wazuh():
    # 7 dias exactos: hoy (alerts.json) + los 6 anteriores (archivos diarios, comprimidos o no)
    script = ("import json,gzip,glob,collections,datetime\n"
              "c=collections.Counter(); ult={}; hoy=datetime.date.today()\n"
              "fs=['/var/ossec/logs/alerts/alerts.json']\n"
              "for d in range(1,7):\n"
              " x=hoy-datetime.timedelta(days=d); fs+=glob.glob(x.strftime('/var/ossec/logs/alerts/%Y/%b/ossec-alerts-%d.json'))"
              "+glob.glob(x.strftime('/var/ossec/logs/alerts/%Y/%b/ossec-alerts-%d.json.gz'))\n"
              "for f in fs:\n"
              " op=gzip.open if f.endswith('.gz') else open\n"
              " try:\n"
              "  for l in op(f,'rt',errors='ignore'):\n"
              "   try: a=json.loads(l)\n"
              "   except Exception: continue\n"
              "   if a['rule']['level']>=10:\n"
              "    k=(a['rule']['level'],a['rule']['description'][:70],a.get('agent',{}).get('name','-')); c[k]+=1\n"
              "    ult[k]=max(ult.get(k,''),a['timestamp'][:16].replace('T',' '))\n"
              " except OSError: pass\n"
              "print(json.dumps([[k[0],k[1],k[2],v,ult[k]] for k,v in c.most_common(10)]))\n")
    out = sh(f"ssh -o BatchMode=yes 10.10.40.10 'sudo python3 -' <<'EOF'\n{script}EOF", timeout=180)
    try:
        top = json.loads(out.splitlines()[-1])
    except (ValueError, IndexError):
        avisos.append("no se pudieron leer las alertas de Wazuh (¿SIEM apagado?)")
        return ["Sin datos de Wazuh."]
    if not top:
        return ["Ninguna alerta de nivel 10 o superior en los últimos 7 días."]
    if any(n >= 12 for n, *_ in top):
        avisos.append("alertas de Wazuh de nivel 12 o superior: revisar en el panel")
    return (["| Nivel | Regla | Agente | Veces | Última (UTC) |", "|---|---|---|---|---|"]
            + [f"| {n} | {d} | {ag} | {v} | {u} |" for n, d, ag, v, u in top])


def servidores():
    out = sh("cd ansible && ansible linux -o -m ansible.builtin.shell -a "
             "'echo \"$(apt list --upgradable 2>/dev/null | grep -c upgradable)|$(systemctl --failed --no-legend --plain | wc -l)"
             "|$(test -f /run/reboot-required && echo si || echo no)|$(uname -r)\"'", timeout=300)
    lineas = ["| Servidor | Paquetes pendientes | Unidades caídas | Reinicio pendiente | Kernel |", "|---|---|---|---|---|"]
    for l in sorted(out.splitlines()):
        m = re.match(r"^(\S+) \| CHANGED \| rc=0 \| \(stdout\) (\d+)\|(\d+)\|(\w+)\|(\S+)", l)
        if not m:
            lineas.append(f"| {l.split()[0] if l else '?'} | sin respuesta | | | |")
            continue
        h, pend, caidas, rb, k = m.groups()
        lineas.append(f"| {h} | {pend} | {caidas} | {rb} | {k} |")
        if int(caidas):
            avisos.append(f"{h}: {caidas} unidad(es) caída(s)")
        if int(pend) or rb == "si":
            avisos.append(f"{h}: parches pendientes o reinicio (RB-03)")
    return lineas


def main():
    semana = datetime.now().strftime("%G-W%V")
    secciones = [("1. Copias de seguridad (ventana de las 22:00)", copias), ("2. Alertas de Prometheus", alertas_prometheus),
                 ("3. SLO de Andes App", slo), ("4. Disco", disco), ("5. Certificados", certificados),
                 ("6. Alertas de Wazuh (nivel ≥ 10)", wazuh), ("7. Servidores Linux", servidores)]
    cuerpo = []
    for titulo, f in secciones:
        try:
            cuerpo += [f"## {titulo}\n", *f(), ""]
        except Exception as e:  # una sección que falla no debe impedir el resto del informe
            cuerpo += [f"## {titulo}\n", f"Error al generar esta sección: {e}", ""]
            avisos.append(f"sección '{titulo}' no generada")
    cab = [f"# Revisión semanal {semana}\n", f"Generada el {datetime.now():%Y-%m-%d %H:%M} con `scripts/revision-semanal.py`.\n",
           "## Resumen\n"]
    cab += ([f"- ⚠ {a}" for a in avisos] if avisos else ["Todo en orden: no hay acciones pendientes."]) + [""]
    destino = RAIZ / "docs" / "operacion" / "informes"
    destino.mkdir(parents=True, exist_ok=True)
    (destino / f"revision-{semana}.md").write_text("\n".join(cab + cuerpo) + "\n", encoding="utf-8")
    print(f"revisión {semana}: {len(avisos)} aviso(s) -> {destino / f'revision-{semana}.md'}")
    return 1 if avisos else 0


if __name__ == "__main__":
    raise SystemExit(main())
