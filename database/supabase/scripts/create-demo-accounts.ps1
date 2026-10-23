<#
.SYNOPSIS
    Prepara las cuentas demo locales de PLUS_LPS para Supabase Auth.

.DESCRIPTION
    El seed (`seed.sql`) crea los usuarios de Auth con una contraseña aleatoria
    que nadie conoce (para no versionar credenciales). Este helper fija una
    contraseña utilizable para esas cuentas usando el Admin API de Supabase Auth.

    Las claves locales (API_URL y service_role/secret key) NO se guardan en el
    repositorio: se leen en tiempo de ejecución desde `supabase status -o env`.
    La contraseña generada se escribe en un archivo local ignorado por git
    (por defecto `.env.demo.local`) y solo se imprime la ruta, no el valor.

    Solo funciona contra el stack local (127.0.0.1 / localhost).

.PARAMETER Password
    Contraseña a aplicar. Si se omite, se genera una aleatoria por ejecución.

.PARAMETER OutFile
    Archivo local para dejar las credenciales de desarrollo. Por defecto
    `.env.demo.local` (ignorado por git). Usa `-NoFile` para no escribir nada.

.EXAMPLE
    ./scripts/create-demo-accounts.ps1

.EXAMPLE
    ./scripts/create-demo-accounts.ps1 -NoFile -Password 'una-clave-local'
#>
[CmdletBinding()]
param(
  [string]$Password,
  [string]$OutFile = '.env.demo.local',
  [switch]$NoFile
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$SupabaseDir = Split-Path -Parent $PSScriptRoot
if (-not $OutFile -or [System.IO.Path]::IsPathRooted($OutFile)) {
  $OutFilePath = $OutFile
} else {
  $OutFilePath = Join-Path $SupabaseDir $OutFile
}

function Get-LocalSupabaseEnv {
  Push-Location $SupabaseDir
  try {
    $script:ErrorActionPreference = 'Continue'
    $raw = @(& supabase status -o env 2>&1)
    $exit = $LASTEXITCODE
    $script:ErrorActionPreference = 'Stop'
  } finally {
    Pop-Location
  }

  $map = @{}
  foreach ($line in $raw) {
    if ($line -match '^([A-Z_]+)="?(.*?)"?\s*$') { $map[$Matches[1]] = $Matches[2] }
  }

  if (-not $map['API_URL']) {
    throw "No se pudo leer el estado de Supabase local. Ejecuta 'supabase start' en database/supabase. (exit=$exit)"
  }
  return $map
}

$local = Get-LocalSupabaseEnv
$apiUrl = $local['API_URL']
$serviceKey = $local['SERVICE_ROLE_KEY']
$anonKey = $local['ANON_KEY']
$publishableKey = $local['PUBLISHABLE_KEY']

$uri = [System.Uri]$apiUrl
if ($uri.Host -notin @('127.0.0.1', 'localhost', '::1')) {
  throw "Este helper es solo para el stack local. API_URL apunta a '$($uri.Host)'."
}
if (-not $serviceKey) {
  throw 'No se encontró SERVICE_ROLE_KEY en supabase status -o env.'
}

if (-not $Password) {
  # Compatible con Windows PowerShell 5.1 (RandomNumberGenerator.Fill no existe ahí).
  $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
  $bytes = New-Object byte[] 24
  $rng.GetBytes($bytes)
  $Password = ([Convert]::ToBase64String($bytes) -replace '[+/=]', '') + 'Aa1!'
  Write-Host 'Se generó una contraseña aleatoria para las cuentas demo.' -ForegroundColor Cyan
}

# Cuentas demo. Los UUID coinciden con los del seed para que las asignaciones,
# rutas y perfiles creados allí queden ligados a usuarios con login real.
$demoAccounts = @(
  @{ Email = 'coordinador.demo@plus-lps.test'; Id = '11111111-1111-4111-8111-111111111111'; Role = 'coordinador'; Name = 'Coordinador Demo' }
  @{ Email = 'despachador.demo@plus-lps.test'; Id = '22222222-2222-4222-8222-222222222222'; Role = 'despachador'; Name = 'Despachador Demo' }
  @{ Email = 'tecnico.uno@plus-lps.test';    Id = '33333333-3333-4333-8333-333333333331'; Role = 'tecnico'; Name = 'Técnico Demo Uno' }
  @{ Email = 'tecnico.dos@plus-lps.test';    Id = '33333333-3333-4333-8333-333333333332'; Role = 'tecnico'; Name = 'Técnico Demo Dos' }
  @{ Email = 'tecnico.tres@plus-lps.test';   Id = '33333333-3333-4333-8333-333333333333'; Role = 'tecnico'; Name = 'Técnico Demo Tres' }
  @{ Email = 'tecnico.cuatro@plus-lps.test'; Id = '33333333-3333-4333-8333-333333333334'; Role = 'tecnico'; Name = 'Técnico Demo Cuatro' }
  @{ Email = 'tecnico.cinco@plus-lps.test';  Id = '33333333-3333-4333-8333-333333333335'; Role = 'tecnico'; Name = 'Técnico Demo Cinco' }
  @{ Email = 'tecnico.seis@plus-lps.test';   Id = '33333333-3333-4333-8333-333333333336'; Role = 'tecnico'; Name = 'Técnico Demo Seis' }
  @{ Email = 'tecnico.siete@plus-lps.test';  Id = '33333333-3333-4333-8333-333333333337'; Role = 'tecnico'; Name = 'Técnico Demo Siete' }
  @{ Email = 'tecnico.ocho@plus-lps.test';   Id = '33333333-3333-4333-8333-333333333338'; Role = 'tecnico'; Name = 'Técnico Demo Ocho' }
)

$adminHeaders = @{
  apikey        = $serviceKey
  Authorization = "Bearer $serviceKey"
  'Content-Type' = 'application/json'
}

$results = @()
foreach ($account in $demoAccounts) {
  $exists = $false
  try {
    Invoke-RestMethod -Method Get -Uri "$apiUrl/auth/v1/admin/users/$($account.Id)" -Headers $adminHeaders | Out-Null
    $exists = $true
  } catch {
    if ($_.Exception.Response.StatusCode.value__ -ne 404) {
      throw "Error consultando $($account.Email): $($_.Exception.Message)"
    }
  }

  $payload = @{
    password     = $Password
    email_confirm = $true
    app_metadata = @{ provider = 'email'; providers = @('email'); role = $account.Role }
    user_metadata = @{ full_name = $account.Name }
  } | ConvertTo-Json -Depth 5

  if ($exists) {
    # No se toca el email para no romper las referencias del seed.
    $null = Invoke-RestMethod -Method Put -Uri "$apiUrl/auth/v1/admin/users/$($account.Id)" -Headers $adminHeaders -Body $payload
    $action = 'password actualizado'
  } else {
    $createPayload = @{
      id            = $account.Id
      email         = $account.Email
      password      = $Password
      email_confirm = $true
      app_metadata  = @{ provider = 'email'; providers = @('email'); role = $account.Role }
      user_metadata = @{ full_name = $account.Name }
    } | ConvertTo-Json -Depth 5
    $null = Invoke-RestMethod -Method Post -Uri "$apiUrl/auth/v1/admin/users" -Headers $adminHeaders -Body $createPayload
    $action = 'usuario creado'
  }

  $results += [pscustomobject]@{ Email = $account.Email; Role = $account.Role; Accion = $action }
}

Write-Host ''
$results | Format-Table -AutoSize | Out-String | Write-Host

if (-not $NoFile) {
  $lines = @(
    '# Credenciales de desarrollo generadas por scripts/create-demo-accounts.ps1',
    '# Archivo local NO versionado (.env.* está en .gitignore). No compartir.',
    "SUPABASE_URL=$apiUrl",
    "SUPABASE_ANON_KEY=$anonKey",
    "SUPABASE_PUBLISHABLE_KEY=$publishableKey",
    "SUPABASE_DEMO_PASSWORD=$Password",
    "SUPABASE_DEMO_COORDINADOR_EMAIL=coordinador.demo@plus-lps.test",
    "SUPABASE_DEMO_DESPACHADOR_EMAIL=despachador.demo@plus-lps.test"
  )
  foreach ($account in $demoAccounts) {
    if ($account.Role -eq 'tecnico') {
      $alias = ($account.Email -replace '^tecnico\.', '' -replace '@plus-lps\.test$', '').ToUpper()
      $lines += "SUPABASE_DEMO_TECNICO_${alias}_EMAIL=$($account.Email)"
    }
  }
  Set-Content -Path $OutFilePath -Value $lines -Encoding UTF8
  Write-Host "Credenciales locales escritas en: $OutFilePath" -ForegroundColor Green
  Write-Host 'La contraseña no se imprime aquí: léela desde ese archivo (ignorado por git).' -ForegroundColor DarkGray
} else {
  Write-Host 'No se escribió archivo de credenciales (-NoFile).' -ForegroundColor DarkGray
}

Write-Host ''
Write-Host 'Recuerda: el rol autorizado vive en public.profiles, no en el JWT ni en user_metadata.' -ForegroundColor Cyan
Write-Host 'El registro público debe seguir creando solo perfiles "tecnico" (sin selector de rol).' -ForegroundColor Cyan
