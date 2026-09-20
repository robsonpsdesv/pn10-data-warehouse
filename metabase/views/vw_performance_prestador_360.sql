-- =====================================================================
-- Prestador Nota 10 - Metabase
-- vw_performance_prestador_360.sql
--
-- View Analítica de Performance 360 dos Prestadores.
-- Consolida orçamentos, taxa de conversão, faturamento, agendamentos,
-- pontualidade e satisfação do cliente por prestador.
-- =====================================================================

CREATE OR REPLACE VIEW dm_prestadores.vw_performance_prestador_360 AS
SELECT
    dp.sk_prestador,
    dp.codigo_prestador,
    dp.nome AS nome_prestador,
    dp.tipo_pessoa,
    c.nome_cidade,
    c.uf,
    c.regiao,
    pl.descricao AS plano_atual,
    pl.valor_mensalidade AS mensalidade_plano,
    
    -- Métricas de Orçamentos e Conversão
    COUNT(DISTINCT fo.sk_orcamento) AS total_orcamentos_enviados,
    COUNT(DISTINCT CASE WHEN fo.foi_selecionado = true THEN fo.sk_orcamento END) AS orcamentos_ganhos,
    ROUND(
        COUNT(DISTINCT CASE WHEN fo.foi_selecionado = true THEN fo.sk_orcamento END)::numeric / 
        NULLIF(COUNT(DISTINCT fo.sk_orcamento), 0) * 100, 2
    ) AS taxa_conversao_pct,
    
    -- Métricas Financeiras
    ROUND(AVG(fo.valor), 2) AS ticket_medio_proposto,
    COALESCE(SUM(CASE WHEN fo.foi_selecionado = true THEN fo.valor ELSE 0 END), 0) AS faturamento_total_estimado,
    
    -- Métricas de Agendamento e Execução
    COUNT(DISTINCT fa.sk_agendamento) AS total_atendimentos_agendados,
    COUNT(DISTINCT CASE WHEN fa.reagendado = true THEN fa.sk_agendamento END) AS total_reagendamentos,
    ROUND(
        COUNT(DISTINCT CASE WHEN fa.reagendado = true THEN fa.sk_agendamento END)::numeric / 
        NULLIF(COUNT(DISTINCT fa.sk_agendamento), 0) * 100, 2
    ) AS taxa_reagendamento_pct,
    ROUND(AVG(fa.duracao_minutos), 1) AS duracao_media_atendimento_minutos,
    
    -- Métricas de Reputação e Satisfação
    COUNT(DISTINCT fav.sk_avaliacao) AS total_avaliacoes_recebidas,
    ROUND(AVG(fav.nota), 2) AS nota_media_avaliacoes,
    COUNT(DISTINCT CASE WHEN fav.nota >= 4.0 THEN fav.sk_avaliacao END) AS total_avaliacoes_positivas,
    COUNT(DISTINCT CASE WHEN fav.nota <= 2.0 THEN fav.sk_avaliacao END) AS total_avaliacoes_criticas

FROM dw.dim_prestador dp
JOIN dw.dim_cidade c ON dp.sk_cidade = c.sk_cidade
JOIN dw.dim_plano pl ON dp.sk_plano = pl.sk_plano
LEFT JOIN dw.fato_orcamento fo ON dp.sk_prestador = fo.sk_prestador
LEFT JOIN dw.fato_agendamento fa ON dp.sk_prestador = fa.sk_prestador
LEFT JOIN dw.fato_avaliacao fav ON dp.sk_prestador = fav.sk_prestador
GROUP BY 
    dp.sk_prestador,
    dp.codigo_prestador,
    dp.nome,
    dp.tipo_pessoa,
    c.nome_cidade,
    c.uf,
    c.regiao,
    pl.descricao,
    pl.valor_mensalidade;

COMMENT ON VIEW dm_prestadores.vw_performance_prestador_360 IS 'View Analítica de Performance 360 dos Prestadores (Conversão, Faturamento, Operação e Satisfação)';
