# Guía del proyecto Andes: de un portátil vacío a una empresa operada como código

**Autor: Erick Guarnizo** · [Volver al README](../README.md) · [Glosario](GLOSARIO.md) · [Bitácora con capturas (PDF)](../BITACORA-PASO-A-PASO.pdf)

Esta guía cuenta el proyecto completo en el orden en que se construyó. Para cada fase explica **qué problema de una
empresa resuelve**, **qué se hizo**, **qué decisiones se tomaron y por qué**, **qué salió mal y cómo se arregló**, y
**cómo se comprobó** que funciona. Los términos técnicos están explicados en el [glosario](GLOSARIO.md).

---

## Índice

- [El punto de partida](#el-punto-de-partida)
- [Fase 0 · Preparar el anfitrión](#fase-0--preparar-el-anfitrión)
- [Fase 1 · El hipervisor](#fase-1--el-hipervisor-proxmox-ve)
- [Fase 2 · La red de la empresa](#fase-2--la-red-de-la-empresa)
- [Fase 3 · Identidad: Active Directory](#fase-3--identidad-active-directory)
- [Fase 4 · Servidores endurecidos y certificados propios](#fase-4--servidores-endurecidos-y-certificados-propios)
- [Fase 5 · La aplicación de la empresa](#fase-5--la-aplicación-de-la-empresa)
- [Fase 6 · Observabilidad: saber qué pasa](#fase-6--observabilidad-saber-qué-pasa)
- [Fase 7 · Seguridad defensiva](#fase-7--seguridad-defensiva)
- [Fase 8 · Todo como código](#fase-8--todo-como-código)
- [Fase 9 · Copias de seguridad y recuperación](#fase-9--copias-de-seguridad-y-recuperación-ante-desastres)
- [Fase 10 · Operar como una empresa](#fase-10--operar-como-una-empresa)
- [Fase 11 · Publicación](#fase-11--publicación)
- [Lo que se aprendió](#lo-que-se-aprendió)

---

## El punto de partida

**Objetivo:** demostrar, con evidencias medibles, las competencias de un perfil de infraestructura y ciberseguridad:
construir, automatizar, proteger, vigilar, recuperar y documentar la plataforma de una empresa.

**Restricción:** un único portátil (Windows 11, CPU de 16 núcleos, 32 GB de RAM). Todo debe caber en unos 20 GB de RAM
para el laboratorio. Esta restricción condicionó muchas decisiones y es parte de lo interesante: en una empresa real los
recursos también son finitos.

**Método:** desde el primer día, todo cambio queda registrado. Primero en una bitácora con capturas y, a partir de la
fase 8, en git, con revisión automática (CI) antes de aplicar nada.

---

## Fase 0 · Preparar el anfitrión

**Problema que resuelve:** para ejecutar un hipervisor (Proxmox) dentro de otro (VMware), la CPU tiene que exponer la
virtualización «anidada», y Windows 11 la bloquea por defecto.

**Qué se hizo**
- Comprobación del hardware: soporte AMD-V, RAM y espacio en disco.
- Desactivación de la integridad de memoria (HVCI/VBS) de Windows, que acapara la virtualización por hardware y
  impedía a VMware ofrecerla a Proxmox.
- Descarga y verificación de las imágenes ISO (Proxmox VE, OPNsense, Windows Server, Ubuntu Server).
- Método de trabajo: bitácora con capturas de cada paso y repositorio de configuración desde el principio.

**Decisión clave:** Proxmox anidado en VMware en lugar de instalar Proxmox directamente sobre el portátil, para poder
seguir usando el equipo con normalidad. El coste es algo de rendimiento; se acepta y se documenta
([ADR-0001](adr/ADR-0001-proxmox-anidado.md)).

---

## Fase 1 · El hipervisor (Proxmox VE)

**Problema que resuelve:** una empresa necesita una plataforma donde crear, aislar y recuperar servidores rápidamente.

**Qué se hizo**
- Proxmox VE 9 como máquina virtual de VMware (PVE01).
- Post-instalación: repositorios, actualizaciones y almacenamiento *thin* (LVM-thin) para no reservar disco que no se usa.
- Identidad: administración con cuentas propias, sin usar root para el trabajo diario.
- **Plantilla Ubuntu 24.04 con cloud-init** (VM 9000): cada servidor nuevo nace de ella con su nombre, IP y clave SSH,
  sin instalar nada a mano.

**Resultado:** un servidor Linux nuevo, listo y configurado, en minutos. Más adelante, con Terraform, en **2 min 31 s**.

---

## Fase 2 · La red de la empresa

**Problema que resuelve:** si toda la empresa está en una sola red, un equipo infectado puede llegar a cualquier
servidor. Hay que separar y controlar.

**Qué se hizo**
- Firewall **OPNsense** con **6 VLAN**, cada una con un propósito: administración, servidores, usuarios, seguridad,
  DMZ y copias ([ADR-0002](adr/ADR-0002-seis-vlan.md)).
- **Denegación por defecto:** entre redes no pasa nada salvo **12 flujos** documentados en una matriz (quién habla con
  quién, por qué puerto y para qué).
- DNS y NTP internos en el firewall, para que todos los equipos resuelvan nombres y tengan la misma hora.
- **VPN WireGuard** como **única** vía de administración: el panel de Proxmox, los servidores y los paneles web solo
  son accesibles a través de ella.
- Registro de conexiones bloqueadas y copia de la configuración del firewall.

**Cómo se comprobó:** pruebas de conectividad de cada flujo permitido **y de los prohibidos**. Por ejemplo, desde el
servidor de la DMZ hacia el controlador de dominio por SMB (445): **bloqueado y registrado**. Se puede ver en el vídeo.

**Diagrama:** [docs/diagramas](diagramas/README.md).

---

## Fase 3 · Identidad: Active Directory

**Problema que resuelve:** cada empleado debe tener una sola cuenta, con los permisos de su puesto, que se pueda
desactivar al instante si se va de la empresa.

**Qué se hizo**
- Controlador de dominio **DC01** en **Windows Server Core** (sin interfaz gráfica: menos superficie de ataque y menos
  memoria, [ADR-0003](adr/ADR-0003-server-core.md)). Dominio `corp.lab.internal`.
- Estructura de la empresa: unidades organizativas por área, usuarios y grupos con el modelo **AGDLP** (los permisos se
  dan a grupos, nunca a personas).
- **Políticas de grupo (GPO)**: contraseñas, bloqueo de cuentas y configuración de los equipos.
- **Servidores Linux unidos al dominio** con realmd, SSSD y Kerberos: los administradores entran con su cuenta de
  Windows y solo el grupo `GG-Linux-Admins` puede iniciar sesión y usar sudo.

**Problema real:** al reconstruir un servidor desde código (fase 9) quedó **fuera del dominio**, porque la unión se
había hecho a mano. **Solución:** un rol de Ansible (`ad_member`) que une el servidor con una **cuenta de servicio
delegada** (`svc-adjoin`), que solo puede crear objetos de equipo en una OU concreta: mínimo privilegio.

---

## Fase 4 · Servidores endurecidos y certificados propios

**Problema que resuelve:** un servidor recién instalado no es seguro, y las conexiones internas sin cifrar se pueden
espiar.

**Qué se hizo**
- **Medir antes de cambiar**: auditorías iniciales con **Lynis** y con el estándar **CIS Ubuntu 24.04**.
- Línea base de seguridad: SSH solo con clave y solo desde la red de gestión y la VPN, servicios innecesarios
  desactivados, parámetros del kernel, auditoría y actualizaciones automáticas.
- **PKI interna**: una autoridad raíz (`Andes-Root-CA`) y una emisora (`Andes-Issuing-CA`). La raíz no firma
  certificados de servidor: si la emisora se viera comprometida, se revoca sin rehacer la confianza de toda la empresa
  ([ADR-0006](adr/ADR-0006-ca-intermedia.md)).
- **TLS en todos los servicios internos**: Proxmox, Grafana, Wazuh, la aplicación…

**Resultado medido:** Lynis **63 → 83** · CIS **53 % → 63 %**.

---

## Fase 5 · La aplicación de la empresa

**Problema que resuelve:** la empresa publica una aplicación para sus clientes, pero la base de datos nunca debe quedar
expuesta.

**Qué se hizo**
- **Andes App** (Python/Flask + PostgreSQL) en **Docker** en SRV-APP01: los contenedores se ejecutan **sin root** y con
  el sistema de archivos **de solo lectura**.
- **Proxy inverso nginx en la DMZ** (SRV-WEB01) con HTTPS: es lo único publicado. Solo él puede hablar con la aplicación
  (flujo F04, puerto 8080).
- **Seguridad de la cadena de contenedores**: la imagen se escanea con **Trivy** y el CI la rechaza si tiene
  vulnerabilidades críticas con parche disponible.
- Copias lógicas de la base de datos (`pg_dump`) programadas.

**Por qué así:** si atacan el proxy de la DMZ, el atacante no está en la red de servidores ni puede tocar la base de
datos directamente.

---

## Fase 6 · Observabilidad: saber qué pasa

**Problema que resuelve:** enterarse de una caída por la queja de un cliente es tarde.

**Qué se hizo**
- **Prometheus** recoge métricas de todos los servidores (CPU, memoria, disco y servicios) y comprueba la web desde
  fuera (*blackbox*).
- **Grafana**: paneles de estado y capacidad del hipervisor.
- **Alertmanager → Telegram**: alertas que importan (servidor caído, web no disponible, disco casi lleno, memoria del
  hipervisor), no ruido.
- **SLO de disponibilidad del 99 %**, con su presupuesto de error y un informe semanal.

**Problema real:** tras un reinicio brusco del hipervisor, el contenedor de Prometheus no volvió a arrancar y las
gráficas tienen un hueco de dos horas. Se detectó, se arrancó y quedó registrado: los huecos honestos también son datos.

---

## Fase 7 · Seguridad defensiva

**Problema que resuelve:** los ataques ocurren. Lo importante es **detectarlos rápido**, **contenerlos** y **aprender**.

**Qué se hizo**
- **SIEM Wazuh** (SRV-SIEM01) con agentes en los servidores Linux y Windows.
- **6 casos de uso de detección** mapeados a **MITRE ATT&CK** y 2 reglas propias. El más potente: la **integridad de
  archivos críticos (FIM) con who-data**, que en una sola alerta dice qué archivo cambió, quién lo cambió y con qué
  comando, con los hashes antes y después.
- **Gestión de vulnerabilidades**: inventario de vulnerabilidades, parcheo de los servidores y medición del antes y el
  después.
- **Incidente simulado de principio a fin** siguiendo **NIST SP 800-61**: preparación, detección, contención,
  erradicación, recuperación y lecciones aprendidas.

**El incidente (INC-0001), en breve:** se alteró sin autorización la configuración del servidor web de la DMZ.
- **Detección en 5 segundos**: Wazuh identificó el archivo, la sesión del administrador, la elevación con sudo y el
  comando exacto, con los hashes antes y después.
- **Contención**: instantánea forense y servidor aislado en una VLAN de cuarentena sin apagarlo (para no perder
  evidencia).
- **Recuperación**: redespliegue desde git, verificado byte a byte con el hash.
- **Métricas:** MTTD 5 s · contención en 11 min 37 s (objetivo ≤ 30 min) · MTTR 26 min.
- **Lección incómoda (y valiosa):** el SIEM detectó el cambio en 5 s, pero **nadie recibió un aviso**: la web seguía
  respondiendo «200 OK» y la monitorización de disponibilidad no lo podía ver. La disponibilidad no detecta cambios de
  integridad. De ahí salieron 6 acciones correctivas.

**Resultados medidos:** vulnerabilidades **−79 %** (19.784 → 4.062), críticas **−89 %**, en un ciclo de parcheo de
1 h 06 min. Informe completo: [INC-0001](incidents/INC-0001.md) · runbook: [RB-IR-01](runbooks/RB-IR-01.md).

---

## Fase 8 · Todo como código

**Problema que resuelve:** si la infraestructura solo existe «tal como quedó», nadie puede reproducirla, revisarla ni
recuperarla con garantías.

**Qué se hizo**
- **Terraform** (proveedor bpg/proxmox) declara las máquinas virtuales. Las VM que ya existían se **importaron** sin
  recrearlas, y el estado de Terraform se guarda **fuera de git** porque contiene datos sensibles
  ([ADR-0004](adr/ADR-0004-estado-terraform.md), [ADR-0005](adr/ADR-0005-terraform-bpg.md)).
- **Ansible** configura los servidores con **9 roles** reutilizables: `common`, `hardening`, `ad_member`, `docker`,
  `andes_app`, `nginx_proxy`, `node_exporter`, `wazuh_agent` y `patching`. Los secretos van cifrados con **Ansible Vault**.
- **Idempotencia**: ejecutar Ansible dos veces seguidas da `changed=0`; el código describe exactamente lo que hay.
- **CI en GitHub Actions** en cada cambio: **gitleaks** (secretos en todo el historial), `terraform validate`,
  **ansible-lint** en perfil *production*, **Trivy** y construcción y publicación de la imagen de la app. Las actions
  van fijadas por SHA (seguridad de la cadena de suministro).
- **Reconstrucción en un comando**: `scripts/reconstruir-servidor.sh` destruye un servidor y lo vuelve a crear y
  configurar desde git.

**Resultado medido:** servidor de la DMZ destruido y reconstruido desde código en **7 min 19 s**, sin pasos manuales.

---

## Fase 9 · Copias de seguridad y recuperación ante desastres

**Problema que resuelve:** una copia que nunca se ha restaurado no es una copia, es una esperanza.

**Qué se hizo**
- Objetivos por servicio: **RTO** (cuánto puede estar caído) y **RPO** (cuántos datos se pueden perder).
- **Proxmox Backup Server** (SRV-PBS01) en su propia VLAN: copias **cifradas** en el origen (PBS nunca ve los datos en
  claro), **deduplicadas** y **verificadas** automáticamente.
- **Regla 3-2-1** adaptada: datos originales + copia principal + segunda copia sincronizada en otro almacenamiento.
- **Ventana diaria de copias a las 22:00** ([ADR-0007](adr/ADR-0007-pbs-ventana-copias.md)): como no caben en memoria el
  SIEM y PBS a la vez, un temporizador apaga el SIEM, enciende PBS, copia y verifica todo, hace el mantenimiento y lo
  devuelve todo a su estado. El servidor de copias se gestiona con una clave SSH **restringida a un solo comando**.
- Copia cifrada de la configuración del firewall en git ([ADR-0008](adr/ADR-0008-opnsense-xml-cifrado.md)).

**Los 6 simulacros** ([detalle](dr/resultados-simulacros.md)):

| Simulacro | Qué se rompió | Resultado |
|---|---|---|
| DR-01 | Restaurar un servidor completo | **5 min 19 s** (objetivo 30 min) |
| DR-02 | Recuperar un único archivo borrado | Idéntico byte a byte (SHA-256) |
| DR-03 | Reconstruir un servidor desde código + base de datos | **7 min 11 s**; RPO real de 12 h, medido |
| DR-04 | Recuperar el firewall | **3 min 38 s**, configuración idéntica |
| DR-05 | Usuario borrado en Active Directory | **0,05 s**, mismo SID y mismos grupos |
| DR-06 | Copia corrupta a propósito | Detectada y reparada desde la otra copia |

**Problemas reales:** un apagón dejó **todos los relojes 2 h 46 min atrasados** (fallaban la VPN, Kerberos y los
certificados): se resincronizaron el hipervisor, el firewall y el controlador de dominio, y quedó como cambio de
emergencia. Al añadir el disco de la segunda copia, **la BIOS cambió el orden de arranque** y el hipervisor dejó de
arrancar: se fijó el orden y se añadió un aviso al script.

---

## Fase 10 · Operar como una empresa

**Problema que resuelve:** si solo una persona sabe cómo funciona, la empresa depende de ella.

**Qué se hizo**
- **8 ADR** (decisiones de arquitectura): el **porqué** de cada elección importante ([adr/](adr/README.md)).
- **Runbooks** paso a paso: alta de empleado, renovar certificados, parcheo mensual, disco lleno, restaurar una VM y
  respuesta a incidentes ([runbooks/](runbooks/README.md)).
- **Gestión de cambios**: estándar, normal y de emergencia, con **19 cambios registrados** con su riesgo y su reversión
  ([cambios/](cambios/README.md)).
- **Inventario automático** desde la API de Proxmox y los *facts* de Ansible ([inventario/](inventario/inventario.md)).
- **Rutinas programadas**: revisión semanal automática (copias, alertas, SLO, vulnerabilidades) y revisión trimestral
  de accesos contra una línea base, con informes que se guardan solos en git ([operacion/](operacion/README.md)).
- **Capacidad**: métricas del propio hipervisor y alertas de memoria y disco antes de que sea tarde.

---

## Fase 11 · Publicación

**Qué se hizo**
- Esta **versión pública** del repositorio: sin historial y sin los archivos cifrados, auditada con **gitleaks** (0
  hallazgos) y comprobada contra las credenciales reales del laboratorio, sin coincidencias.
- README pensado para entenderse en 2 minutos, esta guía y el glosario.
- Vídeo demostrativo de las capacidades principales.

---

## Lo que se aprendió

1. **Medir antes y después.** Sin la medición inicial (Lynis 63, 19.784 vulnerabilidades) no habría forma de demostrar
   la mejora.
2. **Lo que no está en el código se pierde.** La unión al dominio hecha a mano desapareció al reconstruir: desde
   entonces, si no está en Ansible, no existe.
3. **Disponibilidad no es integridad.** Una web alterada que responde «200 OK» pasa desapercibida para la
   monitorización clásica: hace falta el SIEM y, sobre todo, que avise a alguien.
4. **Las copias se prueban.** Seis simulacros encontraron cosas que no se ven sobre el papel: una restauración que
   sobrescribe la VM original, una VM restaurada que arrancaría con la IP duplicada…
5. **Los recursos son finitos.** Con 20 GB de RAM hubo que priorizar: memoria fija para el SIEM, perfiles de encendido
   y una ventana de copias que turna los servicios.
6. **Documentar es parte del trabajo.** Cada problema de esta guía está en una ADR, un runbook, un cambio o un informe:
   la próxima persona no tendrá que redescubrirlo.

**En un entorno de producción** se añadiría: clúster de 3 nodos con almacenamiento compartido, segundo controlador de
dominio, SIEM distribuido con alertas a guardia, copia fuera del sitio y MFA en todos los accesos de administración.

---

*Andes homelab · Erick Guarnizo · [github.com/GUAR-NIX/ANDES-HOMELAB](https://github.com/GUAR-NIX/ANDES-HOMELAB)*
