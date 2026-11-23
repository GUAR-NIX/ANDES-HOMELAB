# Gestión de cambios

Todo cambio en la infraestructura en producción se registra antes de hacerse. Los cambios de código (Terraform, Ansible,
scripts) además pasan por un PR con el CI en verde; el registro enlaza el commit o el PR.

| Tipo | Ejemplo | Aprobación |
|---|---|---|
| Estándar | Alta de empleado (RB-01), renovar certificado (RB-02) | Preaprobado: basta con seguir el runbook y anotarlo |
| Normal | Regla de firewall nueva, parcheo mensual, servidor nuevo | Registro previo con riesgo y reversión |
| Emergencia | Contención de un incidente | Se hace y se registra después, enlazado al INC |

## Registro

| ID | Fecha | Tipo | Cambio | Riesgo | Resultado | Referencia |
|---|---|---|---|---|---|---|
| CHG-0001 | 2026-11-05 | Normal | Hipervisor PVE01 (Proxmox VE 9.2 anidado) | Bajo (nuevo) | OK | ADR-0001, Fase 1 |
| CHG-0002 | 2026-11-11 | Normal | OPNsense, 6 VLAN y matriz de flujos F01-F11 | Medio | OK | ADR-0002, Fase 2 |
| CHG-0003 | 2026-11-12 | Normal | VPN WireGuard como única vía de administración | Medio (pérdida de acceso) | OK | Fase 2 |
| CHG-0004 | 2026-11-13 | Normal | Dominio corp.lab.internal (DC01) y GPO | Medio | OK | ADR-0003, Fase 3 |
| CHG-0005 | 2026-11-13 | Normal | PKI Andes-Root-CA / Andes-Issuing-CA y TLS interno | Bajo | OK | ADR-0006, Fase 4 |
| CHG-0006 | 2026-11-14 | Normal | Andes App en Docker y proxy en la DMZ (F04) | Medio | OK | Fase 5 |
| CHG-0007 | 2026-11-14 | Normal | Monitorización (Prometheus, Grafana, alertas) | Bajo | OK | Fase 6 |
| CHG-0008 | 2026-11-15 | Normal | SIEM Wazuh y agentes | Medio (memoria) | OK tras corregir ballooning | Fase 7 |
| CHG-7.4-01 | 2026-11-21 | Normal | Parcheo de los 4 Linux y DC01 + CIS | Medio (reinicios) | OK, 1 h 06 min; vulnerabilidades -79 % | RB-03, Fase 7.4 |
| CHG-0009 | 2026-11-21 | Normal | Flujo F12 (ADM-ANS01 → API de Proxmox) | Bajo | OK (secuencia 240) | Fase 8.1 |
| CHG-0010 | 2026-11-21 | Normal | Terraform importa MON01, SRV-APP01 y SRV-WEB01 | Medio | OK, plan sin cambios | ADR-0005, 15cbd36 |
| CHG-0011 | 2026-11-21 | Normal | Ansible aplica la línea base (corrige deriva CIS de SRV-SIEM01) | Medio | OK, changed=0 en la segunda pasada | fc903ce |
| CHG-0012 | 2026-11-21 | Normal | Reconstrucción de SRV-WEB01 desde código (T30) | Alto (servicio caído) | OK, 7 min 19 s | c9c1e3d |
| CHG-0013 | 2026-11-21 | Normal | SRV-PBS01, flujo F09 y ruta en PVE01 | Medio | OK | ADR-0007, Fase 9 |
| CHG-0014 | 2026-11-22 | Normal | Simulacros DR-01 a DR-06 | Alto (cortes controlados) | OK | docs/dr |
| CHG-0015 | 2026-11-22 | Normal | Rol ad_member y cuenta delegada svc-adjoin | Medio | OK, T14 | a2a4e4c |
| CHG-0016 | 2026-11-22 | Emergencia | Corrección de la hora tras un apagón (reinicio de OPNsense) | Medio (corte de VPN) | OK | Bitácora 9.5 |
| CHG-0017 | 2026-11-22 | Normal | Ventana diaria de copias a las 22:00 y puerto 22 en PORT_PBS | Medio | OK, copia 2 min 56 s | ADR-0007, e5b68aa |
| CHG-0018 | 2026-11-22 | Normal | Parcheo con el rol patching (reinicio de SRV-APP01 al kernel 151); fuera ipmitool/openipmi y sockets de SSSD | Medio (reinicio) | OK, 1 min 43 s; 0 unidades caídas | RB-03, eba0a78 |
| CHG-0019 | 2026-11-22 | Normal | Sin claves SSH de root y sin la clave de la plantilla en labadmin (INC-0001 acción 3, parte) | Medio (acceso) | OK; acceso de administración comprobado | revisión de accesos 2026-T4 |

## Plantilla

```markdown
# CHG-00XX · Título

| Campo | Valor |
|---|---|
| Solicitante / ejecutor | |
| Tipo | Estándar / Normal / Emergencia |
| Ventana | AAAA-MM-DD HH:MM - HH:MM |
| Sistemas afectados | |
| Riesgo | Bajo / Medio / Alto, y por qué |

**Qué y por qué**
**Prueba previa** (--check, terraform plan, simulacro…)
**Pasos**
**Verificación** (cómo se sabe que salió bien)
**Reversión** (cómo se deshace y cuánto tarda)
**Resultado** (hora real de inicio y fin, incidencias, enlace al commit/PR)
```
