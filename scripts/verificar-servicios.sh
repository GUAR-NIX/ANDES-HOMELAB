#!/bin/bash
# Comprobacion de punta a punta de los servicios gestionados por Ansible (se ejecuta en adm-ans01)
S="ssh -o BatchMode=yes -o ConnectTimeout=5"
echo "== srv-web01: clave TLS y node_exporter"
$S 10.10.50.10 'sudo stat -c "%a %U:%G %n" /etc/ssl/corp/srv-web01.key; echo "node_exporter: $(systemctl is-active prometheus-node-exporter)"; echo "wazuh-agent:   $(systemctl is-active wazuh-agent)"'
echo "== Proxy TLS de la DMZ"
for u in https://app.corp.lab.internal/ https://srv-web01.corp.lab.internal/; do
  curl -s -m 10 -o /dev/null -w "$u -> HTTP %{http_code}, certificado verificado=%{ssl_verify_result} (0 = OK)\n" "$u"
done
echo "== srv-app01: contenedores"
$S 10.10.20.30 'sudo docker compose -f /opt/andes-app/compose.yaml ps --format "{{.Name}}  {{.Status}}"'
echo "== mon01: Prometheus ve los node_exporter (solo mon01 puede consultar el 9100)"
$S 10.10.10.20 'curl -s -m 10 "http://localhost:9090/api/v1/query?query=up%7Bjob%3D~%22node.*%22%7D" | python3 -c "import sys,json; [print(r[\"metric\"].get(\"instance\"), \"up=\"+r[\"value\"][1]) for r in json.load(sys.stdin)[\"data\"][\"result\"]]"'
echo "== srv-siem01: agentes Wazuh"
$S 10.10.40.10 'sudo /var/ossec/bin/agent_control -l | grep "ID:"'
