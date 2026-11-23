# ADR-0008 · Copia de OPNsense cifrada en git en lugar de os-git-backup

| Estado | Fecha | Fase |
|---|---|---|
| Aceptada | 2026-11-22 | 9 |

## Contexto
El plan propone el plugin `os-git-backup` para versionar cada cambio del firewall en un repositorio. Pero `config.xml`
contiene secretos: la clave privada de Andes-Root-CA (ADR-0006), las claves de WireGuard y hashes de contraseñas.

## Decisión
ADM-ANS01 descarga `config.xml` cada día (03:15) por la API de OPNsense con un usuario dedicado (`backup-api`, solo
privilegios de copia), comprueba el certificado fijando su clave pública y, **solo si cambió**, lo cifra con Ansible Vault
y lo guarda en `backups/opnsense/config.xml.vault`. Cada cambio del firewall queda como un commit cifrado.

## Alternativas consideradas
- **os-git-backup**: sencillo, pero el XML viaja y se guarda en claro.
- **Copia manual desde la web**: depende de acordarse y no deja historial.
- **Solo la copia de la VM en PBS**: recupera la máquina, pero no permite ver ni recuperar un cambio concreto.

## Consecuencias
- Recuperación por dos vías (RB-DR-04): restaurar la VM desde PBS o una VM nueva con el XML descifrado.
- La contraseña de Vault es necesaria para descifrar: debe estar fuera del laboratorio, porque si cae el firewall no se
  llega a ADM-ANS01 (carencia detectada en DR-04).
- La API de copias exige el privilegio "Configuration History", que también permite revertir versiones: se acepta y la
  clave solo existe en ADM-ANS01 con permisos 600.
