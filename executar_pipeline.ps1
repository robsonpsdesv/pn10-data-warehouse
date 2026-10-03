# =====================================================================
# Prestador Nota 10 - Orquestrador do Pipeline (PowerShell)
# executar_pipeline.ps1
#
# Executa de ponta a ponta todos os scripts SQL do projeto:
# 1. 01_oltp_ddl.sql (DDL OLTP no schema pn10)
# 2. 02_oltp_carga.sql (Carga sintética no schema pn10)
# 3. 03_dw_ddl.sql (DDL do Data Warehouse no schema dw)
# 4. 04_dw_carga.sql (Carga dimensional do DW)
# 5. 05_datamart_ddl.sql (DDL dos 6 Datamarts)
# 6. 06_datamart_carga.sql (ETL de rollups/agregações nos Datamarts)
# 7. 07_indices_dw.sql (Criação de índices analíticos de alta performance)
# 8. 08_data_quality_tests.sql (Testes automatizados de qualidade de dados)
# 9. Views do Metabase (dm_*.sql + views avançadas)
#
# Uso: .\executar_pipeline.ps1
# =====================================================================

param(
    [string]$HostName = "localhost",
    [int]$Port = 5433,
    [string]$Database = "prestadornota10local",
    [string]$User = "postgres",
    [string]$Password = "postgres"
)

$env:PGPASSWORD = $Password

function Executar-Sql([string]$caminhoRelativo, [string]$etapa) {
    Write-Host "---------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "[$etapa] Executando: $caminhoRelativo" -ForegroundColor Cyan
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    
    $psqlCmd = "psql -h $HostName -p $Port -U $User -d $Database -v ON_ERROR_STOP=1 -f `"$caminhoRelativo`""
    Invoke-Expression $psqlCmd
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "!!! Falha na execução do script: $caminhoRelativo (Código de saída: $LASTEXITCODE)"
        exit $LASTEXITCODE
    }
    $sw.Stop()
    Write-Host "[$etapa Concluído] Tempo: $($sw.Elapsed.TotalSeconds.ToString('F2'))s" -ForegroundColor Green
}

Write-Host "=========================================================" -ForegroundColor White
Write-Host "   PIPELINE DATA WAREHOUSE — PRESTADOR NOTA 10" -ForegroundColor White
Write-Host "=========================================================" -ForegroundColor White

$baseDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# 1. Camada OLTP
Executar-Sql "$baseDir\dw\01_oltp_ddl.sql" "1/9 - OLTP DDL"
Executar-Sql "$baseDir\dw\02_oltp_carga.sql" "2/9 - OLTP Carga"

# 2. Camada DW (Dimensões + Fatos)
Executar-Sql "$baseDir\dw\03_dw_ddl.sql" "3/9 - DW DDL"
Executar-Sql "$baseDir\dw\04_dw_carga.sql" "4/9 - DW Carga"

# 3. Camada Datamarts
Executar-Sql "$baseDir\dw\05_datamart_ddl.sql" "5/9 - Datamart DDL"
Executar-Sql "$baseDir\dw\06_datamart_carga.sql" "6/9 - Datamart Carga"

# 4. Otimização e Qualidade
Executar-Sql "$baseDir\dw\07_indices_dw.sql" "7/9 - Índices de Performance"
Executar-Sql "$baseDir\dw\08_data_quality_tests.sql" "8/9 - Testes de Qualidade de Dados"

# 5. Views do Metabase
Write-Host "---------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "[9/9 - Views Metabase] Criando catálogo de views analíticas..." -ForegroundColor Cyan
$views = Get-ChildItem "$baseDir\metabase\views\*.sql"
foreach ($v in $views) {
    Executar-Sql $v.FullName "View $($v.Name)"
}

Write-Host ""
Write-Host "=========================================================" -ForegroundColor Green
Write-Host " SUCESSO: Pipeline executado e validado com sucesso!" -ForegroundColor Green
Write-Host "=========================================================" -ForegroundColor Green
