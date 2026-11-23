# ADR-0001 · Proxmox VE anidado en VMware Workstation

| Estado | Fecha | Fase |
|---|---|---|
| Aceptada | 2026-11-05 | 0-1 |

## Contexto
El laboratorio tiene que reproducir una empresa pequeña (firewall, dominio, servidores, monitorización, SIEM, copias)
con un único equipo: un portátil con Windows 11, 32 GB de RAM y un AMD Ryzen 9, que también se usa a diario. No hay
hardware libre para instalar un hipervisor directamente.

## Decisión
Instalar Proxmox VE 9.2 como máquina virtual de VMware Workstation (PVE01, 8 vCPU, 20 GB de RAM, disco NVMe de 300 GB,
red NAT de VMware) con la virtualización anidada AMD-V activada, y crear dentro todas las VM del laboratorio.

## Alternativas consideradas
- **Proxmox en el equipo físico**: el mejor rendimiento, pero el portátil dejaría de ser un equipo de uso diario.
- **Solo VMware Workstation**: sin API, sin plantillas cloud-init, sin Terraform ni PBS; no se parece a un entorno real.
- **Hyper-V**: entra en conflicto con VMware y su ecosistema de automatización es menor en entornos Linux.

## Consecuencias
- Hay que desactivar en Windows la integridad de memoria (HVCI/VBS) y Secure Launch para que VMware exponga AMD-V.
- Sobrecarga de la virtualización anidada y presupuesto de memoria ajustado: 20 GB para todo el laboratorio
  (perfiles de encendido, RAM fija en las VM con estado, ventana de copias de la ADR-0007).
- Un único anfitrión: sin alta disponibilidad, y las copias 1 y 2 comparten el disco físico (riesgo aceptado).
- Si el PC se apaga de golpe o con PVE01 suspendido, el reloj del laboratorio se atrasa y rompe DNSSEC, TOTP y
  Kerberos: hay que corregir la hora en cadena (PVE01, OPNsense, VM). Apagar siempre Proxmox antes que el PC.
- Proxmox se administra por la red NAT de VMware (192.168.188.10), fuera de las VLAN del laboratorio.
