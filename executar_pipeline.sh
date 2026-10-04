#!/usr/bin/env bash
# =====================================================================
# Prestador Nota 10 - Orquestrador do Pipeline (Bash)
# executar_pipeline.sh
#
# Executa de ponta a ponta todos os scripts SQL e de mineração do projeto:
# 1. 01_oltp_ddl.sql (DDL OLTP no schema pn10)
# 2. 02_oltp_carga.sql (Carga sintética no schema pn10)
# 3. 03_dw_ddl.sql (DDL do Data Warehouse no schema dw)
# 4. 04_dw_carga.sql (Carga dimensional do DW)
# 5. 05_datamart_ddl.sql (DDL dos 6 Datamarts)
# 6. 06_datamart_carga.sql (ETL de rollups/agregações nos Datamarts)
# 7. 07_indices_dw.sql (Criação de índices analíticos de alta performance)
# 8. 08_data_quality_tests.sql (Testes automatizados de qualidade de dados)
# 9. 09_segmentacao_clientes_ddl.sql (tabela destino da clusterização de clientes)
# 10. Views do Metabase (dm_*.sql + views avançadas)
# 11. Mineração Python (mining/): clusterização -> regras de associação por
#     segmento -> ensemble de classificadores (requer mining/.venv, ver
#     mining/requirements.txt; etapa pulada se o venv não existir)
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
exec_sql "dw/01_oltp_ddl.sql" "1/11 - OLTP DDL"
exec_sql "dw/02_oltp_carga.sql" "2/11 - OLTP Carga"

# 2. Camada DW (Dimensões + Fatos)
exec_sql "dw/03_dw_ddl.sql" "3/11 - DW DDL"
exec_sql "dw/04_dw_carga.sql" "4/11 - DW Carga"

# 3. Camada Datamarts
exec_sql "dw/05_datamart_ddl.sql" "5/11 - Datamart DDL"
exec_sql "dw/06_datamart_carga.sql" "6/11 - Datamart Carga"

# 4. Otimização e Qualidade
exec_sql "dw/07_indices_dw.sql" "7/11 - Índices de Performance"
exec_sql "dw/08_data_quality_tests.sql" "8/11 - Testes de Qualidade de Dados"
exec_sql "dw/09_segmentacao_clientes_ddl.sql" "9/11 - Tabela de Segmentação de Clientes"

# 5. Views do Metabase
echo "---------------------------------------------------------"
echo "[10/11 - Views Metabase] Criando catálogo de views analíticas..."
for v in metabase/views/*.sql; do
    exec_sql "$v" "View $(basename "$v")"
done

# 6. Mineração (Ensemble: Clusterização + Regras de Associação + Classificadores)
echo "---------------------------------------------------------"
echo "[11/11 - Mineração Python] clusterização -> regras de associação -> ensemble"
if [ -f "mining/.venv/bin/activate" ]; then
    (
        source mining/.venv/bin/activate
        python3 mining/clusterizacao/segmentar_clientes.py
        python3 mining/associacao/regras_associacao.py
        python3 mining/ensemble/treinar_ensemble.py
    )
else
    echo "[AVISO] mining/.venv não encontrado - pulei a etapa de mineração."
    echo "        Crie com: python3 -m venv mining/.venv && source mining/.venv/bin/activate && pip install -r mining/requirements.txt"
fi

echo ""
echo "========================================================="
echo " SUCESSO: Pipeline executado e validado com sucesso!"
echo "========================================================="
