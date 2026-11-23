# Bitácora de implementación (Fases 0 a 11)

**[📄 Abrir la bitácora en PDF](../../BITACORA-PASO-A-PASO.pdf)** · **[📝 Descargar en Word](../../BITACORA-PASO-A-PASO.docx)** (185 páginas)

Es el diario de obra del proyecto: cada paso, en el orden en que se hizo, con **434 capturas de pantalla**, los comandos
ejecutados, los errores que aparecieron y cómo se resolvieron. Es la evidencia de que todo lo que se cuenta en el
[README](../../README.md) y en la [guía del proyecto](../GUIA-DEL-PROYECTO.md) se hizo de verdad.

| Fase | Contenido |
|---|---|
| 0 | Preparación del anfitrión: virtualización anidada, HVCI, imágenes |
| 1 | Proxmox VE, post-instalación y plantilla cloud-init |
| 2 | OPNsense, VLAN, matriz de flujos, DNS y VPN WireGuard |
| 3 | Active Directory, estructura de la empresa, GPO y Linux en el dominio |
| 4 | Servidores endurecidos (Lynis, CIS) y PKI interna |
| 5 | Andes App en Docker y proxy en la DMZ |
| 6 | Prometheus, Grafana, alertas y SLO |
| 7 | Wazuh, casos de uso, vulnerabilidades e incidente simulado |
| 8 | Terraform, Ansible y CI en GitHub Actions |
| 9 | Proxmox Backup Server y simulacros de recuperación |
| 10 | Runbooks, cambios, inventario, rutinas y capacidad |
| 11 | Publicación del portafolio |

## Versión pública: qué se ha ocultado

Antes de publicarla se revisó **el texto y el contenido de cada captura** (reconocimiento óptico de caracteres sobre las
434 imágenes, revisión visual de las 27 con palabras de riesgo y comparación con las credenciales reales del
laboratorio). Todo lo que podía dar acceso aparece tapado con una franja negra **«REDACTADO»**:

- contraseñas (por ejemplo, la que muestra el instalador de Wazuh al terminar);
- tokens de API, identificadores de tokens y códigos de un solo uso (TOTP);
- cadenas largas con aspecto de secreto (claves, hashes y huellas, aunque muchas no lo sean).

Las contraseñas que se escribían en comandos ya estaban ocultas en las capturas originales (franjas grises). Las
direcciones IP son privadas (10.x y 192.168.x) y el dominio `corp.lab.internal` no existe fuera del laboratorio.

*Bitácora de Erick Guarnizo · Andes homelab.*
