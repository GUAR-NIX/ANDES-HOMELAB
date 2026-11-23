# Rutinas operativas

| Rutina | Frecuencia | Cómo | Estado |
|---|---|---|---|
| Copias de seguridad | Diaria 22:00 | Ventana automática en PVE01 (ADR-0007); log en `/var/log/andes-ventana-backup.log` | En marcha |
| Revisión semanal | Lunes 09:00 | `scripts/revision-semanal.py` (temporizador en ADM-ANS01): copias, alertas, SLO, disco, certificados, Wazuh, parches; informe en [informes/](informes/) | En marcha |
| Parcheo mensual | Segundo martes | RB-03: `ansible-playbook patch.yml` (rol `patching`, uno a uno) | En marcha |
| Revisión de accesos | Día 1 de cada trimestre | `scripts/revision-accesos.py` (temporizador en ADM-ANS01): AD privilegiado, Proxmox, claves SSH contra la línea base + lista manual; informe en [accesos/](accesos/) | En marcha |
| Capacidad | Mensual | Panel Grafana "Capacidad PVE01", alertas CapacidadThinPool/CapacidadRamPVE01 y [capacidad.md](capacidad.md) | En marcha |
| Inventario | Tras cada cambio de VM | `python3 scripts/inventario.py` y commit | En marcha |

## Hallazgos pendientes
- 2026-11-22 · RESUELTO: SRV-APP01 con el kernel 6.8.0-147 (reconstruido desde la plantilla). El rol de parcheo lo
  reinició con el 151 y purgó el viejo.
- 2026-11-22 · RESUELTO: `openipmi.service` fallido en 4 servidores (`ipmitool` llega como recomendado de
  node-exporter-collectors) y sockets de SSSD fallidos en SRV-APP01. Corregidos en los roles node_exporter y ad_member.
- 2026-11-22 · RESUELTO (revisión de accesos 2026-T4): root tenía en los 5 Linux una clave autorizada (la deja cloud-init) y
  labadmin@adm-ans01 aceptaba la clave de la plantilla, cuya privada está en PVE01. Retiradas con el rol hardening.
- 2026-11-22 · Pendiente: alertas "promiscuous mode" de auditd en MON01 y SRV-APP01 (las provoca Docker al crear sus
  interfaces): afinar la regla en Wazuh para esos hosts.
