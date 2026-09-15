-- =====================================================================
-- Prestador Nota 10 - Data Warehouse
-- 03_fato_pedido_orcamento_historico.sql
--
-- Datamarts: dm_pedidos (fato_pedido, fato_historico_situacao_pedido)
--            dm_orcamentos (fato_orcamento)
--
-- Grão:
--  dm_pedidos.fato_pedido                    -> 1 linha por pedido
--  dm_pedidos.fato_historico_situacao_pedido -> 1 linha por transição de situação do pedido
--  dm_orcamentos.fato_orcamento              -> 1 linha por orçamento enviado por um prestador
--
-- População sintética respeitando as regras de negócio da API:
--  * Fluxo de situação do pedido (SituacaoPedido): AGUARDANDO_ORCAMENTO ->
--    AGUARDANDO_AGENDAMENTO -> AGUARDANDO_ATENDIMENTO ->
--    FINALIZADO_AGUARDANDO_AVALIACAO -> FINALIZADO, podendo ser CANCELADO
--    em qualquer etapa.
--  * Cada pedido pode receber vários orçamentos (SituacaoOrcamento), mas
--    apenas um é selecionado (codigo_orcamento_selecionado em Pedido).
-- =====================================================================

CREATE TABLE dm_pedidos.fato_pedido (
    sk_pedido                     bigserial PRIMARY KEY,
    codigo_pedido                 integer NOT NULL UNIQUE,
    sk_tempo_abertura             integer NOT NULL REFERENCES dw.dim_tempo(sk_tempo),
    sk_tempo_finalizacao          integer REFERENCES dw.dim_tempo(sk_tempo),
    sk_cliente                    integer NOT NULL REFERENCES dw.dim_cliente(sk_cliente),
    sk_prestador                  integer REFERENCES dw.dim_prestador(sk_prestador),
    sk_cidade                     integer NOT NULL REFERENCES dw.dim_cidade(sk_cidade),
    sk_categoria_servico          integer NOT NULL REFERENCES dw.dim_categoria_servico(sk_categoria_servico),
    sk_situacao_pedido            integer NOT NULL REFERENCES dw.dim_situacao_pedido(sk_situacao_pedido),
    sk_forma_pagamento            integer REFERENCES dw.dim_forma_pagamento(sk_forma_pagamento),
    qtd_categorias_servico        smallint NOT NULL DEFAULT 1,
    qtd_orcamentos_recebidos      smallint NOT NULL DEFAULT 0,
    valor_orcamento_selecionado   numeric(10,2),
    dias_para_primeiro_orcamento  integer,
    dias_para_agendamento         integer,
    dias_para_finalizacao         integer,
    indicador_cancelado           boolean NOT NULL DEFAULT false,
    indicador_avaliado            boolean NOT NULL DEFAULT false,
    nota_avaliacao                numeric(3,1)
);
COMMENT ON TABLE dm_pedidos.fato_pedido IS 'Fato: 1 linha por pedido de serviço (grão = pedido)';

CREATE TABLE dm_pedidos.fato_historico_situacao_pedido (
    sk_historico                    bigserial PRIMARY KEY,
    sk_pedido                       bigint NOT NULL REFERENCES dm_pedidos.fato_pedido(sk_pedido),
    codigo_pedido                   integer NOT NULL,
    sk_tempo                        integer NOT NULL REFERENCES dw.dim_tempo(sk_tempo),
    sk_situacao_pedido              integer NOT NULL REFERENCES dw.dim_situacao_pedido(sk_situacao_pedido),
    sk_situacao_pedido_anterior     integer REFERENCES dw.dim_situacao_pedido(sk_situacao_pedido),
    ordem_transicao                 smallint NOT NULL,
    dias_desde_situacao_anterior    integer
);
COMMENT ON TABLE dm_pedidos.fato_historico_situacao_pedido IS 'Fato: 1 linha por transição de situação do pedido (grão = evento de mudança de situação)';

CREATE TABLE dm_orcamentos.fato_orcamento (
    sk_orcamento              bigserial PRIMARY KEY,
    codigo_orcamento          integer NOT NULL UNIQUE,
    sk_pedido                 bigint NOT NULL REFERENCES dm_pedidos.fato_pedido(sk_pedido),
    codigo_pedido             integer NOT NULL,
    sk_tempo_criacao          integer NOT NULL REFERENCES dw.dim_tempo(sk_tempo),
    sk_tempo_validade         integer REFERENCES dw.dim_tempo(sk_tempo),
    sk_prestador              integer NOT NULL REFERENCES dw.dim_prestador(sk_prestador),
    sk_cliente                integer NOT NULL REFERENCES dw.dim_cliente(sk_cliente),
    sk_categoria_servico      integer NOT NULL REFERENCES dw.dim_categoria_servico(sk_categoria_servico),
    sk_situacao_orcamento     integer NOT NULL REFERENCES dw.dim_situacao_orcamento(sk_situacao_orcamento),
    solicitado_pelo_cliente   boolean NOT NULL DEFAULT false,
    valor                     numeric(10,2) NOT NULL,
    foi_selecionado           boolean NOT NULL DEFAULT false,
    dias_validade             integer NOT NULL
);
COMMENT ON TABLE dm_orcamentos.fato_orcamento IS 'Fato: 1 linha por orçamento enviado por um prestador para um pedido (grão = orçamento)';

-- ---------------------------------------------------------------------
-- Geração sintética
-- ---------------------------------------------------------------------
DO $$
DECLARE
    v_clientes_sk        integer[];
    v_prestadores_sk     integer[];
    v_subcategorias_sk   integer[];
    v_formas_pgto_sk     integer[];
    v_qtd_clientes       integer;
    v_qtd_prestadores    integer;
    v_qtd_subcategorias  integer;

    v_total_pedidos      integer := 800;
    v_codigo_orcamento   integer := 0;

    i                    integer;
    j                    integer;
    v_sk_cliente         integer;
    v_sk_cidade          integer;
    v_sk_categoria       integer;
    v_data_abertura      date;
    v_r                  double precision;
    v_situacao_final     varchar(40);
    v_ordem_final        smallint;
    v_path               varchar(40)[];
    v_stage_reached      smallint;
    v_qtd_orcamentos     smallint;
    v_sk_pedido          bigint;
    v_data_atual         date;
    v_data_finalizacao   date;
    v_sk_tempo_finaliz   integer;
    v_dias_para_final    integer;
    v_dias_primeiro_orc  integer;
    v_dias_para_agend    integer;

    -- controle de orçamentos do pedido corrente
    v_orc_sk_prestador   integer[];
    v_orc_valor          numeric(10,2)[];
    v_orc_data_criacao   date[];
    v_idx_selecionado    integer;
    v_sk_prestador_sel   integer;
    v_valor_sel          numeric(10,2);
    v_sk_forma_pgto      integer;
    v_path_dates         date[];
    v_situacao_orc       varchar(40);
BEGIN
    SELECT array_agg(sk_cliente)    INTO v_clientes_sk      FROM dw.dim_cliente;
    SELECT array_agg(sk_prestador)  INTO v_prestadores_sk   FROM dw.dim_prestador;
    SELECT array_agg(sk_categoria_servico) INTO v_subcategorias_sk FROM dw.dim_categoria_servico WHERE nivel = 'SUBCATEGORIA';
    SELECT array_agg(sk_forma_pagamento) INTO v_formas_pgto_sk FROM dw.dim_forma_pagamento;

    v_qtd_clientes := array_length(v_clientes_sk, 1);
    v_qtd_prestadores := array_length(v_prestadores_sk, 1);
    v_qtd_subcategorias := array_length(v_subcategorias_sk, 1);

    PERFORM setseed(0.77);

    FOR i IN 1..v_total_pedidos LOOP
        v_sk_cliente := v_clientes_sk[1 + floor(random() * v_qtd_clientes)::int];
        SELECT sk_cidade INTO v_sk_cidade FROM dw.dim_cliente WHERE sk_cliente = v_sk_cliente;
        v_sk_categoria := v_subcategorias_sk[1 + floor(random() * v_qtd_subcategorias)::int];
        v_data_abertura := date '2022-02-01' + floor(random() * 1580)::int; -- até ~2026-06-01

        -- distribuição da situação final do pedido
        v_r := random();
        IF v_r < 0.07 THEN v_situacao_final := 'AGUARDANDO_ORCAMENTO'; v_ordem_final := 1;
        ELSIF v_r < 0.15 THEN v_situacao_final := 'AGUARDANDO_AGENDAMENTO'; v_ordem_final := 2;
        ELSIF v_r < 0.27 THEN v_situacao_final := 'AGUARDANDO_ATENDIMENTO'; v_ordem_final := 3;
        ELSIF v_r < 0.35 THEN v_situacao_final := 'FINALIZADO_AGUARDANDO_AVALIACAO'; v_ordem_final := 4;
        ELSIF v_r < 0.85 THEN v_situacao_final := 'FINALIZADO'; v_ordem_final := 5;
        ELSE v_situacao_final := 'CANCELADO'; v_ordem_final := 9;
        END IF;

        -- monta o caminho de transições de situação
        v_path := ARRAY['AGUARDANDO_ORCAMENTO']::varchar(40)[];
        IF v_situacao_final = 'CANCELADO' THEN
            v_stage_reached := 1 + floor(random() * 4)::int; -- cancela após atingir 1 a 4 etapas
            IF v_stage_reached >= 2 THEN v_path := array_append(v_path, 'AGUARDANDO_AGENDAMENTO'); END IF;
            IF v_stage_reached >= 3 THEN v_path := array_append(v_path, 'AGUARDANDO_ATENDIMENTO'); END IF;
            IF v_stage_reached >= 4 THEN v_path := array_append(v_path, 'FINALIZADO_AGUARDANDO_AVALIACAO'); END IF;
            v_path := array_append(v_path, 'CANCELADO');
        ELSE
            IF v_ordem_final >= 2 THEN v_path := array_append(v_path, 'AGUARDANDO_AGENDAMENTO'); END IF;
            IF v_ordem_final >= 3 THEN v_path := array_append(v_path, 'AGUARDANDO_ATENDIMENTO'); END IF;
            IF v_ordem_final >= 4 THEN v_path := array_append(v_path, 'FINALIZADO_AGUARDANDO_AVALIACAO'); END IF;
            IF v_ordem_final >= 5 THEN v_path := array_append(v_path, 'FINALIZADO'); END IF;
        END IF;

        -- quantidade de orçamentos recebidos (0 a 4; pedidos ainda em AGUARDANDO_ORCAMENTO podem ter 0)
        IF v_situacao_final = 'AGUARDANDO_ORCAMENTO' AND random() < 0.3 THEN
            v_qtd_orcamentos := 0;
        ELSE
            v_qtd_orcamentos := 1 + floor(random() * 4)::int;
        END IF;

        -- gera os orçamentos do pedido em memória
        v_orc_sk_prestador := ARRAY[]::integer[];
        v_orc_valor := ARRAY[]::numeric(10,2)[];
        v_orc_data_criacao := ARRAY[]::date[];
        FOR j IN 1..v_qtd_orcamentos LOOP
            v_orc_sk_prestador := array_append(v_orc_sk_prestador, v_prestadores_sk[1 + floor(random() * v_qtd_prestadores)::int]);
            v_orc_valor := array_append(v_orc_valor, round((80 + random() * 920)::numeric, 2));
            v_orc_data_criacao := array_append(v_orc_data_criacao, v_data_abertura + floor(random() * 5)::int);
        END LOOP;

        -- seleciona um orçamento vencedor, se o pedido avançou além de AGUARDANDO_ORCAMENTO
        v_idx_selecionado := NULL;
        v_sk_prestador_sel := NULL;
        v_valor_sel := NULL;
        IF v_qtd_orcamentos > 0 AND array_length(v_path, 1) > 1 THEN
            v_idx_selecionado := 1 + floor(random() * v_qtd_orcamentos)::int;
            v_sk_prestador_sel := v_orc_sk_prestador[v_idx_selecionado];
            v_valor_sel := v_orc_valor[v_idx_selecionado];
        END IF;

        -- percorre o caminho de transições, calculando a data de cada etapa uma única vez
        -- (o mesmo array de datas é reutilizado no fato_pedido e no histórico, garantindo consistência)
        v_path_dates := ARRAY[v_data_abertura];
        v_data_atual := v_data_abertura;
        FOR j IN 2..array_length(v_path, 1) LOOP
            v_data_atual := v_data_atual + (1 + floor(random() * 12))::int;
            v_path_dates := array_append(v_path_dates, v_data_atual);
        END LOOP;
        v_data_finalizacao := NULL;
        v_sk_tempo_finaliz := NULL;
        IF v_path[array_length(v_path, 1)] IN ('FINALIZADO', 'CANCELADO') THEN
            v_data_finalizacao := v_path_dates[array_length(v_path_dates, 1)];
            v_sk_tempo_finaliz := to_char(v_data_finalizacao, 'YYYYMMDD')::integer;
        END IF;

        v_dias_para_final := CASE WHEN v_data_finalizacao IS NOT NULL THEN v_data_finalizacao - v_data_abertura ELSE NULL END;
        v_dias_primeiro_orc := CASE WHEN v_qtd_orcamentos > 0 THEN (SELECT min(x) - v_data_abertura FROM unnest(v_orc_data_criacao) x) ELSE NULL END;
        v_dias_para_agend := CASE WHEN array_position(v_path, 'AGUARDANDO_AGENDAMENTO') IS NOT NULL
                              THEN v_path_dates[array_position(v_path, 'AGUARDANDO_AGENDAMENTO')] - v_data_abertura
                              ELSE NULL END;

        v_sk_forma_pgto := CASE WHEN v_path[array_length(v_path,1)] IN ('FINALIZADO_AGUARDANDO_AVALIACAO','FINALIZADO')
                                 THEN v_formas_pgto_sk[1 + floor(random() * array_length(v_formas_pgto_sk,1))::int]
                                 ELSE NULL END;

        INSERT INTO dm_pedidos.fato_pedido (
            codigo_pedido, sk_tempo_abertura, sk_tempo_finalizacao, sk_cliente, sk_prestador, sk_cidade,
            sk_categoria_servico, sk_situacao_pedido, sk_forma_pagamento, qtd_categorias_servico,
            qtd_orcamentos_recebidos, valor_orcamento_selecionado, dias_para_primeiro_orcamento,
            dias_para_agendamento, dias_para_finalizacao, indicador_cancelado, indicador_avaliado, nota_avaliacao
        ) VALUES (
            i,
            to_char(v_data_abertura, 'YYYYMMDD')::integer,
            v_sk_tempo_finaliz,
            v_sk_cliente,
            v_sk_prestador_sel,
            v_sk_cidade,
            v_sk_categoria,
            (SELECT sk_situacao_pedido FROM dw.dim_situacao_pedido WHERE situacao = v_path[array_length(v_path,1)]),
            v_sk_forma_pgto,
            1 + floor(random() * 3)::int,
            v_qtd_orcamentos,
            v_valor_sel,
            v_dias_primeiro_orc,
            v_dias_para_agend,
            v_dias_para_final,
            v_path[array_length(v_path,1)] = 'CANCELADO',
            false,
            NULL
        ) RETURNING sk_pedido INTO v_sk_pedido;

        -- histórico de situação (reutiliza as mesmas datas calculadas em v_path_dates)
        FOR j IN 1..array_length(v_path, 1) LOOP
            INSERT INTO dm_pedidos.fato_historico_situacao_pedido (
                sk_pedido, codigo_pedido, sk_tempo, sk_situacao_pedido, sk_situacao_pedido_anterior, ordem_transicao, dias_desde_situacao_anterior
            ) VALUES (
                v_sk_pedido,
                i,
                to_char(v_path_dates[j], 'YYYYMMDD')::integer,
                (SELECT sk_situacao_pedido FROM dw.dim_situacao_pedido WHERE situacao = v_path[j]),
                CASE WHEN j = 1 THEN NULL ELSE (SELECT sk_situacao_pedido FROM dw.dim_situacao_pedido WHERE situacao = v_path[j-1]) END,
                j,
                CASE WHEN j = 1 THEN NULL ELSE v_path_dates[j] - v_path_dates[j-1] END
            );
        END LOOP;

        -- orçamentos do pedido
        FOR j IN 1..v_qtd_orcamentos LOOP
            v_codigo_orcamento := v_codigo_orcamento + 1;

            -- calcula a situação do orçamento uma única vez (evita reavaliar random()
            -- por linha ao comparar dentro do WHERE de uma subquery)
            v_situacao_orc := CASE
                WHEN j = v_idx_selecionado AND v_path[array_length(v_path,1)] = 'FINALIZADO' THEN 'FINALIZADO'
                WHEN j = v_idx_selecionado AND v_path[array_length(v_path,1)] = 'CANCELADO' THEN 'CANCELADO'
                WHEN j = v_idx_selecionado THEN 'ACEITO'
                WHEN random() < 0.5 THEN 'NOVO'
                WHEN random() < 0.8 THEN 'AGUARDANDO_CLIENTE'
                ELSE 'CANCELADO'
            END;

            INSERT INTO dm_orcamentos.fato_orcamento (
                codigo_orcamento, sk_pedido, codigo_pedido, sk_tempo_criacao, sk_tempo_validade, sk_prestador, sk_cliente,
                sk_categoria_servico, sk_situacao_orcamento, solicitado_pelo_cliente, valor, foi_selecionado, dias_validade
            ) VALUES (
                v_codigo_orcamento,
                v_sk_pedido,
                i,
                to_char(v_orc_data_criacao[j], 'YYYYMMDD')::integer,
                to_char(v_orc_data_criacao[j] + (7 + floor(random()*23))::int, 'YYYYMMDD')::integer,
                v_orc_sk_prestador[j],
                v_sk_cliente,
                v_sk_categoria,
                (SELECT sk_situacao_orcamento FROM dw.dim_situacao_orcamento WHERE situacao = v_situacao_orc),
                random() < 0.2,
                v_orc_valor[j],
                COALESCE(j = v_idx_selecionado, false),
                7 + floor(random()*23)::int
            );
        END LOOP;
    END LOOP;
END $$;
