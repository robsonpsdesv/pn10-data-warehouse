-- =====================================================================
-- Prestador Nota 10 - Data Warehouse
-- 06_views_analiticas.sql
--
-- Views de conveniência que já resolvem os joins entre fato e dimensões
-- de cada datamart, facilitando consultas analíticas/BI ad-hoc.
-- =====================================================================

CREATE OR REPLACE VIEW dm_pedidos.vw_pedido AS
SELECT
    fp.sk_pedido,
    fp.codigo_pedido,
    dt_ab.data                    AS data_abertura,
    dt_ab.ano                     AS ano_abertura,
    dt_ab.mes                     AS mes_abertura,
    dt_fin.data                   AS data_finalizacao,
    c.nome                        AS cliente,
    c.tipo_pessoa                 AS cliente_tipo_pessoa,
    pr.nome                       AS prestador,
    cid.nome_cidade,
    cid.uf,
    cid.regiao,
    cat.descricao                 AS categoria_servico,
    cat.descricao_categoria_pai   AS categoria_pai,
    sit.situacao,
    sit.descricao                 AS situacao_descricao,
    fpg.forma                     AS forma_pagamento,
    fp.qtd_categorias_servico,
    fp.qtd_orcamentos_recebidos,
    fp.valor_orcamento_selecionado,
    fp.dias_para_primeiro_orcamento,
    fp.dias_para_agendamento,
    fp.dias_para_finalizacao,
    fp.indicador_cancelado,
    fp.indicador_avaliado,
    fp.nota_avaliacao
FROM dm_pedidos.fato_pedido fp
JOIN dw.dim_tempo dt_ab              ON dt_ab.sk_tempo = fp.sk_tempo_abertura
LEFT JOIN dw.dim_tempo dt_fin         ON dt_fin.sk_tempo = fp.sk_tempo_finalizacao
JOIN dw.dim_cliente c                ON c.sk_cliente = fp.sk_cliente
LEFT JOIN dw.dim_prestador pr         ON pr.sk_prestador = fp.sk_prestador
JOIN dw.dim_cidade cid                ON cid.sk_cidade = fp.sk_cidade
JOIN dw.dim_categoria_servico cat     ON cat.sk_categoria_servico = fp.sk_categoria_servico
JOIN dw.dim_situacao_pedido sit       ON sit.sk_situacao_pedido = fp.sk_situacao_pedido
LEFT JOIN dw.dim_forma_pagamento fpg  ON fpg.sk_forma_pagamento = fp.sk_forma_pagamento;

CREATE OR REPLACE VIEW dm_orcamentos.vw_orcamento AS
SELECT
    fo.sk_orcamento,
    fo.codigo_orcamento,
    fo.codigo_pedido,
    dtc.data                AS data_criacao,
    dtv.data                AS data_validade,
    pr.nome                 AS prestador,
    cl.nome                 AS cliente,
    cat.descricao           AS categoria_servico,
    sit.situacao,
    sit.descricao           AS situacao_descricao,
    fo.solicitado_pelo_cliente,
    fo.valor,
    fo.foi_selecionado,
    fo.dias_validade
FROM dm_orcamentos.fato_orcamento fo
JOIN dw.dim_tempo dtc ON dtc.sk_tempo = fo.sk_tempo_criacao
LEFT JOIN dw.dim_tempo dtv ON dtv.sk_tempo = fo.sk_tempo_validade
JOIN dw.dim_prestador pr ON pr.sk_prestador = fo.sk_prestador
JOIN dw.dim_cliente cl ON cl.sk_cliente = fo.sk_cliente
JOIN dw.dim_categoria_servico cat ON cat.sk_categoria_servico = fo.sk_categoria_servico
JOIN dw.dim_situacao_orcamento sit ON sit.sk_situacao_orcamento = fo.sk_situacao_orcamento;

CREATE OR REPLACE VIEW dm_avaliacoes.vw_avaliacao AS
SELECT
    fa.sk_avaliacao,
    fa.codigo_avaliacao,
    fa.codigo_pedido,
    dt.data AS data_avaliacao,
    cl.nome AS cliente,
    pr.nome AS prestador,
    cat.descricao AS categoria_servico,
    cid.nome_cidade,
    cid.uf,
    fa.nota,
    fa.qtd_caracteres_comentario,
    fa.nota_acima_media
FROM dm_avaliacoes.fato_avaliacao fa
JOIN dw.dim_tempo dt ON dt.sk_tempo = fa.sk_tempo
JOIN dw.dim_cliente cl ON cl.sk_cliente = fa.sk_cliente
JOIN dw.dim_prestador pr ON pr.sk_prestador = fa.sk_prestador
JOIN dw.dim_categoria_servico cat ON cat.sk_categoria_servico = fa.sk_categoria_servico
JOIN dw.dim_cidade cid ON cid.sk_cidade = fa.sk_cidade;

CREATE OR REPLACE VIEW dm_agendamentos.vw_agendamento AS
SELECT
    fg.sk_agendamento,
    fg.codigo_agendamento,
    fg.codigo_pedido,
    dti.data AS data_inicio,
    dtf.data AS data_fim,
    pr.nome AS prestador,
    cl.nome AS cliente,
    fg.duracao_minutos,
    fg.dias_antecedencia,
    fg.reagendado
FROM dm_agendamentos.fato_agendamento fg
JOIN dw.dim_tempo dti ON dti.sk_tempo = fg.sk_tempo_inicio
JOIN dw.dim_tempo dtf ON dtf.sk_tempo = fg.sk_tempo_fim
JOIN dw.dim_prestador pr ON pr.sk_prestador = fg.sk_prestador
JOIN dw.dim_cliente cl ON cl.sk_cliente = fg.sk_cliente;

CREATE OR REPLACE VIEW dm_prestadores.vw_precificacao AS
SELECT
    fp.sk_precificacao,
    pr.nome AS prestador,
    pr.tipo_pessoa,
    cid.nome_cidade,
    cid.uf,
    cat.descricao AS categoria_servico,
    fp.valor_medio_cobrado,
    pr.avaliacao_media,
    pr.qtd_avaliacoes
FROM dm_prestadores.fato_precificacao_categoria fp
JOIN dw.dim_prestador pr ON pr.sk_prestador = fp.sk_prestador
JOIN dw.dim_cidade cid ON cid.sk_cidade = pr.sk_cidade
JOIN dw.dim_categoria_servico cat ON cat.sk_categoria_servico = fp.sk_categoria_servico;

CREATE OR REPLACE VIEW dm_planos.vw_assinatura AS
SELECT
    fa.sk_assinatura,
    pr.nome AS prestador,
    pl.descricao AS plano,
    dt.data AS data_inicio,
    fa.limite_clientes_mensal,
    fa.valor_mensalidade,
    fa.qtd_pedidos_recebidos_mes_atual,
    pr.avaliacao_media,
    pr.qtd_avaliacoes
FROM dm_planos.fato_assinatura_plano fa
JOIN dw.dim_prestador pr ON pr.sk_prestador = fa.sk_prestador
JOIN dw.dim_plano pl ON pl.sk_plano = fa.sk_plano
JOIN dw.dim_tempo dt ON dt.sk_tempo = fa.sk_tempo_inicio;
