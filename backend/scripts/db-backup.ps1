param(
  [string]$BackupDirectory = ".\backups"
)
$ErrorActionPreference = "Stop"
if (-not $env:DATABASE_URL) { throw "DATABASE_URL wajib diisi." }
New-Item -ItemType Directory -Force -Path $BackupDirectory | Out-Null
$stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
$file = Join-Path $BackupDirectory "firefa-$stamp.dump"
pg_dump --format=custom --no-owner --no-acl $env:DATABASE_URL --file $file
if ($LASTEXITCODE -ne 0) { throw "pg_dump gagal dengan exit code $LASTEXITCODE" }
Write-Output "Backup dibuat: $file"
