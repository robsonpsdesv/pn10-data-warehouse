-- =====================================================================
-- Prestador Nota 10 - Metabase
-- dm_orcamentos.sql
--
-- Views usadas pelo Metabase para visualizar o datamart dm_orcamentos.
-- =====================================================================

CREATE OR REPLACE VIEW dm_orcamentos.vw_resumo_orcamento_prestador AS
SELECT *
FROM dm_orcamentos.resumo_orcamento_prestador
ORDER BY taxa_conversao DESC;
COMMENT ON VIEW dm_orcamentos.vw_resumo_orcamento_prestador IS 'Orçamentos enviados por prestador: volume, taxa de conversão e valores médios';

CREATE OR REPLACE VIEW dm_orcamentos.vw_resumo_orcamento_categoria AS
SELECT *
FROM dm_orcamentos.resumo_orcamento_categoria
ORDER BY qtd_orcamentos DESC;
COMMENT ON VIEW dm_orcamentos.vw_resumo_orcamento_categoria IS 'Orçamentos por categoria de serviço: volume, valor médio e taxa de seleção';
