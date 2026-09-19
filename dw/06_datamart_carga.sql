-- =====================================================================
-- Prestador Nota 10 - Data Warehouse
-- 06_datamart_carga.sql
--
-- PASSO 3 (Datamart) - Etapa 2/2: carga (ETL de agregação a partir do DW).
--
-- Cada INSERT abaixo é um resumo (GROUP BY) construído diretamente das
-- tabelas fato/dimensão do schema `dw`. Nenhuma tabela de datamart aqui
-- guarda o grão fino do fato — todas são agregações prontas para consumo.
--
-- Pré-requisito: 05_datamart_ddl.sql + 04_dw_carga.sql já executados.
-- =====================================================================

-- ---------------------------------------------------------------------
-- dm_pedidos.resumo_pedido_mes_categoria
-- ---------------------------------------------------------------------
INSERT INTO dm_pedidos.resumo_pedido_mes_categoria (
    ano, mes, sk_categoria_servico, categoria_servico, categoria_pai,
    sk_situacao_pedido, situacao, qtd_pedidos, valor_medio_orcamento,
    dias_medio_finalizacao, qtd_avaliados, nota_media
)
SELECT
    dt.ano, dt.mes,
    cat.sk_categoria_servico, cat.descricao, cat.descricao_categoria_pai,
    sit.sk_situacao_pedido, sit.situacao,
    count(*) AS qtd_pedidos,
    round(avg(fp.valor_orcamento_selecionado)::numeric, 2) AS valor_medio_orcamento,
    round(avg(fp.dias_para_finalizacao)::numeric, 1) AS dias_medio_finalizacao,
    count(*) FILTER (WHERE fp.indicador_avaliado) AS qtd_avaliados,
    round(avg(fp.nota_avaliacao)::numeric, 2) AS nota_media
FROM dw.fato_pedido fp
JOIN dw.dim_tempo dt              ON dt.sk_tempo = fp.sk_tempo_abertura
JOIN dw.dim_categoria_servico cat ON cat.sk_categoria_servico = fp.sk_categoria_servico
JOIN dw.dim_situacao_pedido sit   ON sit.sk_situacao_pedido = fp.sk_situacao_pedido
GROUP BY dt.ano, dt.mes, cat.sk_categoria_servico, cat.descricao, cat.descricao_categoria_pai,
         sit.sk_situacao_pedido, sit.situacao;

-- ---------------------------------------------------------------------
-- dm_pedidos.resumo_pedido_regiao
-- ---------------------------------------------------------------------
INSERT INTO dm_pedidos.resumo_pedido_regiao (
    regiao, qtd_pedidos, ticket_medio, taxa_cancelamento, nota_media, dias_medio_finalizacao
)
SELECT
    cid.regiao,
    count(*) AS qtd_pedidos,
    round(avg(fp.valor_orcamento_selecionado)::numeric, 2) AS ticket_medio,
    round(100.0 * count(*) FILTER (WHERE fp.indicador_cancelado) / count(*), 2) AS taxa_cancelamento,
    round(avg(fp.nota_avaliacao)::numeric, 2) AS nota_media,
    round(avg(fp.dias_para_finalizacao)::numeric, 1) AS dias_medio_finalizacao
FROM dw.fato_pedido fp
JOIN dw.dim_cidade cid ON cid.sk_cidade = fp.sk_cidade
GROUP BY cid.regiao;

-- ---------------------------------------------------------------------
-- dm_orcamentos.resumo_orcamento_prestador
-- (somente prestadores que já receberam ao menos 1 solicitação de orçamento)
-- ---------------------------------------------------------------------
INSERT INTO dm_orcamentos.resumo_orcamento_prestador (
    sk_prestador, prestador, plano, qtd_orcamentos_enviados, qtd_selecionados,
    taxa_conversao, valor_medio, valor_medio_selecionado
)
SELECT
    pr.sk_prestador, pr.nome, pl.descricao,
    count(*) AS qtd_orcamentos_enviados,
    count(*) FILTER (WHERE fo.foi_selecionado) AS qtd_selecionados,
    round(100.0 * count(*) FILTER (WHERE fo.foi_selecionado) / count(*), 2) AS taxa_conversao,
    round(avg(fo.valor)::numeric, 2) AS valor_medio,
    round(avg(fo.valor) FILTER (WHERE fo.foi_selecionado)::numeric, 2) AS valor_medio_selecionado
FROM dw.fato_orcamento fo
JOIN dw.dim_prestador pr ON pr.sk_prestador = fo.sk_prestador
JOIN dw.dim_plano pl     ON pl.sk_plano = pr.sk_plano
GROUP BY pr.sk_prestador, pr.nome, pl.descricao;

-- ---------------------------------------------------------------------
-- dm_orcamentos.resumo_orcamento_categoria
-- ---------------------------------------------------------------------
INSERT INTO dm_orcamentos.resumo_orcamento_categoria (
    sk_categoria_servico, categoria_servico, qtd_orcamentos, valor_medio, taxa_selecao
)
SELECT
    cat.sk_categoria_servico, cat.descricao,
    count(*) AS qtd_orcamentos,
    round(avg(fo.valor)::numeric, 2) AS valor_medio,
    round(100.0 * count(*) FILTER (WHERE fo.foi_selecionado) / count(*), 2) AS taxa_selecao
FROM dw.fato_orcamento fo
JOIN dw.dim_categoria_servico cat ON cat.sk_categoria_servico = fo.sk_categoria_servico
GROUP BY cat.sk_categoria_servico, cat.descricao;

-- ---------------------------------------------------------------------
-- dm_avaliacoes.resumo_avaliacao_categoria
-- ---------------------------------------------------------------------
INSERT INTO dm_avaliacoes.resumo_avaliacao_categoria (
    sk_categoria_servico, categoria_servico, qtd_avaliacoes, nota_media,
    qtd_nota_1, qtd_nota_2, qtd_nota_3, qtd_nota_4, qtd_nota_5, pct_nota_acima_media
)
SELECT
    cat.sk_categoria_servico, cat.descricao,
    count(*) AS qtd_avaliacoes,
    round(avg(fa.nota)::numeric, 2) AS nota_media,
    count(*) FILTER (WHERE fa.nota = 1) AS qtd_nota_1,
    count(*) FILTER (WHERE fa.nota = 2) AS qtd_nota_2,
    count(*) FILTER (WHERE fa.nota = 3) AS qtd_nota_3,
    count(*) FILTER (WHERE fa.nota = 4) AS qtd_nota_4,
    count(*) FILTER (WHERE fa.nota = 5) AS qtd_nota_5,
    round(100.0 * count(*) FILTER (WHERE fa.nota_acima_media) / count(*), 2) AS pct_nota_acima_media
FROM dw.fato_avaliacao fa
JOIN dw.dim_categoria_servico cat ON cat.sk_categoria_servico = fa.sk_categoria_servico
GROUP BY cat.sk_categoria_servico, cat.descricao;

-- ---------------------------------------------------------------------
-- dm_avaliacoes.resumo_avaliacao_prestador
-- ---------------------------------------------------------------------
INSERT INTO dm_avaliacoes.resumo_avaliacao_prestador (
    sk_prestador, prestador, qtd_avaliacoes, nota_media
)
SELECT
    pr.sk_prestador, pr.nome,
    count(*) AS qtd_avaliacoes,
    round(avg(fa.nota)::numeric, 2) AS nota_media
FROM dw.fato_avaliacao fa
JOIN dw.dim_prestador pr ON pr.sk_prestador = fa.sk_prestador
GROUP BY pr.sk_prestador, pr.nome;

-- ---------------------------------------------------------------------
-- dm_agendamentos.resumo_agendamento_mes
-- ---------------------------------------------------------------------
INSERT INTO dm_agendamentos.resumo_agendamento_mes (
    ano, mes, qtd_agendamentos, duracao_media_minutos, taxa_reagendamento, dias_antecedencia_media
)
SELECT
    dt.ano, dt.mes,
    count(*) AS qtd_agendamentos,
    round(avg(fg.duracao_minutos)::numeric, 1) AS duracao_media_minutos,
    round(100.0 * count(*) FILTER (WHERE fg.reagendado) / count(*), 2) AS taxa_reagendamento,
    round(avg(fg.dias_antecedencia)::numeric, 1) AS dias_antecedencia_media
FROM dw.fato_agendamento fg
JOIN dw.dim_tempo dt ON dt.sk_tempo = fg.sk_tempo_inicio
GROUP BY dt.ano, dt.mes;

-- ---------------------------------------------------------------------
-- dm_agendamentos.resumo_agendamento_prestador
-- ---------------------------------------------------------------------
INSERT INTO dm_agendamentos.resumo_agendamento_prestador (
    sk_prestador, prestador, qtd_agendamentos, duracao_media_minutos, taxa_reagendamento
)
SELECT
    pr.sk_prestador, pr.nome,
    count(*) AS qtd_agendamentos,
    round(avg(fg.duracao_minutos)::numeric, 1) AS duracao_media_minutos,
    round(100.0 * count(*) FILTER (WHERE fg.reagendado) / count(*), 2) AS taxa_reagendamento
FROM dw.fato_agendamento fg
JOIN dw.dim_prestador pr ON pr.sk_prestador = fg.sk_prestador
GROUP BY pr.sk_prestador, pr.nome;

-- ---------------------------------------------------------------------
-- dm_prestadores.resumo_prestador_categoria
-- ---------------------------------------------------------------------
INSERT INTO dm_prestadores.resumo_prestador_categoria (
    sk_categoria_servico, categoria_servico, qtd_prestadores, valor_medio_cobrado, valor_min_cobrado, valor_max_cobrado
)
SELECT
    cat.sk_categoria_servico, cat.descricao,
    count(*) AS qtd_prestadores,
    round(avg(fpc.valor_medio_cobrado)::numeric, 2) AS valor_medio_cobrado,
    min(fpc.valor_medio_cobrado) AS valor_min_cobrado,
    max(fpc.valor_medio_cobrado) AS valor_max_cobrado
FROM dw.fato_precificacao_categoria fpc
JOIN dw.dim_categoria_servico cat ON cat.sk_categoria_servico = fpc.sk_categoria_servico
GROUP BY cat.sk_categoria_servico, cat.descricao;

-- ---------------------------------------------------------------------
-- dm_prestadores.resumo_prestador_regiao
-- ---------------------------------------------------------------------
INSERT INTO dm_prestadores.resumo_prestador_regiao (
    regiao, qtd_prestadores, nota_media
)
SELECT
    cid.regiao,
    count(*) AS qtd_prestadores,
    round(avg(pr.avaliacao_media)::numeric, 2) AS nota_media
FROM dw.dim_prestador pr
JOIN dw.dim_cidade cid ON cid.sk_cidade = pr.sk_cidade
GROUP BY cid.regiao;

-- ---------------------------------------------------------------------
-- dm_planos.resumo_plano
-- ---------------------------------------------------------------------
INSERT INTO dm_planos.resumo_plano (
    sk_plano, plano, qtd_prestadores, receita_mensal_estimada, nota_media_prestadores, qtd_pedidos_recebidos_mes_total
)
SELECT
    pl.sk_plano, pl.descricao,
    count(fap.sk_prestador) AS qtd_prestadores,
    round((count(fap.sk_prestador) * pl.valor_mensalidade)::numeric, 2) AS receita_mensal_estimada,
    round(avg(pr.avaliacao_media)::numeric, 2) AS nota_media_prestadores,
    COALESCE(sum(fap.qtd_pedidos_recebidos_mes_atual), 0) AS qtd_pedidos_recebidos_mes_total
FROM dw.dim_plano pl
LEFT JOIN dw.fato_assinatura_plano fap ON fap.sk_plano = pl.sk_plano
LEFT JOIN dw.dim_prestador pr           ON pr.sk_prestador = fap.sk_prestador
GROUP BY pl.sk_plano, pl.descricao, pl.valor_mensalidade;
