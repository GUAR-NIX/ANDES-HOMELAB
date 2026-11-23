# Diagramas

Diagramas en Mermaid, versionados con el código: GitHub los dibuja al abrir este archivo. Si cambia la red o un servicio,
se actualizan en el mismo PR que el cambio.

## 1. Red (capa 3) y flujos permitidos

Todo el tráfico entre VLAN está bloqueado (F03/F05) salvo los flujos dibujados. La administración entra solo por la VPN.

```mermaid
flowchart LR
  subgraph HOST["Portátil Windows 11 + VMware Workstation"]
    WIN["Administrador<br/>WireGuard 10.99.0.2"]
    subgraph NAT["Red NAT de VMware 192.168.188.0/24"]
      PVE["PVE01 Proxmox VE<br/>192.168.188.10"]
    end
  end
  FW{{"FW-OPN01 OPNsense<br/>WAN 192.168.188.20<br/>gateway .1 de cada VLAN"}}
  subgraph V10["VLAN 10 MGMT 10.10.10.0/24"]
    ADM["ADM-ANS01 .10<br/>Terraform, Ansible, git"]
    MON["MON01 .20<br/>Prometheus, Grafana"]
  end
  subgraph V20["VLAN 20 SERVERS 10.10.20.0/24"]
    DC["DC01 .20<br/>AD, DNS"]
    APP["SRV-APP01 .30<br/>Andes App + PostgreSQL"]
  end
  subgraph V30["VLAN 30 USERS 10.10.30.0/24"]
    CLI["Equipos de usuario<br/>DHCP .100-.200"]
  end
  subgraph V40["VLAN 40 SEC 10.10.40.0/24"]
    SIEM["SRV-SIEM01 .10<br/>Wazuh"]
  end
  subgraph V50["VLAN 50 DMZ 10.10.50.0/24"]
    WEB["SRV-WEB01 .10<br/>nginx proxy TLS"]
  end
  subgraph V60["VLAN 60 BKP 10.10.60.0/24"]
    PBS["SRV-PBS01 .10<br/>Proxmox Backup Server"]
  end

  WIN -- "VPN WireGuard UDP 51820" --> FW
  FW --- V10 & V20 & V30 & V40 & V50 & V60
  CLI -- "F01 HTTPS" --> WEB
  CLI -- "F02 AD/DNS" --> DC
  WEB -- "F04 8080" --> APP
  ADM -- "F06 SSH/HTTPS/RDP" --> V20 & V40 & V50 & V60
  ADM -- "F12 API 8006" --> PVE
  V10 & V20 & V50 -- "F07 1514-1515" --> SIEM
  MON -- "9100/9182 métricas" --> APP & WEB & DC
  PVE -- "F09 8007 + 22" --> PBS
```

## 2. Dependencias entre servicios

```mermaid
flowchart TD
  PVE01[PVE01 hipervisor] --> FW[FW-OPN01: rutas, DNS, NTP, VPN]
  FW --> DC01[DC01: AD y DNS interno]
  FW --> ADM[ADM-ANS01: administración e IaC]
  DC01 --> APP[SRV-APP01: Andes App]
  APP --> DB[(PostgreSQL)]
  APP --> WEB[SRV-WEB01: proxy publicado]
  FW --> MON[MON01: monitorización y alertas]
  FW --> SIEM[SRV-SIEM01: SIEM]
  PVE01 --> PBS[SRV-PBS01: copias]
  PKI[Andes-Root-CA / Issuing-CA en OPNsense] -.certificados.-> WEB & MON & SIEM & PVE01
  ADM -.Terraform.-> PVE01
  ADM -.Ansible.-> APP & WEB & MON & SIEM
```

Orden de recuperación ante una pérdida total: PVE01 y PBS → firewall → DC01 → ADM-ANS01 → app → web →
monitorización y SIEM (docs/dr/plan-continuidad.md).

## 3. Flujo de las copias (ventana diaria de las 22:00)

```mermaid
sequenceDiagram
  participant T as Temporizador PVE01 (22:00)
  participant P as PVE01
  participant S as SRV-SIEM01
  participant B as SRV-PBS01
  participant U as ds-usb (C:\Lab\USB-PBS)
  T->>P: andes-ventana-backup.sh
  P->>S: apagado ordenado
  P->>B: arranque
  P->>B: vzdump de las VM (cifrado en PVE01)
  B->>B: verificación de cada copia (verify-new)
  P->>B: ssh con clave restringida: mantenimiento
  B->>B: retención (diaria) / GC y re-verificación (domingo)
  B->>U: sincronización de la copia 2 (sábado)
  P->>B: apagado
  P->>S: arranque (pase lo que pase)
```

## 4. Flujo de un cambio de configuración

```mermaid
flowchart LR
  A[Rama en ADM-ANS01] --> B[ci-local.sh] --> C[Push y PR] --> D{CI en GitHub<br/>gitleaks, Terraform,<br/>ansible-lint, Trivy}
  D -- rojo --> A
  D -- verde --> E[Merge a main] --> F[--check --diff] --> G[ansible-playbook / terraform apply] --> H[verificar-servicios.sh]
```
