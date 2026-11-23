# RB-02 · Renovar un certificado interno

**Disparador:** la revisión semanal avisa de que un certificado caduca en menos de 30 días, o un navegador da error.
**Duración:** 15 min por certificado. **Riesgo:** bajo (el servicio se recarga, no se reinicia la VM).

## Certificados en uso (emitidos por Andes-Issuing-CA, ADR-0006)

| Certificado | Servicio | Dónde se instala |
|---|---|---|
| srv-web01 (app.corp.lab.internal, srv-web01) | Proxy nginx de la DMZ | Rol Ansible `nginx_proxy` (fullchain en el rol, clave en Vault) |
| pve01 (IP 192.168.188.10) | Web de Proxmox | `pvenode cert set` en PVE01 |
| mon01 (grafana.corp.lab.internal) | Grafana | MON01: /opt/monitoring/tls/grafana-fullchain.pem y grafana.key (dueño 472:0) |
| siem01 (wazuh.corp.lab.internal) | Panel de Wazuh | SRV-SIEM01: /etc/wazuh-dashboard/certs/wazuh-dashboard.pem y wazuh-dashboard-key.pem |

## Comprobar fechas
```bash
for h in app.corp.lab.internal:443 grafana.corp.lab.internal:443 wazuh.corp.lab.internal:443 192.168.188.10:8006; do
  printf '%-32s ' "$h"; echo | openssl s_client -connect "$h" -servername "${h%%:*}" 2>/dev/null | openssl x509 -noout -enddate
done
```

## Pasos
1. **Emitir** en OPNsense (Sistema → Confianza → Certificados → +): método *Crear un certificado interno*, CA
   **Andes-Issuing-CA**, tipo *Server Certificate*, RSA 2048 o EC, duración 397 días, mismo CN y los mismos SAN que el
   anterior (DNS e IP). Descargar el certificado y la clave.
2. **Instalar** según el servicio:
   - **srv-web01**: sustituir `ansible/roles/nginx_proxy/files/srv-web01-fullchain.pem` (certificado + emisora), actualizar
     la clave con `ansible-vault edit ansible/group_vars/all/vault.yml` (variable `vault_web_tls_key`), PR, CI en verde y
     `ansible-playbook site.yml --limit srv-web01` (valida con `nginx -t` antes de recargar).
   - **pve01**: en la Shell de PVE01, `pvenode cert set cert.pem key.pem --force --restart`.
   - **Grafana**: sustituir `/opt/monitoring/tls/grafana-fullchain.pem` y `grafana.key`, `chown 472:0` de la clave (la
     imagen corre como 472:0) y `docker compose -f /opt/monitoring/compose.yaml restart grafana`.
   - **Wazuh**: sustituir `/etc/wazuh-dashboard/certs/wazuh-dashboard.pem` y `wazuh-dashboard-key.pem` (mismos dueño y
     permisos que los anteriores) y `systemctl restart wazuh-dashboard`.
3. **Borrar** la clave descargada del equipo donde se descargó (`shred` o vaciar la papelera).

## Verificación
Repetir "Comprobar fechas": la nueva fecha debe ser la del certificado emitido. En el navegador, sin avisos (la raíz ya
está instalada en los equipos). Para la web pública: `curl -s -o /dev/null -w '%{http_code} %{ssl_verify_result}\n'
https://app.corp.lab.internal/` → `200 0`.

## Reversión
El certificado anterior sigue siendo válido hasta su fecha: reinstalarlo (git revert del cambio en el rol, o la copia del
archivo antiguo) y recargar el servicio. No revocar el anterior hasta comprobar el nuevo.
