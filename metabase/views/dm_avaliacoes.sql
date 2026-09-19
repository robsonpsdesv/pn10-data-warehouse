-- =====================================================================
-- Prestador Nota 10 - Metabase
-- dm_avaliacoes.sql
--
-- Views usadas pelo Metabase para visualizar o datamart dm_avaliacoes.
-- =====================================================================

CREATE OR REPLACE VIEW dm_avaliacoes.vw_resumo_avaliacao_categoria AS
SELECT *
FROM dm_avaliacoes.resumo_avaliacao_categoria
ORDER BY nota_media DESC;
COMMENT ON VIEW dm_avaliacoes.vw_resumo_avaliacao_categoria IS 'Avaliações por categoria de serviço: nota média e distribuição de notas 1-5';

CREATE OR REPLACE VIEW dm_avaliacoes.vw_resumo_avaliacao_prestador AS
SELECT *
FROM dm_avaliacoes.resumo_avaliacao_prestador
ORDER BY nota_media DESC;
COMMENT ON VIEW dm_avaliacoes.vw_resumo_avaliacao_prestador IS 'Avaliações por prestador: quantidade e nota média';
