# Fase 9.3 - Copia del System State de DC01 con Windows Server Backup.
# Se ejecuta desde la Shell de PVE01 (DC01 es Server Core y se administra con qm guest exec):
#   qm set 201 -scsi1 local-lvm:30,discard=on,iothread=1      (disco de destino, solo la primera vez)
#   qm guest exec 201 --timeout 300 -- powershell -NoProfile -EncodedCommand $(iconv -f UTF-8 -t UTF-16LE dc01-systemstate.ps1 | base64 -w0)
# Ese disco SI entra en la copia nocturna de PBS: el System State queda tambien en ds-main y en la "USB" (ds-usb).
$ErrorActionPreference = 'Stop'
# 1. Disco de 30 GB sin volumen -> S: (SYSSTATE). D: y E: son las ISO montadas en DC01
$d = Get-Disk | Where-Object { $_.Size -eq 30GB -and -not ($_ | Get-Partition -ErrorAction SilentlyContinue | Where-Object DriveLetter) } | Select-Object -First 1
if ($d) {
  if ($d.PartitionStyle -eq 'RAW') { Initialize-Disk -Number $d.Number -PartitionStyle GPT }
  New-Partition -DiskNumber $d.Number -UseMaximumSize -DriveLetter S | Format-Volume -FileSystem NTFS -NewFileSystemLabel SYSSTATE -Confirm:$false | Out-Null
  'Disco S: SYSSTATE creado'
}
# 2. Windows Server Backup
if (-not (Get-WindowsFeature Windows-Server-Backup).Installed) { Install-WindowsFeature Windows-Server-Backup | Out-Null; 'Windows Server Backup instalado' }
# 3. Copia diaria del System State a las 01:00 (antes de PBS a las 02:00), como SYSTEM
$a = New-ScheduledTaskAction -Execute 'wbadmin.exe' -Argument 'start systemstatebackup -backupTarget:S: -quiet'
$t = New-ScheduledTaskTrigger -Daily -At '01:00'
Register-ScheduledTask -TaskName 'Andes-SystemStateBackup' -Action $a -Trigger $t -User 'SYSTEM' -RunLevel Highest -Force | Out-Null
Start-ScheduledTask -TaskName 'Andes-SystemStateBackup'
'Tarea Andes-SystemStateBackup creada (diaria 01:00) y lanzada ahora'
Get-Volume -DriveLetter S | Format-List DriveLetter, FileSystemLabel, Size
