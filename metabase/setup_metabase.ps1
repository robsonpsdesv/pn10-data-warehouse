# =====================================================================
# Prestador Nota 10 - Metabase Setup (PowerShell)
# setup_metabase.ps1
#
# Configura o Metabase recém-criado via API REST no Windows:
#   1) Cria o usuário administrador inicial (setup wizard automatizado)
#   2) Registra a base "prestadornota10local" (schemas dw/dm_*) como fonte de dados
#
# Uso: .\setup_metabase.ps1
# =====================================================================

$MB_URL = if ($env:MB_URL) { $env:MB_URL } else { "http://localhost:3000" }
$MB_ADMIN_EMAIL = if ($env:MB_ADMIN_EMAIL) { $env:MB_ADMIN_EMAIL } else { "admin@pn10.local" }
$MB_ADMIN_PASSWORD = if ($env:MB_ADMIN_PASSWORD) { $env:MB_ADMIN_PASSWORD } else { "Pn10Metabase!2026" }
$MB_ADMIN_FIRST_NAME = if ($env:MB_ADMIN_FIRST_NAME) { $env:MB_ADMIN_FIRST_NAME } else { "Admin" }
$MB_ADMIN_LAST_NAME = if ($env:MB_ADMIN_LAST_NAME) { $env:MB_ADMIN_LAST_NAME } else { "PN10" }

$PG_HOST = if ($env:PG_HOST) { $env:PG_HOST } else { "postgres" }
$PG_PORT = if ($env:PG_PORT) { [int]$env:PG_PORT } else { 5432 }
$PG_DBNAME = if ($env:PG_DBNAME) { $env:PG_DBNAME } else { "prestadornota10local" }
$PG_USER = if ($env:PG_USER) { $env:PG_USER } else { "postgres" }
$PG_PASSWORD = if ($env:PG_PASSWORD) { $env:PG_PASSWORD } else { "postgres" }

Write-Host ">>> Aguardando Metabase responder em $MB_URL ..." -ForegroundColor Cyan
$ready = $false
for ($i = 1; $i -le 60; $i++) {
    try {
        $res = Invoke-RestMethod -Uri "$MB_URL/api/health" -Method Get -TimeoutSec 3 -ErrorAction SilentlyContinue
        if ($res.status -eq "ok") {
            $ready = $true
            break
        }
    } catch {
        Start-Sleep -Seconds 2
    }
}

if (-not $ready) {
    Write-Error "!!! Metabase não respondeu a tempo em $MB_URL. Certifique-se de que o docker compose está em execução."
    exit 1
}

Write-Host ">>> Metabase online! Verificando estado do setup..." -ForegroundColor Green
$setupProps = Invoke-RestMethod -Uri "$MB_URL/api/session/properties" -Method Get
$setupToken = $setupProps."setup-token"

$sessionId = $null

if ($setupToken -and $setupToken -ne "null") {
    Write-Host ">>> Setup ainda não concluído. Criando usuário administrador..." -ForegroundColor Yellow
    $setupBody = @{
        token = $setupToken
        user = @{
            first_name = $MB_ADMIN_FIRST_NAME
            last_name  = $MB_ADMIN_LAST_NAME
            email      = $MB_ADMIN_EMAIL
            password   = $MB_ADMIN_PASSWORD
        }
        prefs = @{
            site_name      = "Prestador Nota 10 - Analytics"
            site_locale    = "pt-BR"
            allow_tracking = $false
        }
    } | ConvertTo-Json -Depth 5

    $setupRes = Invoke-RestMethod -Uri "$MB_URL/api/setup" -Method Post -Body $setupBody -ContentType "application/json"
    $sessionId = $setupRes.id
} else {
    Write-Host ">>> Setup já concluído anteriormente. Autenticando..." -ForegroundColor Yellow
    $loginBody = @{
        username = $MB_ADMIN_EMAIL
        password = $MB_ADMIN_PASSWORD
    } | ConvertTo-Json

    $loginRes = Invoke-RestMethod -Uri "$MB_URL/api/session" -Method Post -Body $loginBody -ContentType "application/json"
    $sessionId = $loginRes.id
}

if (-not $sessionId) {
    Write-Error "!!! Não foi possível obter uma sessão administrativa do Metabase."
    exit 1
}
Write-Host ">>> Sessão administrativa obtida com sucesso." -ForegroundColor Green

$headers = @{ "X-Metabase-Session" = $sessionId }
$dbList = Invoke-RestMethod -Uri "$MB_URL/api/database" -Method Get -Headers $headers
$existingDb = $dbList.data | Where-Object { $_.name -eq "Prestador Nota 10" }

if ($existingDb) {
    Write-Host ">>> Base de dados 'Prestador Nota 10' já cadastrada no Metabase (id=$($existingDb.id))." -ForegroundColor Green
} else {
    Write-Host ">>> Cadastrando a base de dados 'Prestador Nota 10' (schemas dw/dm_*) no Metabase..." -ForegroundColor Cyan
    $dbPayload = @{
        engine  = "postgres"
        name    = "Prestador Nota 10"
        details = @{
            host             = $PG_HOST
            port             = $PG_PORT
            dbname           = $PG_DBNAME
            user             = $PG_USER
            password         = $PG_PASSWORD
            ssl              = $false
            "tunnel-enabled" = $false
        }
        is_full_sync = $true
    } | ConvertTo-Json -Depth 5

    $newDb = Invoke-RestMethod -Uri "$MB_URL/api/database" -Method Post -Body $dbPayload -ContentType "application/json" -Headers $headers
    Write-Host ">>> Base de dados cadastrada com sucesso! O Metabase sincronizará o schema." -ForegroundColor Green
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host ">>> Metabase disponível em: $MB_URL" -ForegroundColor White
Write-Host ">>> Login: $MB_ADMIN_EMAIL" -ForegroundColor White
Write-Host ">>> Senha: $MB_ADMIN_PASSWORD" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Green
