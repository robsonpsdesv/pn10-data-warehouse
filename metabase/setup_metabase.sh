#!/usr/bin/env bash
# Configura o Metabase recém-criado via API REST:
#   1) Cria o usuário administrador inicial (setup wizard automatizado)
#   2) Registra a base "prestadornota10local" (schemas dw/dm_*) como fonte de dados
#
# Uso: ./setup_metabase.sh
# Variáveis de ambiente aceitas (com valores padrão):
#   MB_URL, MB_ADMIN_EMAIL, MB_ADMIN_PASSWORD, MB_ADMIN_FIRST_NAME, MB_ADMIN_LAST_NAME
#   PG_HOST, PG_PORT, PG_DBNAME, PG_USER, PG_PASSWORD

set -euo pipefail

MB_URL="${MB_URL:-http://localhost:3000}"
MB_ADMIN_EMAIL="${MB_ADMIN_EMAIL:-admin@pn10.local}"
MB_ADMIN_PASSWORD="${MB_ADMIN_PASSWORD:-Pn10Metabase!2026}"
MB_ADMIN_FIRST_NAME="${MB_ADMIN_FIRST_NAME:-Admin}"
MB_ADMIN_LAST_NAME="${MB_ADMIN_LAST_NAME:-PN10}"

# Dentro da rede docker `api_default`, o Postgres responde pelo alias "postgres" na porta 5432
PG_HOST="${PG_HOST:-postgres}"
PG_PORT="${PG_PORT:-5432}"
PG_DBNAME="${PG_DBNAME:-prestadornota10local}"
PG_USER="${PG_USER:-postgres}"
PG_PASSWORD="${PG_PASSWORD:-postgres}"

echo ">>> Aguardando Metabase responder em $MB_URL ..."
for i in $(seq 1 60); do
    if curl -sf "$MB_URL/api/health" >/dev/null 2>&1; then
        break
    fi
    sleep 2
done

SETUP_TOKEN=$(curl -sf "$MB_URL/api/session/properties" | jq -r '.["setup-token"]')

if [ "$SETUP_TOKEN" != "null" ] && [ -n "$SETUP_TOKEN" ]; then
    echo ">>> Setup ainda não concluído. Criando usuário administrador..."
    SESSION_ID=$(curl -sf -X POST "$MB_URL/api/setup" \
        -H "Content-Type: application/json" \
        -d @- <<EOF | jq -r '.id'
{
  "token": "$SETUP_TOKEN",
  "user": {
    "first_name": "$MB_ADMIN_FIRST_NAME",
    "last_name": "$MB_ADMIN_LAST_NAME",
    "email": "$MB_ADMIN_EMAIL",
    "password": "$MB_ADMIN_PASSWORD"
  },
  "prefs": {
    "site_name": "Prestador Nota 10 - Analytics",
    "site_locale": "pt-BR",
    "allow_tracking": false
  }
}
EOF
)
else
    echo ">>> Setup já concluído anteriormente. Autenticando..."
    SESSION_ID=$(curl -sf -X POST "$MB_URL/api/session" \
        -H "Content-Type: application/json" \
        -d "{\"username\": \"$MB_ADMIN_EMAIL\", \"password\": \"$MB_ADMIN_PASSWORD\"}" | jq -r '.id')
fi

if [ -z "$SESSION_ID" ] || [ "$SESSION_ID" = "null" ]; then
    echo "!!! Não foi possível obter uma sessão administrativa do Metabase." >&2
    exit 1
fi
echo ">>> Sessão administrativa obtida."

EXISTING_DB=$(curl -sf "$MB_URL/api/database" -H "X-Metabase-Session: $SESSION_ID" \
    | jq -r '.data[]? // .[]? | select(.name=="Prestador Nota 10") | .id' 2>/dev/null || true)

if [ -n "$EXISTING_DB" ]; then
    echo ">>> Base de dados 'Prestador Nota 10' já cadastrada no Metabase (id=$EXISTING_DB)."
else
    echo ">>> Cadastrando a base de dados 'Prestador Nota 10' (schemas dw/dm_*) no Metabase..."
    curl -sf -X POST "$MB_URL/api/database" \
        -H "Content-Type: application/json" \
        -H "X-Metabase-Session: $SESSION_ID" \
        -d @- <<EOF
{
  "engine": "postgres",
  "name": "Prestador Nota 10",
  "details": {
    "host": "$PG_HOST",
    "port": $PG_PORT,
    "dbname": "$PG_DBNAME",
    "user": "$PG_USER",
    "password": "$PG_PASSWORD",
    "ssl": false,
    "tunnel-enabled": false
  },
  "is_full_sync": true
}
EOF
    echo ""
    echo ">>> Base de dados cadastrada. O Metabase iniciará a sincronização do schema em segundo plano."
fi

echo ""
echo ">>> Metabase disponível em: $MB_URL"
echo ">>> Login: $MB_ADMIN_EMAIL / $MB_ADMIN_PASSWORD"
