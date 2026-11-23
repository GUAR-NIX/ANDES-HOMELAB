# Capacidad de PVE01

Panel de Grafana: **Andes → Capacidad PVE01** (`monitoring/grafana/capacidad-pve01.json`). Métricas: node_exporter de
PVE01 (solo en 192.168.188.10:9100, lo recoge MON01 por el flujo F06) y `andes-pve-metricas.sh` (cada 5 min: thin pool,
sobreasignación y RAM asignada a las VM). Alertas: **CapacidadThinPool** (> 85 %) y **CapacidadRamPVE01** (< 10 % libre).
Se revisa una vez al mes y se anota aquí.

## Medición de referencia · 2026-11-22 (todas las VM encendidas salvo PBS, test-users y la plantilla)

| Recurso | Capacidad | Uso | Margen | Lectura |
|---|---|---|---|---|
| RAM de PVE01 | 19,5 GB | 18,0 GB asignados a las VM encendidas (92 %); 22,5 % disponible | ~4,4 GB | **Recurso limitante** |
| CPU de PVE01 | 8 vCPU | 40 % de media en 5 min; iowait 0 % | Amplio | Sin problema |
| local-lvm (thin pool) | 186 GB | 59 % escrito; sobreasignación ×3 (596 GB prometidos) | ~76 GB | Vigilar: si llega al 100 % las VM se congelan |
| local (raíz de PVE01, ISO y snippets) | 83 GB | 28 % | ~60 GB | Sin problema |

## Conclusión

1. **La memoria es el límite.** La RAM configurada de las VM encendidas ya ocupa el 92 % de PVE01; el margen real
   (~4,4 GB) existe porque ADM-ANS01 y SRV-WEB01 tienen ballooning y no todas las VM usan toda su RAM. PBS y el SIEM no
   caben a la vez, y por eso existe la ventana diaria de copias (ADR-0007).
2. **La CPU no limita** y **el disco tiene margen**, pero con una sobreasignación ×3: el riesgo no es el uso de hoy, sino que
   varias VM crezcan a la vez (índices de Wazuh, imágenes de Docker, snapshots olvidados).
3. **Una VM nueva** solo cabe si cumple al menos una de estas condiciones: necesita ≤ 2 GB y se acepta quedar con < 10 % de
   RAM libre; se enciende solo cuando hace falta (perfil de encendido, como PBS o la VM de pruebas); o se libera memoria
   de otra.

## Qué se haría al crecer (por orden de coste)

| Opción | Gana | Coste / riesgo |
|---|---|---|
| Perfiles de encendido (ya en uso: PBS y test-users fuera de horario) | 2-3 GB | Gestión; ya automatizado para PBS |
| Ballooning en VM sin estado crítico (MON01) | ~0,5 GB | Lección de la Fase 7: nunca en el SIEM ni en bases de datos |
| Subir PVE01 de 20 a 22 GB | 2 GB | Windows queda con ~9 GB: límite razonable para el anfitrión |
| Ampliar el disco virtual de PVE01 y el thin pool | Disco | Sencillo (VMware + `lvextend`); no resuelve la RAM |
| Segundo anfitrión o equipo dedicado | Todo, y alta disponibilidad | Hardware: es el paso natural si el laboratorio crece |

## Registro de revisiones
| Fecha | RAM asignada / total | Thin pool | Acción |
|---|---|---|---|
| 2026-11-22 | 18,0 / 19,5 GB | 59 % (×3) | Línea base; alertas y panel creados |
