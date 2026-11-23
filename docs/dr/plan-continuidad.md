# Plan de continuidad - Andes (laboratorio corp.lab.internal)

Version 1.0 - 22/11/2026 - Fase 9. Resultados medidos en docs/dr/resultados-simulacros.md.

## 1. Objetivos por servicio
| Servicio | VM | Criticidad | RPO objetivo | RTO objetivo | Metodo principal | Medido |
|---|---|---|---|---|---|---|
| Firewall / red / VPN | FW-OPN01 (100) | Critica | Cada cambio | 30 min | PBS (via A) o VM nueva + XML cifrado de git (via B, RB-DR-04) | 3 min 38 s (DR-04, aislado) |
| Directorio activo | DC01 (201) | Critica | 24 h | 2 h | PBS + System State (S:) + Papelera de AD | Objeto: 0,05 s (DR-05) |
| App + BD | SRV-APP01 (130) | Alta | 24 h (pg_dump 01:30 UTC) | 1 h | Reconstruccion por codigo + pg_restore, o PBS | 7 min 11 s, RPO real 12 h (DR-03) |
| Web publica (proxy) | SRV-WEB01 (150) | Alta | 24 h | 30 min | PBS o reconstruccion por codigo | 5 min 19 s (DR-01); 7 min 19 s por codigo (T30) |
| Monitorizacion | MON01 (120) | Media | 7 dias | 4 h | PBS | - |
| SIEM | SRV-SIEM01 (140) | Media | 7 dias | 4 h | PBS | - |
| Administracion | ADM-ANS01 (110) | Alta | 24 h | 1 h | PBS (contiene repo git, Vault, claves y estado de Terraform) | - |
| Copias | SRV-PBS01 (160) | Alta | - | 2 h | Reinstalar PBS (Terraform pbs.tf + pbs-config.sh) y reconectar ds-usb (copia 2) | - |

## 2. Donde estan las copias (regla 3-2-1)
| Copia | Soporte | Frecuencia | Contenido |
|---|---|---|---|
| 1 | ds-main en SRV-PBS01 (disco de PVE01) | Diaria 22:00 en la ventana de copias; verificacion al terminar cada copia; retencion diaria; GC y re-verificacion los domingos | 7 VM cifradas en el cliente (clave en el gestor de contrasenas y USB) |
| 2 | ds-usb, disco extraible en C:\Lab\USB-PBS del anfitrion | Semanal (sabados, en la ventana), solo copias cifradas y verificadas | Espejo de ds-main |
| 3 | Fuera del sitio | No implementada | RIESGO ACEPTADO: PBS 4.2 admite datastores S3; requiere cuenta de pago |
| App | /opt/andes-app/backups en SRV-APP01 | Diaria 01:30 UTC (pg_dump), 14 dias | Viaja dentro de las copias de la VM |
| AD | S: (SYSSTATE) en DC01 | Diaria 01:00 | System State (wbadmin); viaja en las copias de la VM |
| Firewall | GitHub GUAR-NIX/andes-config, backups/opnsense/config.xml.vault | Diaria 03:15, solo si cambia | config.xml cifrado con Ansible Vault |
| Codigo | GitHub GUAR-NIX/andes-config (privado) | Cada cambio | Terraform, Ansible, scripts, documentacion |

## 2b. Ventana diaria de copias (22:00)
PBS (2 GB) y SRV-SIEM01 (6 GB) no caben a la vez con todo encendido. El temporizador andes-ventana-backup.timer de PVE01
(Persistent: si el PC estaba apagado, se ejecuta al arrancar, tras 10 min) lanza /usr/local/sbin/andes-ventana-backup.sh:
apaga el SIEM, enciende PBS, copia todas las VM (salvo 160, 301 y 9000), pide a PBS su mantenimiento por SSH con una
clave restringida (restrict, command forzado a andes-mantenimiento-pbs.sh, from=192.168.188.10) y, pase lo que pase,
apaga PBS y vuelve a encender el SIEM. Duracion medida: unos 6 min (copia 2 min 56 s). Log: /var/log/andes-ventana-backup.log.
Fuera de la ventana: SIEM encendido (onboot=1) y PBS apagado (onboot=0, en Terraform).

## 3. Dependencias
- Todo depende de FW-OPN01 (rutas entre VLAN, DNS Unbound, NTP, VPN WireGuard) y de PVE01.
- Autenticacion y DNS interno dependen de DC01; SRV-APP01 esta unido a AD (rol ad_member).
- SRV-WEB01 (proxy) depende de SRV-APP01; MON01 y SRV-SIEM01 vigilan a todos.
- Recuperar por codigo necesita ADM-ANS01 (Terraform, Ansible, Vault). Recuperar desde PBS necesita PVE01 + SRV-PBS01 +
  la clave de cifrado de PBS.
- Secretos imprescindibles FUERA del laboratorio: clave de cifrado de PBS, contrasena de Vault, credenciales de Proxmox
  y OPNsense (gestor de contrasenas del administrador).

## 4. Orden de recuperacion (perdida total)
1. PVE01 (VMware) y SRV-PBS01 (o reinstalar PBS y montar ds-usb para leer la copia 2).
2. FW-OPN01 (RB-DR-04) -> vuelven la red, el DNS y la VPN.
3. DC01 (PBS; System State si hace falta una restauracion autoritativa).
4. ADM-ANS01 (PBS) -> vuelven Terraform, Ansible y Vault.
5. SRV-APP01 (PBS, o reconstruir por codigo + pg_restore).
6. SRV-WEB01 (PBS, o scripts/reconstruir-servidor.sh srv-web01 10.10.50.10).
7. MON01 y SRV-SIEM01 (PBS). Tras recuperar SIEM: comprobar que los agentes reconstruidos se registran.

## 5. Riesgos aceptados y limitaciones
- Un unico anfitrion fisico: las copias 1 y 2 estan en el mismo disco del portatil (la 2 en otra carpeta, fuera de Proxmox).
- Sin copia fuera del sitio (copia 3).
- Por RAM (31 GB en el anfitrion), PBS y SRV-SIEM01 no caben a la vez: el SIEM no vigila durante la ventana diaria (~6 min).
- Tras un apagon el reloj del laboratorio se atrasa: corregir PVE01 (date + hwclock), reiniciar OPNsense y forzar chrony.
- La proteccion de la rama main en GitHub no se aplica en un repositorio privado gratuito.
