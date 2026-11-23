# Fase 9.2 - SRV-PBS01: Proxmox Backup Server en la VLAN 60 (BKP)
# No sale de la plantilla Ubuntu: PBS se instala desde su ISO oficial (Debian), asi que
# Terraform crea la VM "vacia" (CPU, RAM, discos, red, ISO) y la instalacion se hace por consola.

resource "proxmox_virtual_environment_vm" "pbs" {
  name        = "srv-pbs01"
  description = "Proxmox Backup Server (Fase 9). Datastore ds-main en el segundo disco."
  node_name   = "pve01"
  vm_id       = 160
  tags        = ["terraform", "pbs"]
  on_boot     = false # solo se enciende en la ventana diaria de copias (andes-ventana-backup.timer en PVE01)
  started     = true

  scsi_hardware = "virtio-scsi-single"

  operating_system {
    type = "l26"
  }

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 2048
    floating  = 0 # sin ballooning: leccion de la Fase 7 (OOM de Wazuh)
  }

  # qemu-guest-agent instalado por scripts/fase9/pbs-config.sh (la ISO no lo trae)
  agent {
    enabled = true
    timeout = "2m"
  }

  # scsi0: sistema. scsi1: datos del datastore (thin: solo ocupa lo que se escribe)
  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = 32
    discard      = "on"
    ssd          = true
    iothread     = true
  }
  disk {
    datastore_id = "local-lvm"
    interface    = "scsi1"
    size         = 120
    discard      = "on"
    ssd          = true
    iothread     = true
  }

  # La ISO solo hizo falta para instalar (21/11/2026); ya instalado, la unidad queda vacia
  # scsi2 (64 GB) NO se declara aqui: es el disco "extraible" de la copia 2 (datastore ds-usb), un disco de
  # VMware en C:\Lab\USB-PBS del anfitrion pasado a la VM con "qm set 160 -scsi2 /dev/disk/by-path/...,backup=0".
  # Pasar un dispositivo fisico solo lo permite root@pam, no el token de Terraform. Ver scripts/fase9/pbs-usb.sh.

  cdrom {
    interface = "ide2"
    file_id   = "none"
  }

  boot_order = ["scsi0"]

  network_device {
    bridge  = "vmbr1"
    vlan_id = 60
  }

  lifecycle {
    ignore_changes = [started]
  }
}
