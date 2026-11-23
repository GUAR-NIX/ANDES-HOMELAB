#!/bin/bash
# Fase 7.4 - Informe de vulnerabilidades desde el indexer de Wazuh
# Correr en SRV-SIEM01 (el indexer solo escucha en local). No necesita sudo.
# Uso: bash vuln-report.sh <etiqueta>      ej.: antes | despues
set -euo pipefail
ETQ=${1:?Indica la etiqueta: antes o despues}
OUT="$HOME/vuln-ciclo-01-$ETQ.md"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

read -rsp "Contrasena del usuario admin de Wazuh: " P; echo
printf 'user = "admin:%s"\n' "$P" > "$TMP/cred"; unset P

cat > "$TMP/q.json" <<'EOF'
{
  "size": 0,
  "track_total_hits": true,
  "aggs": {
    "por_sev":  { "terms": { "field": "vulnerability.severity", "size": 10 } },
    "por_host": { "terms": { "field": "agent.name", "size": 50 },
                  "aggs": { "sev": { "terms": { "field": "vulnerability.severity", "size": 10 } },
                            "os":  { "terms": { "field": "host.os.full", "size": 1 } } } },
    "graves": { "filter": { "terms": { "vulnerability.severity": ["Critical", "High"] } },
                "aggs": { "cve": { "terms": { "field": "vulnerability.id", "size": 25 },
                                   "aggs": { "sev":   { "terms": { "field": "vulnerability.severity", "size": 1 } },
                                             "pkg":   { "terms": { "field": "package.name", "size": 2 } },
                                             "hosts": { "terms": { "field": "agent.name", "size": 10 } },
                                             "cvss":  { "max":   { "field": "vulnerability.score.base" } } } } } },
    "paquetes": { "terms": { "field": "package.name", "size": 15 },
                  "aggs": { "hosts": { "terms": { "field": "agent.name", "size": 10 } } } }
  }
}
EOF

curl -sSk -K "$TMP/cred" -H 'Content-Type: application/json' \
  "https://127.0.0.1:9200/wazuh-states-vulnerabilities-*/_search" -d @"$TMP/q.json" > "$TMP/r.json"

python3 - "$TMP/r.json" "$ETQ" > "$OUT" <<'PY'
import json, sys, datetime
r = json.load(open(sys.argv[1])); etq = sys.argv[2]
if "aggregations" not in r:
    sys.exit("ERROR del indexer: " + json.dumps(r)[:400])
a = r["aggregations"]; ORD = ["Critical", "High", "Medium", "Low"]
def sev(b): return {x["key"]: x["doc_count"] for x in b["buckets"]}
tot = sev(a["por_sev"]); otras = sum(v for k, v in tot.items() if k not in ORD)
print(f"# Ciclo de vulnerabilidades 01: {etq}\n")
print(f"- Fecha: {datetime.datetime.now(datetime.timezone.utc):%d/%m/%Y %H:%M} UTC (Ecuador = UTC-5)")
print("- Fuente: Wazuh 4.14.10, Vulnerability Detection (indice wazuh-states-vulnerabilities-*)")
print(f"- Total: **{r['hits']['total']['value']}** vulnerabilidades\n")
print("## Total por severidad\n\n| Severidad | Total |\n|---|---:|")
for k in ORD: print(f"| {k} | {tot.get(k, 0)} |")
if otras: print(f"| Sin severidad | {otras} |")
print("\n## Por host\n\n| Host | Sistema | Critical | High | Medium | Low | Total |\n|---|---|---:|---:|---:|---:|---:|")
for h in a["por_host"]["buckets"]:
    s = sev(h["sev"]); so = h["os"]["buckets"][0]["key"] if h["os"]["buckets"] else "-"
    print(f"| {h['key']} | {so} | " + " | ".join(str(s.get(k, 0)) for k in ORD) + f" | {h['doc_count']} |")
print("\n## Top 25 CVE criticas y altas\n\n| CVE | Severidad | CVSS | Paquete | Hosts |\n|---|---|---:|---|---|")
for c in a["graves"]["cve"]["buckets"]:
    sv = c["sev"]["buckets"][0]["key"]; cv = c["cvss"]["value"]
    pk = ", ".join(x["key"] for x in c["pkg"]["buckets"]); hs = ", ".join(x["key"] for x in c["hosts"]["buckets"])
    print(f"| {c['key']} | {sv} | {round(cv, 1) if cv is not None else '-'} | {pk} | {hs} |")
print("\n## Paquetes con mas vulnerabilidades\n\n| Paquete | Vulnerabilidades | Hosts |\n|---|---:|---|")
for p in a["paquetes"]["buckets"]:
    print(f"| {p['key']} | {p['doc_count']} | " + ", ".join(x["key"] for x in p["hosts"]["buckets"]) + " |")
PY

echo "== Informe guardado en $OUT"
cat "$OUT"
