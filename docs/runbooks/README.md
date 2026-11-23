# Runbooks

Procedimientos para operar el laboratorio sin depender de quien lo montó. Formato: **disparador → pasos → verificación →
reversión**. Todos los comandos se lanzan desde ADM-ANS01 (`ssh labadmin@10.10.10.10` por la VPN) salvo que se indique la
Shell de PVE01 (`https://192.168.188.10:8006` → pve01 → Shell).

| Runbook | Cuándo |
|---|---|
| [RB-01](RB-01-alta-empleado.md) | Alta (y baja) de un empleado en el directorio activo |
| [RB-02](RB-02-renovar-certificado.md) | Un certificado interno caduca en menos de 30 días |
| [RB-03](RB-03-parcheo-mensual.md) | Parcheo mensual (segundo martes) o vulnerabilidad crítica |
| [RB-04](RB-04-disco-lleno.md) | Alerta de disco por encima del 85 % |
| [RB-05](RB-05-restaurar-vm.md) | Hay que recuperar una VM, un archivo o un servidor completo |
| [RB-IR-01](RB-IR-01.md) | Alteración no autorizada de la web pública (incidente) |
| [RB-DR-04](../dr/RB-DR-04-firewall.md) | Recuperación del firewall |

Reglas comunes:
- Todo cambio en producción tiene un registro en [docs/cambios](../cambios/README.md).
- Antes de un cambio con riesgo: comprobar que la copia más reciente en PBS tiene verificación OK.
- Los secretos nunca se escriben en los tickets ni en Git: viven en Ansible Vault, `~/.secrets` o el gestor de contraseñas.
