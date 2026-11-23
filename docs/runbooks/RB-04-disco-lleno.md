# RB-04 · Disco lleno

**Disparador:** alerta de Prometheus (sistema de archivos por encima del 85 %), revisión semanal o un servicio que falla
por falta de espacio. **Objetivo:** liberar espacio sin borrar datos de negocio y averiguar por qué creció.

## 1. ¿Dónde?
```bash
for h in 10.10.10.20 10.10.20.30 10.10.40.10 10.10.50.10; do ssh $h 'echo "== $(hostname)"; df -h -x tmpfs -x overlay | awk "NR==1 || \$5+0>=70"'; done
```
En PVE01 (Shell): `pvesm status` y `lvs pve/data` (uso del thin pool **local-lvm**, el más delicado: si llega al 100 % las
VM se congelan).

## 2. Encontrar lo que ocupa
```bash
sudo du -xh --max-depth=2 / 2>/dev/null | sort -h | tail -15
```

## 3. Causas habituales y solución

| Causa | Comprobación | Solución |
|---|---|---|
| Logs del sistema | `journalctl --disk-usage` | `sudo journalctl --vacuum-size=200M` (journald ya está limitado en la línea base) |
| Imágenes y capas de Docker (MON01, APP01) | `sudo docker system df` | `sudo docker image prune -a` (no borra volúmenes) |
| Caché de apt | `du -sh /var/cache/apt` | `sudo apt-get clean` |
| Kernels antiguos | `dpkg -l 'linux-image-*' \| grep ^ii` | `ssh <host> 'sudo bash -s' < scripts/fase7/quitar-kernel-viejo.sh` |
| Índices de Wazuh (SIEM) | `du -sh /var/lib/wazuh-indexer` | Revisar la política de retención del índice (ISM) antes de borrar nada |
| Copias de pg_dump (APP01) | `ls -lh /opt/andes-app/backups` | El script ya borra las de más de 14 días: revisar que el cron funciona |
| Snapshots en local-lvm (PVE01) | `qm listsnapshot <id>` | Borrar los snapshots ya validados |
| Datastore de PBS lleno | PBS → ds-main → Summary | La retención y el GC los lanza la ventana de copias (domingo); ver su log en PVE01 |

## 4. Si es un disco que se queda pequeño de verdad
Ampliar el disco en Terraform (servidores gestionados) o en Proxmox (`qm resize <id> scsi0 +10G`) y dentro de la VM
`sudo growpart /dev/sda 1 && sudo resize2fs /dev/sda1`. Registrar el cambio.

## Verificación
`df -h` por debajo del 70 % y la alerta resuelta en Grafana. Anotar en el cambio o en la revisión semanal la causa y,
si se repite, abrir un problema (crecimiento no previsto).

## Reversión
Lo borrado con estos pasos es regenerable (logs rotados, caché, imágenes que se vuelven a descargar). Si se borró algo
por error: RB-05 (restauración de un archivo desde PBS).
