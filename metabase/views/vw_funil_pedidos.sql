-- =====================================================================
-- Prestador Nota 10 - Metabase
-- vw_funil_pedidos.sql
--
-- View Analítica de Funil de Conversão e Ciclo de Vida dos Pedidos.
-- Permite acompanhar a taxa de conversão em cada fase do marketplace:
-- Abertos -> Com Orçamento -> Orçamento Aceito -> Agendados -> Finalizados -> Avaliados.
-- =====================================================================

CREATE OR REPLACE VIEW dm_pedidos.vw_funil_pedidos AS
SELECT
    t.ano,
    t.mes,
    t.nome_mes,
    c.regiao,
    cat.descricao AS categoria_servico,
    COUNT(fp.sk_pedido) AS total_pedidos_criados,
    COUNT(CASE WHEN fp.qtd_orcamentos_recebidos > 0 THEN 1 END) AS pedidos_com_orcamento,
    COUNT(CASE WHEN fp.sk_prestador IS NOT NULL THEN 1 END) AS pedidos_com_prestador_escolhido,
    COUNT(fa.sk_agendamento) AS pedidos_agendados,
    COUNT(CASE WHEN fp.sk_tempo_finalizacao IS NOT NULL AND fp.indicador_cancelado = false THEN 1 END) AS pedidos_finalizados_sucesso,
    COUNT(CASE WHEN fp.indicador_cancelado = true THEN 1 END) AS pedidos_cancelados,
    COUNT(fav.sk_avaliacao) AS pedidos_avaliados,
    
    -- Taxas de Conversão do Funil
    ROUND(
        COUNT(CASE WHEN fp.qtd_orcamentos_recebidos > 0 THEN 1 END)::numeric / 
        NULLIF(COUNT(fp.sk_pedido), 0) * 100, 2
    ) AS pct_receberam_orcamento,

    ROUND(
        COUNT(CASE WHEN fp.sk_prestador IS NOT NULL THEN 1 END)::numeric / 
        NULLIF(COUNT(CASE WHEN fp.qtd_orcamentos_recebidos > 0 THEN 1 END), 0) * 100, 2
    ) AS pct_conversao_orcamento_para_escolha,

    ROUND(
        COUNT(CASE WHEN fp.sk_tempo_finalizacao IS NOT NULL AND fp.indicador_cancelado = false THEN 1 END)::numeric / 
        NULLIF(COUNT(fp.sk_pedido), 0) * 100, 2
    ) AS pct_taxa_sucesso_geral,

    ROUND(
        COUNT(CASE WHEN fp.indicador_cancelado = true THEN 1 END)::numeric / 
        NULLIF(COUNT(fp.sk_pedido), 0) * 100, 2
    ) AS pct_taxa_cancelamento,

    ROUND(AVG(fp.valor_orcamento_selecionado), 2) AS ticket_medio_selecionado,
    ROUND(AVG(fav.nota), 2) AS nota_media_satisfacao

FROM dw.fato_pedido fp
JOIN dw.dim_tempo t ON fp.sk_tempo_abertura = t.sk_tempo
JOIN dw.dim_cidade c ON fp.sk_cidade = c.sk_cidade
JOIN dw.dim_categoria_servico cat ON fp.sk_categoria_servico = cat.sk_categoria_servico
LEFT JOIN dw.fato_agendamento fa ON fp.sk_pedido = fa.sk_pedido
LEFT JOIN dw.fato_avaliacao fav ON fp.sk_pedido = fav.sk_pedido
GROUP BY t.ano, t.mes, t.nome_mes, c.regiao, cat.descricao;

COMMENT ON VIEW dm_pedidos.vw_funil_pedidos IS 'View Analítica de Funil de Conversão e Desempenho Operacional dos Pedidos';
