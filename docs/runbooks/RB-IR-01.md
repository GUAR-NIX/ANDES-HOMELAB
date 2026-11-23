# RB-IR-01 · Respuesta a alteración no autorizada de la web pública

| Campo | Valor |
|---|---|
| Versión | 1.0 (21/11/2026) |
| Responsable | Erick Guarnizo (guarnix), responsable de respuesta a incidentes |
| Marco | NIST SP 800-61: preparación, detección y análisis, contención, erradicación, recuperación y lecciones aprendidas |
| Alcance | SRV-WEB01 (VM 150, DMZ, 10.10.50.10): nginx que publica https://app.corp.lab.internal |
| Detección principal | Wazuh UC-01 (FIM con who-data en /var/www y /etc/nginx), apoyada por UC-02 (SSH) y los logs de OPNsense |

## 1. Severidad y tiempos objetivo

| Nivel | Criterio | Ejemplo | Contención objetivo |
|---|---|---|---|
| SEV-1 Crítica | Servicio público alterado o caído, o cuenta privilegiada comprometida | Página de app.corp.lab.internal sustituida | 30 min |
| SEV-2 Alta | Servidor comprometido sin impacto visible en el servicio | Clave SSH desconocida en un servidor | 4 h |
| SEV-3 Media | Actividad sospechosa sin compromiso confirmado | Fuerza bruta SSH bloqueada (UC-02) | 24 h |
| SEV-4 Baja | Ruido o falso positivo | Regla que necesita afinado | Siguiente revisión |

## 2. Contactos y comunicación

| Rol | Quién | Canal |
|---|---|---|
| Responsable de incidentes y analista | Erick Guarnizo (adm-erick) | Consola de Wazuh y Telegram (@andes_guarnix_alertas_bot) |
| Dirección (ficticio) | Gerencia de Andes Logística | Aviso al declarar SEV-1 y al cerrar |
| Proveedor de la aplicación (ficticio) | Equipo de Andes App | Si hay que redesplegar la aplicación |

Las horas se registran en UTC (los servidores y Wazuh usan UTC; Ecuador es UTC-5).

## 3. Preparación (antes de cualquier incidente)

- [ ] Copia buena de la configuración de nginx en el repositorio git de ADM-ANS01 (`~/andes-config`, script `preparar-ir.sh`) con su SHA-256. Es la fuente de verdad para recuperar.
- [ ] Línea base de persistencia de SRV-WEB01 guardada en el repositorio: claves autorizadas, cron, usuarios y servicios.
- [ ] Wazuh: los cinco agentes activos y UC-01/UC-02 probados (7.3).
- [ ] Snapshots: Proxmox puede crear snapshots de la VM 150 (probado en la 7.4).
- [ ] Acceso fuera de banda: `qm terminal 150` desde la Shell de PVE01 (consola serie con labadmin y contraseña). Sirve aunque la VM esté aislada de la red.
- [ ] VLAN de cuarentena: tag 999, que no tiene interfaz en OPNsense, así que no enruta ni recibe tráfico.

## 4. Detección y análisis

1. **Disparador**: alerta FIM 550 (modificado), 553 (borrado) o 554 (creado) en srv-web01 sobre /var/www o /etc/nginx, o un aviso de un usuario.
2. **Validar** en Wazuh → Threat Hunting → `agent.name: srv-web01`, en la ventana de tiempo afectada:
   - Qué cambió: ruta, hashes antes/después y diff si hay report_changes.
   - Quién y con qué: `syscheck.audit.login_user`, `effective_user` y `process.name` de who-data.
   - Cuándo: hora de la primera alerta.
3. **Correlacionar**:
   - Accesos SSH: reglas 5715 (inicio de sesión aceptado) y 5501/5502 (apertura y cierre de sesión), con IP de origen.
   - Uso de sudo: regla 5402 y comandos ejecutados.
   - Firewall: logs de OPNsense con origen o destino 10.10.50.10.
4. **Comprobar el impacto**: abrir https://app.corp.lab.internal y guardar captura.
5. **Declarar el incidente**: asignar número (INC-000N) y severidad, y abrir la línea de tiempo en `docs/incidents/INC-000N.md`.

## 5. Contención

1. **Snapshot forense** antes de tocar nada (Shell de PVE01):
   `qm snapshot 150 inc000N_forense --description "Evidencia INC-000N"`
2. **Aislar** la VM en la VLAN de cuarentena, sin apagarla para no perder el estado:
   ```
   NET=$(qm config 150 | awk '/^net0:/{print $2}')
   qm set 150 --net0 "$(echo "$NET" | sed -E 's/tag=[0-9]+/tag=999/')"
   ```
3. **Verificar el aislamiento**: el ping desde ADM-ANS01 a 10.10.50.10 falla y el agente pasa a "disconnected" en Wazuh.
4. Anotar la hora de contención. A partir de aquí el servicio está caído a propósito: es preferible a seguir mostrando la página alterada.

## 6. Erradicación (por la consola serie: `qm terminal 150`, salir con Ctrl+O)

- [ ] **Vector**: con qué cuenta y desde qué IP se hizo el cambio (`last -ai`, `journalctl -u ssh --since "-6h"`, `/var/log/auth.log`).
- [ ] **Archivos cambiados** en las últimas horas: `sudo find /etc /usr/local /var/www /var/lib /home /root -xdev -type f -mmin -360`.
- [ ] **Persistencia**:
  - cron: `/etc/cron.d`, `/etc/crontab` y `crontab -l` de root y de cada usuario.
  - systemd: `systemctl list-timers`, y unidades nuevas en /etc/systemd/system.
  - Claves SSH: `ssh-keygen -lf ~/.ssh/authorized_keys` de cada usuario, comparadas con la línea base.
  - Usuarios: UID ≥ 1000 o UID 0 nuevos, y cambios en los grupos sudo.
- [ ] **Eliminar** lo encontrado. Guardar antes una copia en /root/inc000N/ como evidencia.
- [ ] **Rotar credenciales**: quitar las claves desconocidas. Si la clave legítima pudo haberse filtrado, generar un par nuevo y retirar el antiguo.
- [ ] Anotar la hora de erradicación.

## 7. Recuperación

1. **Volver a la DMZ**: el mismo comando de la contención, con `tag=50`.
2. **Redesplegar desde git** con `desplegar-web.sh` en ADM-ANS01. El script verifica el SHA-256 del repositorio, instala la configuración, ejecuta `nginx -t`, recarga nginx y compara el hash instalado.
3. **Validar**:
   - https://app.corp.lab.internal muestra Andes App.
   - El agente de Wazuh vuelve a "active".
   - No aparecen nuevas alertas FIM en srv-web01.
4. **Vigilancia reforzada**: revisar las alertas de srv-web01 durante 24 h. En el laboratorio, al menos 30 min: si quedara persistencia, la alteración volvería a aparecer.
5. Anotar la hora de recuperación y borrar el snapshot forense cuando se cierre el informe.

## 8. Lecciones aprendidas (máximo 5 días después del cierre)

Post-mortem sin culpables en `docs/incidents/INC-000N.md`:

- Resumen
- Impacto
- Línea de tiempo (UTC)
- Causa raíz
- Qué funcionó y qué no
- Métricas:
  - **MTTD**: del cambio a la primera alerta.
  - **MTTC**: de la alerta a la contención.
  - **MTTR**: de la alerta al servicio restablecido.
- Acciones, cada una con responsable y fecha.
