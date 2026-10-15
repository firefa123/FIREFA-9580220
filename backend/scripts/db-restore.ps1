param(
  [Parameter(Mandatory=$true)][string]$BackupFile,
  [switch]$ConfirmRestore
)
$ErrorActionPreference = "Stop"
if (-not $env:DATABASE_URL) { throw "DATABASE_URL wajib diisi." }
if (-not $ConfirmRestore) { throw "Restore mengganti objek/data target. Jalankan ulang dengan -ConfirmRestore." }
if (-not (Test-Path -LiteralPath $BackupFile -PathType Leaf)) { throw "File backup tidak ditemukan: $BackupFile" }
pg_restore --clean --if-exists --no-owner --no-acl --dbname $env:DATABASE_URL $BackupFile
if ($LASTEXITCODE -ne 0) { throw "pg_restore gagal dengan exit code $LASTEXITCODE" }
Write-Output "Restore selesai dari: $BackupFile"
