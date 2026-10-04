-- =====================================================================
-- Prestador Nota 10 - Metabase
-- vw_segmentacao_clientes.sql
--
-- Views para visualizar o resultado da clusterização de clientes
-- (dw.dim_cliente_segmento, populada por mining/clusterizacao/segmentar_clientes.py)
-- e cruzá-la com as regras de associação mineradas por segmento
-- (ver mining/RELATORIO_TECNICO.md).
-- =====================================================================

-- Detalhe: 1 linha por cliente, com o segmento/cluster atribuído.
CREATE OR REPLACE VIEW dw.vw_segmentacao_clientes AS
SELECT
    seg.sk_cliente,
    c.codigo_cliente,
    c.nome,
    c.tipo_pessoa,
    cid.nome_cidade,
    cid.uf,
    cid.regiao,
    seg.cluster,
    seg.rotulo_segmento,
    seg.qtd_pedidos,
    seg.valor_total,
    seg.valor_medio_pedido,
    seg.qtd_categorias_distintas,
    seg.taxa_cancelamento,
    seg.nota_media,
    seg.recencia_dias,
    seg.data_execucao
FROM dw.dim_cliente_segmento seg
JOIN dw.dim_cliente c ON c.sk_cliente = seg.sk_cliente
JOIN dw.dim_cidade cid ON cid.sk_cidade = c.sk_cidade
ORDER BY seg.cluster, seg.valor_total DESC;
COMMENT ON VIEW dw.vw_segmentacao_clientes IS 'Clusterização de clientes (K-Means) com perfil RFM — 1 linha por cliente segmentado. Populada por mining/clusterizacao/segmentar_clientes.py.';

-- Resumo: perfil médio de cada cluster/segmento (para cards/dashboard).
CREATE OR REPLACE VIEW dw.vw_resumo_segmento_cliente AS
SELECT
    cluster,
    rotulo_segmento,
    COUNT(*) AS qtd_clientes,
    ROUND(AVG(qtd_pedidos), 2) AS media_qtd_pedidos,
    ROUND(AVG(valor_total), 2) AS media_valor_total,
    ROUND(AVG(valor_medio_pedido), 2) AS media_ticket_medio,
    ROUND(AVG(qtd_categorias_distintas), 2) AS media_categorias_distintas,
    ROUND(AVG(taxa_cancelamento) * 100, 2) AS taxa_cancelamento_pct,
    ROUND(AVG(nota_media), 2) AS nota_media,
    ROUND(AVG(recencia_dias), 0) AS media_recencia_dias
FROM dw.dim_cliente_segmento
GROUP BY cluster, rotulo_segmento
ORDER BY cluster;
COMMENT ON VIEW dw.vw_resumo_segmento_cliente IS 'Perfil médio (RFM + satisfação/cancelamento) de cada segmento de cliente gerado pelo K-Means.';
