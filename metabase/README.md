# Metabase — Prestador Nota 10

Container do [Metabase](https://www.metabase.com/) para visualizar os 6
datamarts (`dm_pedidos`, `dm_orcamentos`, `dm_avaliacoes`, `dm_agendamentos`,
`dm_prestadores`, `dm_planos`) do banco `prestadornota10local`.

## Estrutura

| Arquivo/Diretório | Conteúdo |
|---|---|
| `docker-compose.yml` | Sobe o container `metabase_pn10` (porta `3000`), conectado à rede docker `api_default` onde já roda o Postgres do projeto (`postgres_pn10_local`) |
| `setup_metabase.sh` | Configura o Metabase via API REST: cria o usuário administrador e registra a base `prestadornota10local` como fonte de dados |
| `views/` | Um script SQL por datamart, com uma view `vw_resumo_*` para cada tabela de resumo (ver seção 4 do [README da raiz](../README.md)) |

## Pré-requisitos

- Docker rodando.
- Postgres do projeto já em execução (container `postgres_pn10_local`,
  `jdbc:postgresql://localhost:5433/prestadornota10local`) e com os schemas
  `dw`/`dm_*` já criados e populados (ver seção 4 do README da raiz).

## Como executar

```bash
cd metabase

# 1) Sobe o container
docker compose up -d

# 2) Cria as views que o Metabase vai visualizar
export PGPASSWORD=postgres
for f in views/*.sql; do psql -h localhost -p 5433 -U postgres -d prestadornota10local -v ON_ERROR_STOP=1 -f "$f"; done

# 3) Configura o Metabase (cria admin + registra a base de dados)
./setup_metabase.sh
```

Acesse **http://localhost:3000** e faça login com:

- **E-mail**: `admin@pn10.local`
- **Senha**: `Pn10Metabase!2026`

(Ajustável via as variáveis `MB_ADMIN_EMAIL`/`MB_ADMIN_PASSWORD` antes de
rodar `setup_metabase.sh`.)

A base de dados aparece no Metabase com o nome **"Prestador Nota 10"**,
com os schemas `dw` (dimensões e fatos) e `dm_pedidos`/`dm_orcamentos`/
`dm_avaliacoes`/`dm_agendamentos`/`dm_prestadores`/`dm_planos` (datamarts,
com as views `vw_resumo_*`) prontos para explorar em **Perguntas** e
**Dashboards**.

## Re-sincronizar o schema

Sempre que uma view/tabela nova for criada no Postgres, force o Metabase a
reconhecer as mudanças (Configurações → Governança de dados → *Prestador
Nota 10* → **Sincronizar esquema do banco de dados agora**), ou via API:

```bash
SESSION_ID=$(curl -sf -X POST http://localhost:3000/api/session \
  -H "Content-Type: application/json" \
  -d '{"username":"admin@pn10.local","password":"Pn10Metabase!2026"}' | jq -r '.id')
DB_ID=$(curl -sf http://localhost:3000/api/database -H "X-Metabase-Session: $SESSION_ID" \
  | jq -r '.data[] | select(.name=="Prestador Nota 10") | .id')
curl -sf -X POST "http://localhost:3000/api/database/$DB_ID/sync_schema" -H "X-Metabase-Session: $SESSION_ID"
```
