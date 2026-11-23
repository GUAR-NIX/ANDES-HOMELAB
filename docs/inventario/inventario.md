# Inventario del laboratorio

Generado automáticamente el 2026-11-22 18:34 UTC con `scripts/inventario.py` (API de Proxmox + facts de Ansible). No editar a mano: regenerar.

## Anfitrión PVE01

Proxmox VE 9.2.26 · 8 vCPU · RAM 19.5 GB (libre 4.3 GB) · kernel 7.0.14-28-pve

| Almacenamiento | Tipo | Usado | Total |
|---|---|---|---|
| local | dir | 19 GB (23 %) | 83 GB |
| local-lvm | lvmthin | 111 GB (59 %) | 186 GB |

## Máquinas virtuales

| VMID | Nombre | Estado | vCPU | RAM (MB) | Balloon | VLAN | Discos | Arranque | Etiquetas |
|---|---|---|---|---|---|---|---|---|---|
| 100 | FW-OPN01 | running | 2 | 2048 | - | WAN + troncal | scsi0=16G | si |  |
| 110 | adm-ans01 | running | 2 | 1536 | 1024 | 10 MGMT | scsi0=16G | si |  |
| 120 | mon01 | running | 2 | 2048 | 0 | 10 MGMT | scsi0=25G | si | mon terraform |
| 130 | srv-app01 | running | 2 | 2560 | 0 | 20 SERVERS | scsi0=16G | si | app terraform |
| 140 | srv-siem01 | running | 4 | 6144 | 0 | 40 SEC | scsi0=60G | si |  |
| 150 | srv-web01 | running | 2 | 1536 | 1024 | 50 DMZ | scsi0=16G | si | dmz terraform |
| 160 | srv-pbs01 | stopped | 2 | 2048 | 0 | 60 BKP | scsi0=32G scsi1=120G scsi2=64G | no | pbs terraform |
| 201 | DC01 | running | 2 | 2560 | 0 | 20 SERVERS | scsi0=40G scsi1=30G | si |  |
| 301 | test-users | stopped | 2 | 1024 | 512 | 30 USERS | scsi0=16G | no |  |
| 9000 | tpl-ubuntu-2404 | stopped | 2 | 1024 | 0 | - | scsi0=16G | no |  |

## Servidores Linux (facts de Ansible)

| Host | IP | Sistema | Kernel | vCPU | RAM | Disco / | Encendido |
|---|---|---|---|---|---|---|---|
| adm-ans01 | 10.10.10.10 | Ubuntu 24.04 | 6.8.0-151-generic | 2 | 1.1 GB | 14 GB (35 % usado) | 0 d 3 h |
| mon01 | 10.10.10.20 | Ubuntu 24.04 | 6.8.0-151-generic | 2 | 1.9 GB | 23 GB (17 % usado) | 0 d 3 h |
| srv-app01 | 10.10.20.30 | Ubuntu 24.04 | 6.8.0-147-generic | 2 | 2.4 GB | 14 GB (25 % usado) | 0 d 1 h |
| srv-siem01 | 10.10.40.10 | Ubuntu 24.04 | 6.8.0-151-generic | 4 | 5.8 GB | 57 GB (35 % usado) | 0 d 0 h |
| srv-web01 | 10.10.50.10 | Ubuntu 24.04 | 6.8.0-151-generic | 2 | 1.2 GB | 14 GB (16 % usado) | 0 d 2 h |

Los servidores apagados en el momento de generar el inventario no aparecen en esta segunda tabla.
