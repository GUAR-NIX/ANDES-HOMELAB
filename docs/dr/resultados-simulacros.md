# Fase 9 - Resultados de los simulacros de recuperacion (DR)

Regla: antes de cualquier simulacro destructivo, la copia mas reciente debe tener verificacion OK en PBS.
Verificacion completa de ds-main del 22/11/2026 07:25: 7/7 grupos, 0 errores.

| ID | Simulacro | Procedimiento | Medido | Objetivo | Resultado |
|----|-----------|---------------|--------|----------|-----------|
| DR-05 | Usuario borrado en AD | Usuario y grupo de prueba; Remove-ADUser; Restore-ADObject desde la Papelera (scripts/fase9/dr05-ad-recycle.ps1) | Restauracion 0,05 s; mismo SID, mismos grupos, habilitado | RTO 2 h (DC01) | Superado |
| DR-02 | Archivo individual | Borrado /var/www/html/index.nginx-debian.html en SRV-WEB01; File Restore desde PBS (copia cifrada) | 11 min 03 s de extremo a extremo (primera vez, guiado); ~2 min la operacion; SHA-256 identico (fb47468a...d6de) | - | Superado |
| DR-01 | Restaurar VM | Copia de SRV-WEB01 restaurada como VM 151 (Unique, NIC link_down=1); arranque aislado; intercambio con la VM 150 | Restauracion 76 s; arranque 134 s; RTO total 5 min 19 s; corte en el intercambio 7 s | RTO 30 min | Superado |
| DR-06 | Copia corrupta | Bloque alterado a proposito en ds-usb (copia 2); verify; sync con resync-corrupt desde ds-main; verify | Detectado ("chunks could not be verified", bloque apartado como .bad); reparado; verify 0 errores | - | Superado |
| DR-03 | Reconstruccion por codigo | Destruir SRV-APP01 con scripts/reconstruir-servidor.sh (Terraform + Ansible); dump de las 01:30 recuperado de PBS con File Restore; pg_restore | Reconstruccion 6 min 53 s; RTO total 7 min 11 s (descarga del dump en paralelo); RPO real 12 h: 5 de 10 filas (las posteriores al dump) perdidas | RTO 1 h, RPO 24 h | Superado; la union a AD NO esta en el codigo (se pierde) |
| DR-04 | Firewall | Version segura: copia de FW-OPN01 restaurada como VM 102 con WAN y troncal desconectadas (link_down) + validacion del XML cifrado de git (via B documentada en RB-DR-04) | Restauracion 106 s; firewall arrancado con 6 VLAN, WAN, TRUNK y WG_VPN en 3 min 38 s; XML descifrado identico a la configuracion actual | RTO 30 min | Superado (sin intercambio real: cortaria la VPN); carencia: contrasena de Vault solo en ADM-ANS01 |

## DR-01 frente a DR-03
| | DR-01 restaurar VM desde PBS | DR-03 reconstruir por codigo |
|---|---|---|
| RTO | 5 min 19 s | 7 min 11 s |
| Estado final | Identico a la copia (incluida la union a AD y la clave del agente Wazuh) | Limpio, con la configuracion actual de git |
| Se pierde | Lo cambiado despues de la copia | Lo que no esta en el codigo (union a AD) y lo que no esta en el dump |
| Cuando usarlo | Servidor con estado dificil de reproducir, o el mas rapido | Servidor comprometido (no se quiere restaurar algo posiblemente alterado) o cambio de version |

## Lecciones
- Restore desde la pestana Backup de una VM restaura ENCIMA de esa VM: para un ID nuevo hay que restaurar desde el almacenamiento (pbs01 -> Backups).
- La copia restaurada conserva onboot=1: desactivarlo, o en el siguiente reinicio de PVE01 arrancarian dos VM con la misma IP.
- Con la NIC desconectada, Linux no asigna la IP (eth0 sin direccion): es lo esperado, se comprueba el arranque por el agente QEMU.
- ds-usb se monta, sincroniza y desmonta solo (run-on-mount / unmount-on-done): para manipularlo hay que desactivar esas opciones.
- El sync de la "USB" solo copia snapshots cifrados y verificados; una copia corrupta se repara con resync-corrupt desde la otra.
- DR-03: la union al dominio de SRV-APP01 (Fase 3, realm join) no estaba en Ansible: tras reconstruir, el servidor quedo fuera de AD.
  CORREGIDO el 22/11: rol ad_member (realmd + SSSD, solo gg-linux-admins, sudo) con la cuenta svc-adjoin en OU=Servicio,
  delegada SOLO sobre objetos de equipo de OU=Linux,OU=Servidores,OU=CORP (sin grupos de dominio); contrasena en Vault.
  T14 repetida: erick entra y tiene sudo, Administrator denegado; segunda ejecucion changed=0.
- El pg_dump solo vive dentro de la VM (y en sus copias): para restaurar hay que sacarlo de PBS. Solo hay dumps de los dias en que
  la VM estaba encendida a las 01:30 UTC (cron); un timer de systemd con Persistent=true no se saltaria dias.
- Con el SIEM apagado, la reconstruccion sigue (ignore_unreachable); el agente se registra cuando el SIEM vuelve.
