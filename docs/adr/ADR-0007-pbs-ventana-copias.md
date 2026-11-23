# ADR-0007 · Proxmox Backup Server con ventana diaria de copias

| Estado | Fecha | Fase |
|---|---|---|
| Aceptada | 2026-11-22 | 9 |

## Contexto
Se necesitan copias cifradas, verificadas y con retención de todas las VM, y una segunda copia en otro soporte. Con 20 GB
de RAM en PVE01, PBS (2 GB) y SRV-SIEM01 (6 GB) no caben a la vez con el resto de servicios encendidos, y el portátil
suele estar apagado de madrugada.

## Decisión
- **Proxmox Backup Server** (SRV-PBS01, VLAN 60) con datastore `ds-main`, cifrado en el cliente (Proxmox), verificación
  de cada copia al terminar, retención (last 3, daily 7, weekly 4, monthly 3) y un datastore extraíble `ds-usb`
  (disco en una carpeta del anfitrión) que se sincroniza cada sábado.
- **Ventana diaria a las 22:00** (temporizador en PVE01, también al arrancar si se perdió): se apaga el SIEM, se enciende
  PBS, se copian las VM, PBS hace su mantenimiento y, pase lo que pase, se apaga PBS y vuelve el SIEM.

## Alternativas consideradas
- **vzdump a almacenamiento local**: sin deduplicación ni cifrado ni verificación, y cada copia ocupa el disco entero.
- **PBS siempre encendido y SIEM apagado**: copias garantizadas, pero el laboratorio sin vigilancia.
- **Reducir la memoria del SIEM**: fue la causa de su caída por falta de memoria en la Fase 7.
- **Copia de madrugada (02:00)**: el portátil normalmente está apagado a esa hora.

## Consecuencias
- El SIEM no vigila unos 6 minutos al día (ventana documentada).
- PVE01 lanza el mantenimiento de PBS por SSH con una clave restringida (`restrict`, comando forzado, `from`).
- La clave de cifrado de PBS es imprescindible: sin ella las copias no sirven (debe estar fuera del portátil).
- Copia 3 fuera del sitio: riesgo aceptado (PBS 4.2 admite S3 si se contrata).
- Simulacros DR-01 a DR-06 superados (docs/dr/resultados-simulacros.md).
