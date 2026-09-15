-- =====================================================================
-- Prestador Nota 10 - Data Warehouse
-- 04_fato_avaliacao_agendamento.sql
--
-- Datamarts: dm_avaliacoes (fato_avaliacao)
--            dm_agendamentos (fato_agendamento)
--
-- Grão:
--  dm_avaliacoes.fato_avaliacao    -> 1 linha por avaliação de pedido concluído
--  dm_agendamentos.fato_agendamento -> 1 linha por agendamento de atendimento
--
-- Regras de negócio respeitadas:
--  * Só existe avaliação para pedidos cuja situação final é FINALIZADO
--    (AvaliacaoPedido é 1:1 com Pedido - PedidoJaAvaliadoException impede duplicidade).
--  * Só existe agendamento para pedidos que avançaram até (ou além de)
--    AGUARDANDO_ATENDIMENTO no fluxo de situação.
-- =====================================================================

CREATE TABLE dm_avaliacoes.fato_avaliacao (
    sk_avaliacao               bigserial PRIMARY KEY,
    codigo_avaliacao            integer NOT NULL UNIQUE,
    sk_pedido                   bigint NOT NULL UNIQUE REFERENCES dm_pedidos.fato_pedido(sk_pedido),
    codigo_pedido                integer NOT NULL,
    sk_tempo                     integer NOT NULL REFERENCES dw.dim_tempo(sk_tempo),
    sk_cliente                   integer NOT NULL REFERENCES dw.dim_cliente(sk_cliente),
    sk_prestador                 integer NOT NULL REFERENCES dw.dim_prestador(sk_prestador),
    sk_categoria_servico         integer NOT NULL REFERENCES dw.dim_categoria_servico(sk_categoria_servico),
    sk_cidade                    integer NOT NULL REFERENCES dw.dim_cidade(sk_cidade),
    nota                         numeric(3,1) NOT NULL CHECK (nota BETWEEN 1 AND 5),
    qtd_caracteres_comentario    integer NOT NULL,
    nota_acima_media             boolean NOT NULL
);
COMMENT ON TABLE dm_avaliacoes.fato_avaliacao IS 'Fato: 1 linha por avaliação de pedido finalizado (grão = avaliação)';

CREATE TABLE dm_agendamentos.fato_agendamento (
    sk_agendamento      bigserial PRIMARY KEY,
    codigo_agendamento   integer NOT NULL UNIQUE,
    sk_pedido            bigint NOT NULL UNIQUE REFERENCES dm_pedidos.fato_pedido(sk_pedido),
    codigo_pedido         integer NOT NULL,
    sk_tempo_inicio       integer NOT NULL REFERENCES dw.dim_tempo(sk_tempo),
    sk_tempo_fim          integer NOT NULL REFERENCES dw.dim_tempo(sk_tempo),
    sk_prestador          integer NOT NULL REFERENCES dw.dim_prestador(sk_prestador),
    sk_cliente            integer NOT NULL REFERENCES dw.dim_cliente(sk_cliente),
    duracao_minutos       integer NOT NULL,
    dias_antecedencia     integer NOT NULL,
    reagendado            boolean NOT NULL DEFAULT false
);
COMMENT ON TABLE dm_agendamentos.fato_agendamento IS 'Fato: 1 linha por agendamento de atendimento (grão = agendamento)';

-- ---------------------------------------------------------------------
-- Geração sintética: avaliações (pedidos com situação final = FINALIZADO)
-- ---------------------------------------------------------------------
DO $$
DECLARE
    rec               record;
    v_codigo           integer := 0;
    v_r                double precision;
    v_nota             numeric(3,1);
    v_data_avaliacao   date;
BEGIN
    PERFORM setseed(0.13);

    FOR rec IN
        SELECT fp.sk_pedido, fp.codigo_pedido, fp.sk_cliente, fp.sk_prestador, fp.sk_categoria_servico,
               fp.sk_cidade, fp.sk_tempo_finalizacao, dt.data AS data_finalizacao
        FROM dm_pedidos.fato_pedido fp
        JOIN dw.dim_situacao_pedido dsp ON dsp.sk_situacao_pedido = fp.sk_situacao_pedido
        JOIN dw.dim_tempo dt ON dt.sk_tempo = fp.sk_tempo_finalizacao
        WHERE dsp.situacao = 'FINALIZADO'
    LOOP
        v_codigo := v_codigo + 1;
        v_r := random();
        v_nota := CASE
            WHEN v_r < 0.05 THEN 1
            WHEN v_r < 0.10 THEN 2
            WHEN v_r < 0.20 THEN 3
            WHEN v_r < 0.50 THEN 4
            ELSE 5
        END;
        v_data_avaliacao := rec.data_finalizacao + floor(random() * 4)::int;

        INSERT INTO dm_avaliacoes.fato_avaliacao (
            codigo_avaliacao, sk_pedido, codigo_pedido, sk_tempo, sk_cliente, sk_prestador,
            sk_categoria_servico, sk_cidade, nota, qtd_caracteres_comentario, nota_acima_media
        ) VALUES (
            v_codigo, rec.sk_pedido, rec.codigo_pedido,
            to_char(v_data_avaliacao, 'YYYYMMDD')::integer,
            rec.sk_cliente, rec.sk_prestador, rec.sk_categoria_servico, rec.sk_cidade,
            v_nota,
            20 + floor(random() * 280)::int,
            v_nota >= 4
        );

        UPDATE dm_pedidos.fato_pedido
        SET indicador_avaliado = true, nota_avaliacao = v_nota
        WHERE sk_pedido = rec.sk_pedido;
    END LOOP;
END $$;

-- ---------------------------------------------------------------------
-- Geração sintética: agendamentos (pedidos que atingiram AGUARDANDO_ATENDIMENTO ou além)
-- ---------------------------------------------------------------------
DO $$
DECLARE
    rec              record;
    v_codigo          integer := 0;
    v_duracao         integer;
    v_data_fim        date;
BEGIN
    PERFORM setseed(0.29);

    FOR rec IN
        SELECT fp.sk_pedido, fp.codigo_pedido, fp.sk_prestador, fp.sk_cliente,
               dt_abertura.data AS data_abertura, dt_evento.data AS data_inicio
        FROM dm_pedidos.fato_pedido fp
        JOIN dw.dim_tempo dt_abertura ON dt_abertura.sk_tempo = fp.sk_tempo_abertura
        JOIN dm_pedidos.fato_historico_situacao_pedido h ON h.sk_pedido = fp.sk_pedido
        JOIN dw.dim_situacao_pedido dsp ON dsp.sk_situacao_pedido = h.sk_situacao_pedido AND dsp.situacao = 'AGUARDANDO_ATENDIMENTO'
        JOIN dw.dim_tempo dt_evento ON dt_evento.sk_tempo = h.sk_tempo
        WHERE fp.sk_prestador IS NOT NULL
    LOOP
        v_codigo := v_codigo + 1;
        v_duracao := 30 * (1 + floor(random() * 8))::int; -- 30 a 240 minutos
        v_data_fim := rec.data_inicio; -- mesmo dia (granularidade diária)

        INSERT INTO dm_agendamentos.fato_agendamento (
            codigo_agendamento, sk_pedido, codigo_pedido, sk_tempo_inicio, sk_tempo_fim,
            sk_prestador, sk_cliente, duracao_minutos, dias_antecedencia, reagendado
        ) VALUES (
            v_codigo, rec.sk_pedido, rec.codigo_pedido,
            to_char(rec.data_inicio, 'YYYYMMDD')::integer,
            to_char(v_data_fim, 'YYYYMMDD')::integer,
            rec.sk_prestador, rec.sk_cliente, v_duracao,
            rec.data_inicio - rec.data_abertura,
            random() < 0.15
        );
    END LOOP;
END $$;
