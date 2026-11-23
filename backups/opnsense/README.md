# Copia de la configuración de OPNsense

En el entorno real, `scripts/fase9/opnsense-backup.sh` exporta cada día a las 03:15 el `config.xml` del firewall,
lo cifra con Ansible Vault y lo guarda aquí como `config.xml.vault` (un commit por cada cambio). Ver
[ADR-0008](../../docs/adr/ADR-0008-opnsense-xml-cifrado.md) y [RB-DR-04](../../docs/dr/RB-DR-04-firewall.md).

**Esta es la versión pública del repositorio:** el archivo cifrado no se incluye, porque contiene la configuración
completa del firewall y la clave de la CA interna. Aunque va cifrado, publicarlo permitiría intentar descifrarlo
sin límite de intentos.
