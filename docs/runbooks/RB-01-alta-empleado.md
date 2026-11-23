# RB-01 · Alta y baja de un empleado

**Disparador:** solicitud de Recursos Humanos con nombre, departamento y fecha de incorporación (o de salida).
**Responsable:** Helpdesk (GG-Helpdesk puede restablecer contraseñas y desbloquear cuentas en OU=Usuarios) o TI.
**Duración:** 5 min.

## Estructura del directorio

| Departamento | OU | Grupo global |
|---|---|---|
| TI | OU=TI,OU=Usuarios,OU=CORP,DC=corp,DC=lab,DC=internal | GG-TI |
| Operaciones | OU=Operaciones,OU=Usuarios,OU=CORP,… | GG-Operaciones |
| Administración | OU=Administracion,OU=Usuarios,OU=CORP,… | GG-Administracion |

Los permisos sobre recursos se dan a grupos locales de dominio (DL-…) que contienen los grupos globales (modelo AGDLP);
nunca a usuarios sueltos. Política de contraseñas: longitud mínima 14, historial 24, bloqueo tras 10 intentos durante
15 min, sin caducidad forzada (recomendación NIST).

## Alta
En la Shell de PVE01 (DC01 es Server Core), cambiando los datos marcados:

```bash
cat > /root/alta.ps1 <<'EOF'
$ErrorActionPreference = 'Stop'
$nombre = 'Lucia'; $apellido = 'Mora'; $depto = 'Operaciones'          # <- datos de la solicitud
$sam = ($nombre.Substring(0,1) + $apellido).ToLower()                    # lmora (o nombre.apellido, criterio de la empresa)
$pw  = -join ((48..57)+(65..90)+(97..122) | Get-Random -Count 16 | ForEach-Object {[char]$_}) + '!'
New-ADUser -Name "$nombre $apellido" -GivenName $nombre -Surname $apellido -SamAccountName $sam `
  -UserPrincipalName "$sam@corp.lab.internal" -Path "OU=$depto,OU=Usuarios,OU=CORP,DC=corp,DC=lab,DC=internal" `
  -AccountPassword (ConvertTo-SecureString $pw -AsPlainText -Force) -ChangePasswordAtLogon $true -Enabled $true `
  -Description "Alta RB-01 $(Get-Date -Format yyyy-MM-dd)"
Add-ADGroupMember -Identity "GG-$depto" -Members $sam
"Usuario $sam creado en $depto. Contrasena temporal: $pw"
EOF
qm guest exec 201 --timeout 60 -- powershell -NoProfile -EncodedCommand $(iconv -f UTF-8 -t UTF-16LE /root/alta.ps1 | base64 -w0) \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('out-data',''))"
shred -u /root/alta.ps1
```

La contraseña temporal se entrega al empleado por un canal distinto del usuario (en persona o por teléfono), nunca por
correo ni en el ticket; tendrá que cambiarla en el primer inicio de sesión.

## Verificación
```bash
qm guest exec 201 -- powershell -NoProfile -Command "Get-ADUser lmora -Properties MemberOf,Enabled,DistinguishedName | Format-List Name,Enabled,DistinguishedName,MemberOf"
```
Debe estar habilitado, en su OU y en su grupo GG-. El SIEM registra el alta (regla de Windows 4720).

## Baja
El día de salida: deshabilitar (no borrar), quitar de los grupos y moverlo a una OU de bajas si existe.
```powershell
Disable-ADAccount lmora; Get-ADUser lmora -Properties MemberOf | Select-Object -ExpandProperty MemberOf | ForEach-Object { Remove-ADGroupMember $_ -Members lmora -Confirm:$false }
Set-ADUser lmora -Description "Baja RB-01 $(Get-Date -Format yyyy-MM-dd)"
```
Se borra pasados 90 días; si se borra por error, se recupera desde la Papelera de AD (RB-05, caso AD).

## Reversión
Alta por error: `Remove-ADUser <sam>` (queda en la Papelera de AD 180 días). Baja por error: `Enable-ADAccount` y volver a
añadir los grupos que tenía (anotados en el registro de cambios).
