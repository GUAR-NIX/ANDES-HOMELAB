# Revisión de accesos 2026-T4

Generada el 2026-11-22 18:53 con `scripts/revision-accesos.py` contra la línea base aprobada. Revisor: ______  Fecha de aprobación: ______

## Hallazgos

Sin desviaciones respecto a la línea base.

## 1. Grupos privilegiados de AD

| Grupo | Miembros | Estado |
|---|---|---|
| admins. del dominio | adm-erick, administrador | OK |
| administradores de empresas | administrador | OK |
| administradores de esquema | administrador | OK |
| gg-linux-admins | erick | OK |
| gg-helpdesk | hd.rojas | OK |

## 2. Proxmox: usuarios, 2FA y permisos

| Usuario | Habilitado | 2FA | Caduca | Estado |
|---|---|---|---|---|
| guarnix@pve | sí | sí | nunca | OK |
| root@pam | sí | sí | nunca | OK |
| terraform@pve | sí | no | nunca | OK |

| Ruta | Usuario/grupo/token | Rol | Hereda |
|---|---|---|---|
| / | pve-admins (group) | Administrator | sí |
| / | terraform@pve (user) | TerraformProv | sí |

## 3. Claves SSH autorizadas

| Servidor | Usuario | Clave (comentario) | Huella | Restricciones | Estado |
|---|---|---|---|---|---|
| adm-ans01 | labadmin | erick@laptop | `SHA256:eDKHQ4B0Zl7yo…` | - | OK |
| mon01 | labadmin | erick@adm-ans01 | `SHA256:R0BKuUPOh/J4U…` | - | OK |
| srv-app01 | labadmin | erick@adm-ans01 | `SHA256:R0BKuUPOh/J4U…` | - | OK |
| srv-siem01 | labadmin | erick@adm-ans01 | `SHA256:R0BKuUPOh/J4U…` | - | OK |
| srv-web01 | labadmin | erick@adm-ans01 | `SHA256:R0BKuUPOh/J4U…` | - | OK |
| srv-pbs01 | - | (apagado: se revisa en la ventana de copias o encendiéndolo) | | | PENDIENTE |

## 4. Comprobación manual

- [ ] OPNsense (Sistema → Acceso → Usuarios): solo `root` y `backup-api`; `backup-api` sin shell y solo con privilegios de copia (Configuration History y Backups).
- [ ] OPNsense (VPN → WireGuard → Peers): solo los equipos de administración aprobados.
- [ ] Wazuh y Grafana: solo la cuenta `admin`; contraseñas en el gestor, no compartidas.
- [ ] PBS (Configuración → Control de acceso): `pve-backup@pbs` y su token `pve01`, solo DatastoreBackup en ds-main.
- [ ] Cuentas de servicio de AD (OU=Servicio): `svc-adjoin` sin grupos y con delegación solo en OU=Linux.
- [ ] Bajas del trimestre (RB-01): ninguna cuenta habilitada de personas que ya no trabajan.

