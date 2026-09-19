-- =====================================================================
-- Prestador Nota 10 - Metabase
-- dm_pedidos.sql
--
-- Views usadas pelo Metabase para visualizar o datamart dm_pedidos.
-- São passthroughs 1:1 sobre as tabelas de resumo (schema `dw` já contém
-- os fatos/dimensões; aqui só expomos os resumos com nomes/comentários
-- amigáveis para o catálogo de dados do Metabase).
-- =====================================================================

CREATE OR REPLACE VIEW dm_pedidos.vw_resumo_pedido_mes_categoria AS
SELECT *
FROM dm_pedidos.resumo_pedido_mes_categoria
ORDER BY ano, mes, categoria_servico;
COMMENT ON VIEW dm_pedidos.vw_resumo_pedido_mes_categoria IS 'Pedidos por mês, categoria de serviço e situação: quantidade, ticket médio, dias até finalização e nota média';

CREATE OR REPLACE VIEW dm_pedidos.vw_resumo_pedido_regiao AS
SELECT *
FROM dm_pedidos.resumo_pedido_regiao
ORDER BY qtd_pedidos DESC;
COMMENT ON VIEW dm_pedidos.vw_resumo_pedido_regiao IS 'Pedidos por região geográfica de atendimento: volume, ticket médio, taxa de cancelamento e nota média';
