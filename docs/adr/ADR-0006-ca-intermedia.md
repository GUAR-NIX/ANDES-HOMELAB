# ADR-0006 · PKI propia de dos niveles en OPNsense

| Estado | Fecha | Fase |
|---|---|---|
| Aceptada | 2026-11-13 | 4 |

## Contexto
Los servicios internos (web publicada, Proxmox, Grafana, Wazuh) necesitan HTTPS con certificados de confianza. El dominio
`corp.lab.internal` no es público, así que no se puede usar una CA pública.

## Decisión
Una PKI de dos niveles gestionada en OPNsense: **Andes-Root-CA** (raíz, solo firma la intermedia) y **Andes-Issuing-CA**
(emisora, firma los certificados de servidor). La raíz se distribuye a los Linux (rol `common`), a Windows y al dominio
(GPO SEC-Trust-RootCA).

## Alternativas consideradas
- **Certificados autofirmados**: avisos en cada navegador y nadie puede verificarlos.
- **AD CS en DC01**: más memoria y más servicios en el servidor más sensible; además DC01 es Server Core.
- **Una sola CA**: si su clave se compromete hay que revocar y redistribuir todo; con la intermedia, la raíz apenas se usa.

## Consecuencias
- Certificados emitidos: srv-web01 (app y srv-web01), pve01, mon01 (Grafana) y siem01 (Wazuh). Se renuevan con RB-02.
- La clave privada de la raíz vive en la configuración de OPNsense: por eso la copia de esa configuración va cifrada
  (ADR-0008) y nunca en claro en Git.
- Pendiente opcional: un certificado de la emisora para la propia web de OPNsense (hoy autofirmada; se fija su clave
  pública en los scripts que usan su API).
