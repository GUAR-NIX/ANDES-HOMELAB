# ADR-0002 · Seis VLAN con OPNsense y denegación por defecto

| Estado | Fecha | Fase |
|---|---|---|
| Aceptada | 2026-11-11 | 2 |

## Contexto
Los servidores tienen funciones y niveles de exposición distintos: administración, servicios internos, usuarios,
seguridad, servicios publicados y copias. Si un equipo de usuario o la DMZ se comprometen, el atacante no debe poder
alcanzar el resto de la red.

## Decisión
Un puente VLAN-aware (vmbr1) en Proxmox lleva seis VLAN hasta OPNsense 26.7, que enruta y filtra entre ellas:

| VLAN | Red | Uso |
|---|---|---|
| 10 MGMT | 10.10.10.0/24 | ADM-ANS01 (único punto de administración) y MON01 |
| 20 SERVERS | 10.10.20.0/24 | DC01 y SRV-APP01 |
| 30 USERS | 10.10.30.0/24 | Equipos de usuario (DHCP) |
| 40 SEC | 10.10.40.0/24 | SRV-SIEM01 |
| 50 DMZ | 10.10.50.0/24 | SRV-WEB01 (proxy publicado) |
| 60 BKP | 10.10.60.0/24 | SRV-PBS01 |

Todo el tráfico entre segmentos está bloqueado (F03/F05) salvo los flujos documentados en la matriz (F01-F12), cada uno
con su alias de origen, destino y puerto. La administración entra solo por la VPN WireGuard (10.99.0.0/24).

## Alternativas consideradas
- **Red plana**: más sencilla, pero sin contención de movimientos laterales.
- **Menos VLAN** (por ejemplo, servidores y usuarios): mezclaría servicios publicados o el SIEM con servidores internos.
- **Firewall en cada servidor como único control**: se mantiene UFW como segunda capa, pero no sustituye al perímetro.

## Consecuencias
- Cada servicio nuevo exige un flujo explícito en la matriz: más trabajo, pero queda documentado y auditable.
- Lecciones: en OPNsense una regla clonada queda con secuencia 1000, por detrás del bloqueo (300); las excepciones van en
  200-240. Las reglas en la WAN hacia la red interna necesitan "Disable reply-to".
- Los bloqueos entre segmentos llegan al SIEM (syslog de OPNsense, regla propia 100100).
