# Inventario de servidores (sin secretos; versionado en Git)
ssh_pubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGeW5pYiE4eZNg29c4BOO4IukMH96knnpp2Zgoa6R9v/ erick@adm-ans01"

servers = {
  "srv-web01" = {
    id = 150, role = "dmz", cores = 2, mem = 1536, balloon = 1024, vlan = 50
    ip = "10.10.50.10/24", gw = "10.10.50.1"
  }
  "srv-app01" = {
    id = 130, role = "app", cores = 2, mem = 2560, balloon = 0, vlan = 20
    ip = "10.10.20.30/24", gw = "10.10.20.1"
  }
  "mon01" = {
    id = 120, role = "mon", cores = 2, mem = 2048, balloon = 0, vlan = 10
    ip = "10.10.10.20/24", gw = "10.10.10.1"
  }
}

