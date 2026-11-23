variable "pve_api_token" {
  description = "Token de la API de Proxmox (terraform@pve!tf=...). Se pasa como TF_VAR_pve_api_token."
  type        = string
  sensitive   = true
}

variable "ssh_pubkey" {
  description = "Clave publica que cloud-init instala en labadmin (la de ADM-ANS01)."
  type        = string
}

variable "servers" {
  description = "Servidores Linux gestionados por Terraform."
  type = map(object({
    id      = number
    role    = string
    cores   = number
    mem     = number
    balloon = number
    vlan    = number
    ip      = string
    gw      = string
  }))
}

