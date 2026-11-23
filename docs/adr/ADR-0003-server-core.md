# ADR-0003 · Controlador de dominio en Windows Server 2025 Core

| Estado | Fecha | Fase |
|---|---|---|
| Aceptada | 2026-11-13 | 3 |

## Contexto
Hace falta un directorio activo (corp.lab.internal) para identidades, GPO y DNS interno. La memoria es escasa y el
controlador de dominio es el servidor más sensible del laboratorio.

## Decisión
DC01 con Windows Server 2025 en instalación Server Core (sin escritorio), 2,5 GB de RAM, UEFI + TPM 2.0, administrado por
PowerShell. Desde Proxmox se le envían comandos con el agente QEMU (`qm guest exec 201 -- powershell ...`).

## Alternativas consideradas
- **Desktop Experience**: consola gráfica (GPMC, ADUC), pero más memoria, más parches y más superficie de ataque.
- **Samba AD en Linux**: más ligero, pero no representa el entorno Windows habitual en empresas.

## Consecuencias
- Toda la gestión de AD y GPO se hace con PowerShell y queda en scripts reutilizables.
- La consola noVNC no permite pegar texto: se usa `qm guest exec` (y `-EncodedCommand` para scripts largos).
- Menos parches y menos vulnerabilidades: en el ciclo de la Fase 7.4, DC01 pasó de 2.724 a 2 vulnerabilidades.
- La unión de los Linux al dominio se automatiza con el rol de Ansible `ad_member` y una cuenta delegada (`svc-adjoin`)
  que solo puede gestionar equipos de OU=Linux.
