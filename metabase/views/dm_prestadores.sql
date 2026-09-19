-- =====================================================================
-- Prestador Nota 10 - Metabase
-- dm_prestadores.sql
--
-- Views usadas pelo Metabase para visualizar o datamart dm_prestadores.
-- =====================================================================

CREATE OR REPLACE VIEW dm_prestadores.vw_resumo_prestador_categoria AS
SELECT *
FROM dm_prestadores.resumo_prestador_categoria
ORDER BY qtd_prestadores DESC;
COMMENT ON VIEW dm_prestadores.vw_resumo_prestador_categoria IS 'Prestadores e precificação por categoria de serviço: quantidade e faixa de valores cobrados';

CREATE OR REPLACE VIEW dm_prestadores.vw_resumo_prestador_regiao AS
SELECT *
FROM dm_prestadores.resumo_prestador_regiao
ORDER BY qtd_prestadores DESC;
COMMENT ON VIEW dm_prestadores.vw_resumo_prestador_regiao IS 'Prestadores por região geográfica: quantidade e nota média';
