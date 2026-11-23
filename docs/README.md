# Documentación de operación · Andes (corp.lab.internal)

Objetivo: que otra persona pueda operar el laboratorio leyendo estos documentos.

| Carpeta | Contenido |
|---|---|
| [adr/](adr/README.md) | Decisiones de arquitectura: por qué el diseño es como es |
| [runbooks/](runbooks/README.md) | Procedimientos paso a paso: altas, certificados, parcheo, disco lleno, restauraciones, incidentes |
| [cambios/](cambios/README.md) | Gestión de cambios: tipos, registro y plantilla |
| [incidents/](incidents/INC-0001.md) | Informes de incidentes con línea de tiempo, causa raíz y acciones |
| [dr/](dr/plan-continuidad.md) | Plan de continuidad, resultados de los simulacros y recuperación del firewall |
| [inventario/](inventario/inventario.md) | Inventario de VM y servidores, generado con `scripts/inventario.py` |
| [diagramas/](diagramas/README.md) | Red y flujos, dependencias, copias y flujo de cambios (Mermaid) |
| [operacion/](operacion/README.md) | Rutinas: revisión semanal, parcheo mensual, revisión de accesos, capacidad |

## Primeros pasos para quien llega
1. Conectar la VPN WireGuard (`lab-mgmt`) y entrar en ADM-ANS01: `ssh labadmin@10.10.10.10`.
2. Leer las ADR 0001, 0002 y 0007 y el diagrama de red.
3. Comprobar el estado: `~/andes-config/scripts/verificar-servicios.sh`.
4. Antes de tocar nada: abrir un cambio (docs/cambios) y seguir el runbook correspondiente.

Los secretos no están en este repositorio: viven en Ansible Vault (`ansible/group_vars/all/vault.yml`, cifrado), en
`~/.secrets` de ADM-ANS01 (permisos 600) y en el gestor de contraseñas del responsable.
