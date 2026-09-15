#!/usr/bin/env bash
# Executa, em ordem, todos os scripts de criação e carga do Data Warehouse
# Prestador Nota 10 no banco informado.
#
# Uso: ./run_all.sh
# Variáveis de ambiente aceitas (com valores padrão do ambiente local):
#   PGHOST=localhost PGPORT=5433 PGUSER=postgres PGPASSWORD=postgres PGDATABASE=prestadornota10local

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export PGHOST="${PGHOST:-localhost}"
export PGPORT="${PGPORT:-5433}"
export PGUSER="${PGUSER:-postgres}"
export PGPASSWORD="${PGPASSWORD:-postgres}"
export PGDATABASE="${PGDATABASE:-prestadornota10local}"

SCRIPTS=(
    "00_criar_schemas.sql"
    "01_dimensoes_conformadas.sql"
    "02_dim_cliente_prestador.sql"
    "03_fato_pedido_orcamento_historico.sql"
    "04_fato_avaliacao_agendamento.sql"
    "05_fato_prestadores_planos.sql"
    "06_views_analiticas.sql"
    "07_popular_oltp_sincronizado.sql"
)

for script in "${SCRIPTS[@]}"; do
    echo ">>> Executando $script"
    psql -v ON_ERROR_STOP=1 -f "$DIR/$script"
done

echo ">>> DW criado e populado com sucesso (e OLTP sincronizado em public.*)."
