# Fase 8.1 - VMs declarativas en Proxmox (provider bpg/proxmox)
# Las VMs existentes se importan (terraform import) y quedan gestionadas sin recrearse:
# lo que se crea solo al nacer (clon, cloud-init, disco) se ignora en los cambios posteriores.

terraform {
  required_version = ">= 1.9"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.123"
    }
  }
  # Estado FUERA del repositorio: contiene datos sensibles (ver ADR-0004)
  backend "local" {
    path = "/home/labadmin/.terraform-state/andes.tfstate"
  }
}

provider "proxmox" {
  endpoint  = "https://pve01.corp.lab.internal:8006/"
  api_token = var.pve_api_token # viene de TF_VAR_pve_api_token (nunca en archivos del repo)
}

resource "proxmox_virtual_environment_vm" "srv" {
  for_each  = var.servers
  name      = each.key
  node_name = "pve01"
  vm_id     = each.value.id
  tags      = ["terraform", each.value.role]
  on_boot   = true
  started   = true

  scsi_hardware = "virtio-scsi-single" # el de la plantilla 9000 (el provider usaria virtio-scsi-pci)

  clone {
    vm_id = 9000
    full  = true
  }

  cpu {
    cores = each.value.cores
    type  = "host"
  }

  memory {
    dedicated = each.value.mem
    floating  = each.value.balloon
  }

  agent {
    enabled = true
    timeout = "2m" # sin esto, una VM sin agente bloquea apply/plan hasta 15 min
  }

  network_device {
    bridge  = "vmbr1"
    vlan_id = each.value.vlan
  }

  initialization {
    ip_config {
      ipv4 {
        address = each.value.ip
        gateway = each.value.gw
      }
    }
    dns {
      servers = [each.value.gw]
      domain  = "corp.lab.internal"
    }
    user_account {
      username = "labadmin"
      keys     = [var.ssh_pubkey]
    }
    # Instala y arranca qemu-guest-agent en el primer arranque (snippet en PVE01: local:snippets/qga.yaml)
    vendor_data_file_id = "local:snippets/qga.yaml"
  }

  lifecycle {
    # Atributos de nacimiento: no se reaplican a VMs ya creadas o importadas
    ignore_changes = [clone, initialization, disk, operating_system, serial_device, vga, cpu[0].type, network_device[0].mac_address, started]
  }
}

