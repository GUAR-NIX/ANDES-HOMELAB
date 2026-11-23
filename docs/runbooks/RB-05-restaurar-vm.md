# RB-05 · Restaurar una VM, un archivo o un servidor

**Disparador:** pérdida o corrupción de un servidor, un archivo borrado, un usuario de AD borrado o un servidor que se
quiere rehacer limpio. Tiempos medidos en los simulacros (docs/dr/resultados-simulacros.md).

**Antes de nada:** PBS solo está encendido en la ventana de las 22:00. Encenderlo (Proxmox → 160 → Start) y, si el SIEM está
encendido y falta memoria, apagar el SIEM mientras dure la restauración. Comprobar que la copia que se va a usar tiene
**Verify State OK**.

## Elegir el método

| Situación | Método | Tiempo medido |
|---|---|---|
| Un archivo borrado o dañado | A. File Restore | ~2 min |
| Una VM rota | B. Restaurar la VM desde PBS | 5 min 19 s (web) |
| Servidor comprometido, o rehacerlo limpio | C. Reconstruir por código | 6-7 min + datos |
| Usuario u objeto de AD borrado | D. Papelera de AD | 0,05 s |
| Firewall | [RB-DR-04](../dr/RB-DR-04-firewall.md) | 3 min 38 s |

## A. Archivo individual
Proxmox → `pbs01` → Backups → copia de la VM → **File Restore** → `drive-scsi0.img.fidx` → `part` → `1` (la partición
grande) → ruta del archivo → **Download**. Copiarlo al servidor con `scp` e `install` con su dueño y permisos. Comparar el
SHA-256 si se conoce.

## B. VM completa
1. Proxmox → `pbs01` → **Backups** (no la pestaña Backup de la VM: esa restaura **encima** de la VM).
2. Restore con un **ID nuevo**, **Unique** marcado y **sin** *Start after restore*.
3. Si la VM original sigue existiendo: antes de arrancar la copia, `link_down=1` en todas sus tarjetas (misma IP) y
   `onboot=0`.
4. Arrancar y comprobar por la consola o el agente QEMU.
5. Intercambio: apagar la original, quitar `link_down` de la copia, comprobar el servicio, restaurar `onboot`.

## C. Reconstruir por código
```bash
cd ~/andes-config && scripts/reconstruir-servidor.sh <nombre> <ip>     # ej.: srv-web01 10.10.50.10
```
Destruye y crea la VM con Terraform y la configura con Ansible (dos pasadas, la segunda con changed=0). Después, los
datos: en SRV-APP01, recuperar el último `pg_dump` de PBS con File Restore (`/opt/andes-app/backups`) y
`docker exec -i andes-app-db-1 pg_restore -U andes_app -d andes --clean --if-exists --no-owner < dump`.
Si el SIEM estaba apagado durante la reconstrucción, al volver lanzar una pasada de Ansible al servidor para que su
agente de Wazuh se registre.

## D. Objeto de AD
```powershell
Get-ADObject -Filter "samAccountName -eq '<usuario>'" -IncludeDeletedObjects | Restore-ADObject
```
Conserva el SID y los grupos. Para un daño mayor del dominio: copia del System State (S:) o restauración de DC01 desde PBS.

## Verificación
`scripts/verificar-servicios.sh` en verde, el servicio responde y no hay dos VM con la misma IP. Anotar en el cambio o
incidente el tiempo real (RTO) y los datos perdidos (RPO).

## Reversión
Mientras no se borre, la VM original (o la restaurada) sigue disponible para volver atrás. Borrar la que sobre solo al
final, con `qm destroy <id> --purge`.
