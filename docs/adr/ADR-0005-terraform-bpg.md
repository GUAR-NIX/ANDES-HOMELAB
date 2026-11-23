# ADR-0005 · Proveedor bpg/proxmox e importación de las VM existentes

| Estado | Fecha | Fase |
|---|---|---|
| Aceptada | 2026-11-21 | 8 |

## Contexto
Las VM se habían creado a mano en las fases anteriores. Para poder reconstruirlas desde código (y demostrarlo), su
definición tenía que pasar a Terraform sin recrear servidores que ya funcionaban.

## Decisión
Terraform 1.17 con el proveedor **bpg/proxmox** (versión fijada `~> 0.123`), una única definición de recurso con
`for_each` sobre los servidores descritos como datos, e **importación** de las VM existentes (`terraform import`).
Los atributos que solo importan al nacer la VM (clon, cloud-init, disco, MAC) van en `ignore_changes`.

## Alternativas consideradas
- **Proveedor Telmate/proxmox**: el más antiguo, pero con menos mantenimiento y peor soporte de Proxmox 9.
- **Recrear todas las VM**: más limpio, pero con pérdida de configuración y riesgo innecesario.
- **Solo Ansible**: configura servidores, pero no crea ni versiona la infraestructura.

## Consecuencias
- El token de Terraform tiene un rol mínimo (TerraformProv) y solo se usa desde ADM-ANS01 (flujo F12).
- El estado vive fuera de Git (ADR-0004).
- La plantilla no trae qemu-guest-agent: un snippet de cloud-init lo instala y el tiempo de espera del agente baja a
  2 min (antes una VM nueva tardaba 16 min).
- Demostrado: SRV-WEB01 se reconstruye en 7 min 19 s (T30) y SRV-APP01 en 6 min 53 s (DR-03).
- PBS también está en Terraform (pbs.tf), aunque se instala desde su ISO.
