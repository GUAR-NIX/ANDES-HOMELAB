# RB-DR-04 - Recuperacion del firewall (FW-OPN01)

Objetivo: RTO 30 min, RPO "cada cambio". Si cae OPNsense cae TODO: rutas entre VLAN, DNS, VPN y el acceso a ADM-ANS01.
Por eso el procedimiento se hace desde PVE01 (red NAT de VMware) y la consola de Proxmox, nunca desde el laboratorio.

## Via A (preferente): restaurar la VM desde PBS  -> probada en el simulacro DR-04
1. Proxmox -> pbs01 -> Backups -> vm/100/<ultima> (comprobar Verify OK) -> Restore.
   VM 100 (si la original no existe) o un ID nuevo con Unique; Start after restore: NO.
2. Si convive con la original: net0 y net1 con link_down=1 antes de arrancar; comprobar por consola.
3. Intercambio: apagar la original, quitar link_down de la nueva, comprobar trafico entre VLAN y la VPN.
4. onboot=1, order=1 (debe arrancar la primera).
Medido el 22/11/2026: restauracion 106 s; firewall arrancado con las 6 VLAN, WAN, TRUNK y WG_VPN en 3 min 38 s.

## Via B: VM nueva + importar el XML (si la copia de la VM no sirve)
El XML vive cifrado (Ansible Vault) en GUAR-NIX/andes-config: backups/opnsense/config.xml.vault, una version por cambio.
1. Crear la VM en PVE01 (como la 100): 2 vCPU, 2 GB, disco 16 GB, net0 vmbr0 (WAN), net1 vmbr1 (troncal),
   ISO local:iso/OPNsense-26.7-dvd-amd64.iso. Instalar OPNsense (UFS).
2. Obtener el XML SIN depender del laboratorio:
   - Descargar config.xml.vault desde GitHub en el navegador del anfitrion (cuenta del administrador).
   - Contrasena de Vault: copia en el gestor de contrasenas del administrador (NO solo en ADM-ANS01, que queda
     inaccesible sin firewall).  <- CARENCIA DETECTADA EN EL SIMULACRO; accion: guardar esa copia.
   - Descifrar en PVE01: apt install ansible-core && ansible-vault decrypt --output config.xml config.xml.vault
3. Importar: en PVE01 crear un disco pequeno FAT con /conf/config.xml, anadirlo a la VM nueva y, al arrancar el
   instalador/live de OPNsense, pulsar una tecla para el importador y elegir ese disco (opnsense-importer).
4. Reiniciar, comprobar interfaces/VLAN en la consola, borrar el disco temporal y el config.xml descifrado (shred).
5. Al recuperar el acceso: comprobar que el certificado de la GUI y las claves WireGuard son las del XML
   (los clientes VPN no necesitan cambios).

## Por que no se ejecuto la via B completa en el laboratorio
Un unico anfitrion: apagar FW-OPN01 corta la VPN y el acceso de administracion a todo el laboratorio; el simulacro
se hizo en version segura (via A aislada + validacion del XML: descifrado, bien formado e identico a la configuracion
actual, 124.095 bytes, 11 interfaces, 6 VLAN, 21 reglas, 19 alias, 5 certificados, 2 CA, WireGuard).
