# ADR-0004: el estado de Terraform se guarda fuera de Git

- **Fecha:** 21/11/2026
- **Estado:** aceptado

## Contexto
Terraform guarda en el archivo de estado (`terraform.tfstate`) todo lo que sabe de cada recurso: identificadores,
configuración completa de las VM, direcciones IP, claves públicas y, según el provider, valores marcados como
sensibles. El repositorio `andes-config` se publicará en GitHub (Fase 11).

## Decisión
- El estado vive en ADM-ANS01, en `/home/labadmin/.terraform-state/andes.tfstate` (backend `local`, carpeta 700),
  fuera del repositorio. `.gitignore` excluye `*.tfstate*`, `.terraform/` y `tfplan`.
- El token de la API de Proxmox (`terraform@pve!tf`) nunca está en archivos del repositorio: se carga como variable de
  entorno `TF_VAR_pve_api_token` desde `~/.secrets/pve-terraform.env` (permisos 600) y la variable es `sensitive`.
- El token tiene un rol mínimo (`TerraformProv`) y solo se puede usar desde ADM-ANS01: el flujo F12 de OPNsense
  permite únicamente HOST_ADM01 → HOST_PVE01:8006.

## Consecuencias
- Si se pierde ADM-ANS01 se pierde el estado: las VM siguen existiendo y se recuperan con `terraform import`
  (como se hizo la primera vez). La copia de ADM-ANS01 en Proxmox Backup Server (Fase 9) cubre este riesgo.
- Mejora futura: backend S3 compatible (MinIO en MGMT) con cifrado y bloqueo de estado.
