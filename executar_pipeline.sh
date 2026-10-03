#!/usr/bin/env bash
# =====================================================================
# Prestador Nota 10 - Orquestrador do Pipeline (Bash)
# executar_pipeline.sh
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
# Uso: ./executar_pipeline.sh
# =====================================================================

set -euo pipefail

PGHOST="${PGHOST:-localhost}"
PGPORT="${PGPORT:-5433}"
PGUSER="${PGUSER:-postgres}"
PGPASSWORD="${PGPASSWORD:-postgres}"
PGDATABASE="${PGDATABASE:-prestadornota10local}"

export PGHOST PGPORT PGUSER PGPASSWORD PGDATABASE

exec_sql() {
    local file="$1"
    local etapa="$2"
    echo "---------------------------------------------------------"
    echo "[$etapa] Executando: $file"
    psql -v ON_ERROR_STOP=1 -f "$file"
    echo "[$etapa Concluído]"
}

echo "========================================================="
echo "   PIPELINE DATA WAREHOUSE — PRESTADOR NOTA 10"
echo "========================================================="

# 1. Camada OLTP
exec_sql "dw/01_oltp_ddl.sql" "1/9 - OLTP DDL"
exec_sql "dw/02_oltp_carga.sql" "2/9 - OLTP Carga"

# 2. Camada DW (Dimensões + Fatos)
exec_sql "dw/03_dw_ddl.sql" "3/9 - DW DDL"
exec_sql "dw/04_dw_carga.sql" "4/9 - DW Carga"

# 3. Camada Datamarts
exec_sql "dw/05_datamart_ddl.sql" "5/9 - Datamart DDL"
exec_sql "dw/06_datamart_carga.sql" "6/9 - Datamart Carga"

# 4. Otimização e Qualidade
exec_sql "dw/07_indices_dw.sql" "7/9 - Índices de Performance"
exec_sql "dw/08_data_quality_tests.sql" "8/9 - Testes de Qualidade de Dados"

# 5. Views do Metabase
echo "---------------------------------------------------------"
echo "[9/9 - Views Metabase] Criando catálogo de views analíticas..."
for v in metabase/views/*.sql; do
    exec_sql "$v" "View $(basename "$v")"
done

echo ""
echo "========================================================="
echo " SUCESSO: Pipeline executado e validado com sucesso!"
echo "========================================================="
