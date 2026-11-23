# Revisión semanal 2026-W47

Generada el 2026-11-22 18:48 con `scripts/revision-semanal.py`.

## Resumen

- ⚠ solo 1 día(s) con copia correcta en la última semana (esperado: 7)

## 1. Copias de seguridad (ventana de las 22:00)

| Fecha | Estado | Duración |
|---|---|---|
| 2026-11-21 21:25 | OK | 0 min 24 s |
| 2026-11-22 07:18 | OK | 6 min 22 s |
| 2026-11-22 13:11 | OK | 2 min 56 s |

Días con copia correcta: **1/7**.

## 2. Alertas de Prometheus

| Alerta | Severidad | Muestras en alerta |
|---|---|---|
| HostCaido | critical | 2 |
| WebNoDisponible | critical | 2 |

## 3. SLO de Andes App

Disponibilidad de Andes App: **95.616 %** en 16.2 h medidas; 42.5 min sin servicio (presupuesto semanal 100,8 min, objetivo 99 %): **CUMPLIDO**.

## 4. Disco

| Servidor | Disco / usado |
|---|---|
| 10.10.10.10 | 35 % |
| 10.10.10.20 | 17 % |
| 10.10.20.30 | 23 % |
| 10.10.50.10 | 15 % |
| PVE01 local-lvm | 59 % |
| PVE01 local | 23 % |

## 5. Certificados

| Servicio | Caduca | Días |
|---|---|---|
| app.corp.lab.internal:443 | Nov 14 02:40:40 2027 GMT | 356 |
| srv-web01.corp.lab.internal:443 | Nov 14 02:40:40 2027 GMT | 356 |
| grafana.corp.lab.internal:443 | Nov 14 20:05:37 2027 GMT | 357 |
| wazuh.corp.lab.internal:443 | Nov 15 15:59:29 2027 GMT | 357 |
| pve01.corp.lab.internal:8006 | Nov 14 04:04:02 2027 GMT | 356 |

## 6. Alertas de Wazuh (nivel ≥ 10)

| Nivel | Regla | Agente | Veces | Última (UTC) |
|---|---|---|---|---|
| 10 | Auditd: Device enables promiscuous mode. | mon01 | 24 | 2026-11-22 12:02 |
| 10 | Auditd: Device enables promiscuous mode. | srv-app01 | 10 | 2026-11-22 18:43 |
| 10 | Multiple pfSense firewall blocks events from same source. | srv-siem01 | 8 | 2026-11-22 18:33 |
| 10 | CVE-2025-66418 affects python3-pip-whl | adm-ans01 | 1 | 2026-11-22 00:26 |
| 10 | CVE-2026-11332 affects ansible-core | adm-ans01 | 1 | 2026-11-21 23:26 |

## 7. Servidores Linux

| Servidor | Paquetes pendientes | Unidades caídas | Reinicio pendiente | Kernel |
|---|---|---|---|---|
| adm-ans01 | 0 | 0 | no | 6.8.0-151-generic |
| mon01 | 0 | 0 | no | 6.8.0-151-generic |
| srv-app01 | 0 | 0 | no | 6.8.0-151-generic |
| srv-siem01 | 0 | 0 | no | 6.8.0-151-generic |
| srv-web01 | 0 | 0 | no | 6.8.0-151-generic |

