-- =====================================================================
-- Prestador Nota 10 - Data Warehouse
-- 05_fato_prestadores_planos.sql
--
-- Datamarts: dm_prestadores (fato_precificacao_categoria)
--            dm_planos (fato_assinatura_plano)
--
-- Grão:
--  dm_prestadores.fato_precificacao_categoria -> 1 linha por (prestador, categoria de serviço atendida)
--  dm_planos.fato_assinatura_plano             -> 1 linha por prestador (snapshot do plano vigente)
--
-- Espelha public.categoria_servico_prestador (valor médio cobrado por
-- categoria) e public.usuario.codigo_plano / public.plano.
-- =====================================================================

CREATE TABLE dm_prestadores.fato_precificacao_categoria (
    sk_precificacao       bigserial PRIMARY KEY,
    sk_prestador          integer NOT NULL REFERENCES dw.dim_prestador(sk_prestador),
    sk_categoria_servico  integer NOT NULL REFERENCES dw.dim_categoria_servico(sk_categoria_servico),
    valor_medio_cobrado   numeric(10,2) NOT NULL,
    UNIQUE (sk_prestador, sk_categoria_servico)
);
COMMENT ON TABLE dm_prestadores.fato_precificacao_categoria IS 'Fato: 1 linha por categoria de serviço atendida por um prestador (grão = prestador x categoria)';

CREATE TABLE dm_planos.fato_assinatura_plano (
    sk_assinatura                    bigserial PRIMARY KEY,
    sk_prestador                     integer NOT NULL UNIQUE REFERENCES dw.dim_prestador(sk_prestador),
    sk_plano                         integer NOT NULL REFERENCES dw.dim_plano(sk_plano),
    sk_tempo_inicio                  integer NOT NULL REFERENCES dw.dim_tempo(sk_tempo),
    limite_clientes_mensal           integer NOT NULL,
    valor_mensalidade                numeric(10,2) NOT NULL,
    qtd_pedidos_recebidos_mes_atual  integer NOT NULL DEFAULT 0
);
COMMENT ON TABLE dm_planos.fato_assinatura_plano IS 'Fato: 1 linha por assinatura vigente de plano do prestador (grão = prestador)';

-- ---------------------------------------------------------------------
-- Geração sintética: precificação por categoria
-- ---------------------------------------------------------------------
DO $$
DECLARE
    v_subcategorias_sk  integer[];
    v_qtd_subcategorias integer;
    rec                 record;
    v_qtd_categorias    integer;
    v_escolhidas        integer[];
    v_cat               integer;
    k                   integer;
BEGIN
    SELECT array_agg(sk_categoria_servico) INTO v_subcategorias_sk FROM dw.dim_categoria_servico WHERE nivel = 'SUBCATEGORIA';
    v_qtd_subcategorias := array_length(v_subcategorias_sk, 1);

    PERFORM setseed(0.55);

    FOR rec IN SELECT sk_prestador FROM dw.dim_prestador LOOP
        v_qtd_categorias := 1 + floor(random() * 4)::int;
        v_escolhidas := ARRAY[]::integer[];
        FOR k IN 1..v_qtd_categorias LOOP
            v_cat := v_subcategorias_sk[1 + floor(random() * v_qtd_subcategorias)::int];
            IF NOT (v_cat = ANY(v_escolhidas)) THEN
                v_escolhidas := v_escolhidas || v_cat;
                INSERT INTO dm_prestadores.fato_precificacao_categoria (sk_prestador, sk_categoria_servico, valor_medio_cobrado)
                VALUES (rec.sk_prestador, v_cat, round((80 + random() * 820)::numeric, 2));
            END IF;
        END LOOP;
    END LOOP;
END $$;

-- ---------------------------------------------------------------------
-- Geração sintética: assinatura de plano vigente por prestador
-- ---------------------------------------------------------------------
INSERT INTO dm_planos.fato_assinatura_plano (sk_prestador, sk_plano, sk_tempo_inicio, limite_clientes_mensal, valor_mensalidade, qtd_pedidos_recebidos_mes_atual)
SELECT
    p.sk_prestador,
    p.sk_plano,
    to_char(p.data_cadastro, 'YYYYMMDD')::integer,
    pl.limite_clientes_mensal,
    pl.valor_mensalidade,
    COALESCE(m.qtd_pedidos, 0)
FROM dw.dim_prestador p
JOIN dw.dim_plano pl ON pl.sk_plano = p.sk_plano
LEFT JOIN (
    -- mês de referência = mês mais recente com orçamentos gerados
    SELECT fo.sk_prestador, count(*) AS qtd_pedidos
    FROM dm_orcamentos.fato_orcamento fo
    JOIN dw.dim_tempo dt ON dt.sk_tempo = fo.sk_tempo_criacao
    WHERE (dt.ano, dt.mes) = (
        SELECT dt2.ano, dt2.mes
        FROM dm_orcamentos.fato_orcamento fo2
        JOIN dw.dim_tempo dt2 ON dt2.sk_tempo = fo2.sk_tempo_criacao
        ORDER BY dt2.data DESC
        LIMIT 1
    )
    GROUP BY fo.sk_prestador
) m ON m.sk_prestador = p.sk_prestador;

-- ---------------------------------------------------------------------
-- Atualiza a reputação do prestador (avaliacao_media / qtd_avaliacoes)
-- a partir do datamart de avaliações, mantendo dw.dim_prestador consistente
-- ---------------------------------------------------------------------
UPDATE dw.dim_prestador p
SET avaliacao_media = a.media_nota,
    qtd_avaliacoes = a.qtd
FROM (
    SELECT sk_prestador, round(avg(nota), 2) AS media_nota, count(*) AS qtd
    FROM dm_avaliacoes.fato_avaliacao
    GROUP BY sk_prestador
) a
WHERE a.sk_prestador = p.sk_prestador;
