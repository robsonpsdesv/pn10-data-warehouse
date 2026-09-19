-- =====================================================================
-- Prestador Nota 10 - Metabase
-- dm_planos.sql
--
-- Views usadas pelo Metabase para visualizar o datamart dm_planos.
-- =====================================================================

CREATE OR REPLACE VIEW dm_planos.vw_resumo_plano AS
SELECT *
FROM dm_planos.resumo_plano
ORDER BY qtd_prestadores DESC;
COMMENT ON VIEW dm_planos.vw_resumo_plano IS 'Assinaturas por plano comercial: prestadores, receita mensal estimada e nota média';
