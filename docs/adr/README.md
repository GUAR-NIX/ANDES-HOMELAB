# Registro de decisiones de arquitectura (ADR)

Cada decisión que condiciona el diseño queda escrita con su contexto, la alternativa elegida, las descartadas y lo que
implica. Un ADR no se edita para cambiar la decisión: se escribe uno nuevo que lo sustituye y se marca el antiguo.

| ADR | Decisión | Estado |
|---|---|---|
| [0001](ADR-0001-proxmox-anidado.md) | Proxmox VE anidado en VMware Workstation sobre el portátil | Aceptada |
| [0002](ADR-0002-seis-vlan.md) | Seis VLAN con OPNsense y denegación por defecto entre segmentos | Aceptada |
| [0003](ADR-0003-server-core.md) | Controlador de dominio en Windows Server 2025 Core | Aceptada |
| [0004](ADR-0004-estado-terraform.md) | Estado de Terraform fuera de Git | Aceptada |
| [0005](ADR-0005-terraform-bpg.md) | Proveedor bpg/proxmox e importación de las VM existentes | Aceptada |
| [0006](ADR-0006-ca-intermedia.md) | PKI propia de dos niveles (raíz + emisora) en OPNsense | Aceptada |
| [0007](ADR-0007-pbs-ventana-copias.md) | Proxmox Backup Server con ventana diaria de copias | Aceptada |
| [0008](ADR-0008-opnsense-xml-cifrado.md) | Copia de OPNsense cifrada en git en lugar de os-git-backup | Aceptada |

## Plantilla

```markdown
# ADR-00XX · Título corto

| Estado | Fecha | Fase |
|---|---|---|
| Propuesta / Aceptada / Sustituida por ADR-00YY | AAAA-MM-DD | N |

## Contexto
Qué problema hay y qué restricciones existen.

## Decisión
Qué se hace, en una o dos frases claras.

## Alternativas consideradas
- Opción A: por qué no.
- Opción B: por qué no.

## Consecuencias
Lo que se gana, lo que se acepta y lo que queda por vigilar.
```
