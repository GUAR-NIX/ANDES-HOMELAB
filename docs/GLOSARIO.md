# Glosario

[Volver al README](../README.md) · [Guía del proyecto](GUIA-DEL-PROYECTO.md)

Los términos técnicos del proyecto explicados con palabras sencillas, con un ejemplo de dónde aparecen en Andes.

| Término | Qué es | En Andes |
|---|---|---|
| **ADR** (Architecture Decision Record) | Documento breve que explica una decisión de diseño: el contexto, las alternativas y por qué se eligió una | 8 ADR en [docs/adr](adr/README.md) |
| **AGDLP** | Modelo de permisos de Active Directory: cuentas → grupos globales → grupos de dominio local → permisos. Nunca se dan permisos a una persona directamente | Estructura de grupos del dominio |
| **Active Directory (AD)** | El directorio de Microsoft que centraliza usuarios, contraseñas, equipos y permisos de una empresa | DC01, dominio `corp.lab.internal` |
| **Ansible** | Herramienta que configura servidores a partir de archivos de texto (*playbooks* y *roles*), sin instalar agentes | 9 roles en [ansible/roles](../ansible/roles) |
| **Ansible Vault** | Cifrado de Ansible para guardar contraseñas y claves dentro del repositorio sin que se puedan leer | Plantilla en [vault.yml.example](../ansible/group_vars/all/vault.yml.example) |
| **Ballooning** | Técnica del hipervisor para «recuperar» memoria de una VM que no la usa. Peligrosa en servicios que necesitan su memoria | Desactivada en el SIEM tras quedarse sin memoria |
| **Bastión** | Único servidor desde el que se administra el resto. Reduce los puntos de entrada | ADM-ANS01 |
| **CI/CD** | Integración y despliegue continuos: cada cambio en el código se comprueba automáticamente antes de aplicarse | GitHub Actions en [ci.yml](../.github/workflows/ci.yml) |
| **CIS Benchmark** | Guía de configuración segura publicada por el Center for Internet Security, con una puntuación de cumplimiento | Ubuntu de 53 % a 63 % |
| **cloud-init** | Sistema que personaliza un servidor en su primer arranque (nombre, IP, usuarios, claves) | Plantilla Ubuntu VM 9000 |
| **Contenedor (Docker)** | Forma de empaquetar una aplicación con todo lo que necesita para que funcione igual en cualquier servidor | Andes App en SRV-APP01 |
| **Controlador de dominio** | Servidor que ejecuta Active Directory y valida los inicios de sesión | DC01 |
| **DMZ** | Zona desmilitarizada: red intermedia para lo que se publica hacia fuera, aislada de la red interna | VLAN 50, SRV-WEB01 |
| **DR** (Disaster Recovery) | Recuperación ante desastres: cómo se vuelve a funcionar tras perder un servidor, datos o todo el sistema | 6 simulacros en [docs/dr](dr/resultados-simulacros.md) |
| **Endurecimiento** (*hardening*) | Configurar un sistema para reducir su superficie de ataque: quitar lo innecesario y cerrar lo abierto | Rol `hardening`, Lynis 63 → 83 |
| **FIM** (File Integrity Monitoring) | Vigilancia de archivos críticos: avisa si alguien los modifica | Detección del INC-0001 en 5 s |
| **Firewall** | Equipo que decide qué tráfico puede pasar entre redes | OPNsense (FW-OPN01) |
| **GPO** (Group Policy Object) | Política de Active Directory que aplica configuración a usuarios y equipos de forma centralizada | Contraseñas, bloqueo de cuentas |
| **gitleaks** | Herramienta que busca contraseñas, claves y tokens olvidados en el código y en el historial de git | En el CI y antes de publicar este repositorio |
| **Grafana** | Herramienta de paneles para visualizar métricas | Panel de capacidad de PVE01 |
| **Hipervisor** | Software que ejecuta máquinas virtuales | Proxmox VE (PVE01) |
| **IaC** (infraestructura como código) | Describir servidores y configuración en archivos de texto versionados, en lugar de hacerlo a mano | Terraform + Ansible |
| **Idempotencia** | Propiedad de una automatización que, ejecutada varias veces, deja siempre el mismo resultado sin cambiar nada de más | Ansible con `changed=0` en la segunda pasada |
| **Kerberos** | Protocolo de autenticación de Active Directory basado en «tickets»; necesita que los relojes estén sincronizados | Linux unidos al dominio |
| **Lynis** | Herramienta de auditoría de seguridad para Linux que da una puntuación de endurecimiento | 63 → 83 |
| **MITRE ATT&CK** | Catálogo mundial de técnicas usadas por atacantes reales, usado para clasificar detecciones | Casos de uso de Wazuh; INC-0001 = T1565.001 |
| **MTTD / MTTC / MTTR** | Tiempo medio hasta detectar / contener / recuperar un incidente | 5 s / 11 min 37 s / 26 min |
| **NIST SP 800-61** | Guía de referencia para gestionar incidentes: preparación, detección, contención, erradicación, recuperación y lecciones | Proceso del INC-0001 |
| **OPNsense** | Firewall y router de código abierto | Las 6 VLAN, la VPN, el DNS y la PKI |
| **PKI / CA** | Infraestructura de clave pública: una autoridad de certificación emite los certificados que cifran las conexiones | Andes-Root-CA y Andes-Issuing-CA |
| **Prometheus** | Sistema que recoge métricas de los servidores y lanza alertas | MON01 |
| **Proxmox Backup Server (PBS)** | Servidor de copias de Proxmox: cifradas, deduplicadas y verificables | SRV-PBS01 |
| **Proxy inverso** | Servidor que recibe las peticiones de los usuarios y las reenvía a la aplicación, sin exponerla | nginx en SRV-WEB01 |
| **Regla 3-2-1** | Tres copias de los datos, en dos soportes distintos y una fuera del sitio | Copia principal + segunda copia sincronizada (la externa, riesgo aceptado) |
| **Runbook** | Procedimiento paso a paso para una tarea concreta, para que cualquiera pueda hacerla bien | 6 runbooks en [docs/runbooks](runbooks/README.md) |
| **RPO / RTO** | Cuántos datos se pueden perder (RPO) y cuánto tiempo puede estar caído un servicio (RTO) | RTO medido de 5 min 19 s en DR-01 |
| **SIEM** | Sistema que centraliza los registros de seguridad de toda la empresa y detecta ataques | Wazuh (SRV-SIEM01) |
| **SLO** | Objetivo de nivel de servicio: por ejemplo, «la web disponible el 99 % del tiempo» | SLO del 99 % con informe semanal |
| **SSSD** | Servicio de Linux que permite iniciar sesión con cuentas de Active Directory | Rol `ad_member` |
| **Terraform** | Herramienta que crea y modifica infraestructura (aquí, máquinas virtuales) a partir de código | [terraform/](../terraform) |
| **Trivy** | Escáner de vulnerabilidades y malas configuraciones en imágenes de contenedores y código | En el CI |
| **VLAN** | Red virtual: divide una red física en varias redes separadas | 6 VLAN (10, 20, 30, 40, 50 y 60) |
| **VPN (WireGuard)** | Túnel cifrado para conectarse a una red privada desde fuera | Única vía de administración |
| **Wazuh** | SIEM y XDR de código abierto | Detección del INC-0001 |
| **Who-data** | Modo del FIM de Wazuh que registra no solo qué cambió, sino quién y con qué proceso | Identificó al usuario y el comando `sed` |
