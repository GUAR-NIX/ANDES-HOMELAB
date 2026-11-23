# Fase 9.4 - Simulacro DR-05: usuario borrado en AD y recuperado desde la Papelera de reciclaje.
# Crea un usuario y un grupo de PRUEBA, borra el usuario, lo restaura con Restore-ADObject y comprueba
# que conserva el mismo SID y la pertenencia al grupo. Al final limpia lo creado.
# Desde la Shell de PVE01:
#   qm guest exec 201 --timeout 120 -- powershell -NoProfile -EncodedCommand $(iconv -f UTF-8 -t UTF-16LE dr05-ad-recycle.ps1 | base64 -w0)
$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory
$base = 'CN=Users,DC=corp,DC=lab,DC=internal'
$pw = ConvertTo-SecureString ([guid]::NewGuid().ToString() + 'Aa1!') -AsPlainText -Force

New-ADGroup -Name 'GG-DR05-Prueba' -GroupScope Global -Path $base -Description 'Grupo de prueba DR-05'
New-ADUser -Name 'dr05.prueba' -SamAccountName 'dr05.prueba' -AccountPassword $pw -Enabled $true -Path $base -Description 'Usuario de prueba DR-05'
Add-ADGroupMember -Identity 'GG-DR05-Prueba' -Members 'dr05.prueba'
$antes = Get-ADUser 'dr05.prueba' -Properties memberOf
"ANTES     : SID $($antes.SID.Value) | grupos: $($antes.memberOf -join '; ')"

Remove-ADUser 'dr05.prueba' -Confirm:$false
$tBorrado = Get-Date
"BORRADO   : $($tBorrado.ToString('HH:mm:ss')) (simula el error de un administrador)"

$del = Get-ADObject -Filter "samAccountName -eq 'dr05.prueba'" -IncludeDeletedObjects -Properties isDeleted, lastKnownParent
"PAPELERA  : isDeleted=$($del.isDeleted) | ultimo contenedor: $($del.lastKnownParent)"
$t0 = Get-Date
$del | Restore-ADObject
$t1 = Get-Date

$despues = Get-ADUser 'dr05.prueba' -Properties memberOf
"RESTAURADO: en $([math]::Round(($t1 - $t0).TotalSeconds, 2)) s | SID $($despues.SID.Value) | grupos: $($despues.memberOf -join '; ')"
"MISMO SID : $($antes.SID.Value -eq $despues.SID.Value)"
"MISMOS GRUPOS: $((($antes.memberOf | Sort-Object) -join ';') -eq (($despues.memberOf | Sort-Object) -join ';'))"
"HABILITADO: $($despues.Enabled)"

Remove-ADUser 'dr05.prueba' -Confirm:$false
Remove-ADGroup 'GG-DR05-Prueba' -Confirm:$false
'LIMPIEZA  : usuario y grupo de prueba eliminados'
