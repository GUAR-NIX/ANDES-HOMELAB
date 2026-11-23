# RB-03 · Parcheo mensual

**Disparador:** segundo martes de cada mes (Windows publica los parches) o una vulnerabilidad crítica explotada.
**Ventana:** se registra como cambio (CHG). Referencia medida en la Fase 7.4: 1 h 06 min para los 4 Linux y DC01.
**Riesgo:** medio (reinicios). Orden: servidores menos críticos primero; DC01 y el firewall por separado.

## Antes
1. Abrir el cambio en `docs/cambios` (qué, ventana, riesgo, reversión).
2. Comprobar que la copia de anoche está verificada: PBS → ds-main → Content (columna Verify State en OK).
3. Informe de vulnerabilidades de partida, en SRV-SIEM01 (el indexer solo escucha en local; pide la contraseña del
   usuario admin de Wazuh): `scp scripts/fase7/vuln-report.sh 10.10.40.10: && ssh -t 10.10.40.10 bash vuln-report.sh antes`.
4. Snapshot de las VM que se reinician (Proxmox → VM → Snapshots), y borrarlo al validar (llenan el thin pool).

## Linux (desde ADM-ANS01)
Los scripts se ejecutan dentro de cada servidor; desde ADM-ANS01 se les pasan por SSH, uno a uno:
```bash
cd ~/andes-config
for h in 10.10.50.10 10.10.20.30 10.10.10.20; do ssh $h 'sudo bash -s' < scripts/fase7/parche-linux.sh; done
ssh 10.10.40.10 'apt-mark showhold'        # SRV-SIEM01: wazuh-* retenidos a propósito (se actualizan aparte, los cuatro a la vez)
ssh 10.10.40.10 'sudo bash -s' < scripts/fase7/parche-linux.sh
sudo bash scripts/fase7/parche-linux.sh    # ADM-ANS01, el último
# Reiniciar los que lo pidan (/run/reboot-required) y, con el kernel nuevo validado:
ssh <host> 'sudo bash -s' < scripts/fase7/quitar-kernel-viejo.sh
```
El script deja el registro en `/var/log/parche-7.4.log` de cada servidor.
Cada kernel antiguo instalado suma unas 1.000 CVE al inventario: purgarlos cuando el nuevo esté probado.

## DC01 (Shell de PVE01)
```bash
qm snapshot 201 pre-parcheo-$(date +%Y%m)
qm guest exec 201 --timeout 5 -- powershell -EncodedCommand <wu-7.4.ps1 codificado>   # instala y deja log en C:\Windows\Temp
```
Reiniciar en la ventana y comprobar `dcdiag /q` y que los Linux siguen resolviendo nombres y autenticando.

## OPNsense
Sistema → Firmware → Actualizaciones, en una ventana propia: se corta la VPN. Antes, comprobar que la copia cifrada del
XML está al día (`scripts/fase9/opnsense-backup.sh`).

## Verificación
- `scripts/verificar-servicios.sh` en verde (web 200, contenedores sanos, Prometheus ve los node_exporter, agentes activos).
- Grafana sin alertas activas y Wazuh sin errores nuevos de los agentes.
- Informe posterior: `ssh -t 10.10.40.10 bash vuln-report.sh despues` y comparar críticas y altas con el de antes.

## Reversión
- Linux: arrancar con el kernel anterior desde el menú de GRUB (consola de la VM) o volver al snapshot.
- DC01: volver al snapshot solo si el dominio no funciona (un DC restaurado a un snapshot puede causar problemas de
  replicación en entornos con varios DC; aquí solo hay uno).
- Último recurso: restaurar la VM desde PBS (RB-05).
