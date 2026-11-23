# Fase 9 - Cuenta de servicio svc-adjoin para el rol de Ansible ad_member (se ejecuta en DC01 con qm guest exec).
# La contrasena NO esta aqui: se genera en ADM-ANS01 directamente en Ansible Vault (vault_ad_join_password) y se
# inserta en la linea marcada solo en el momento de ejecutarlo; el script temporal se borra con shred.
$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory
$base    = 'OU=CORP,DC=corp,DC=lab,DC=internal'
$ouLinux = "OU=Linux,OU=Servidores,$base"
$ouServ  = "OU=Servicio,$base"
$pw = ConvertTo-SecureString '<CONTRASENA DE VAULT>' -AsPlainText -Force
if (Get-ADUser -Filter "SamAccountName -eq 'svc-adjoin'") { Set-ADAccountPassword 'svc-adjoin' -Reset -NewPassword $pw }
else {
  New-ADUser -Name 'svc-adjoin' -SamAccountName 'svc-adjoin' -UserPrincipalName 'svc-adjoin@corp.lab.internal' -Path $ouServ `
    -AccountPassword $pw -Enabled $true -PasswordNeverExpires $true -CannotChangePassword $true `
    -Description 'Une servidores Linux a OU=Linux (Ansible ad_member, Fase 9)'
}
# Delegacion minima: crear/borrar objetos equipo en OU=Linux y control solo sobre esos objetos equipo
dsacls $ouLinux /I:T /G 'CORP\svc-adjoin:CCDC;computer' | Out-Null
dsacls $ouLinux /I:S /G 'CORP\svc-adjoin:GA;;computer' | Out-Null
dsacls $ouLinux | Select-String 'svc-adjoin'
'Grupos: [' + ((Get-ADUser 'svc-adjoin' -Properties memberOf).memberOf -join '; ') + '] (vacio = sin privilegios de dominio)'
