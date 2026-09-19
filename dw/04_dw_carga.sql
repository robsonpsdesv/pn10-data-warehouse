-- =====================================================================
-- Prestador Nota 10 - Data Warehouse
-- 04_dw_carga.sql
--
-- PASSO 2 (DW) - Etapa 2/2: carga (dimensões + fatos, mesmo schema `dw`).
--
-- dim_tempo, dim_cidade e dim_categoria_servico são carregadas a partir
-- dos dados mestres/de referência já existentes no schema operacional
-- (pn10.cidade, pn10.estado, pn10.categoria_servico), pois são
-- dados de apoio (não transacionais) legítimos para reaproveitar.
-- As demais dimensões (situações e forma de pagamento) refletem os
-- enums de domínio do código-fonte da API (SituacaoPedido,
-- SituacaoOrcamento, FormaPagamento). dim_plano, dim_cliente e
-- dim_prestador são sintéticas. As tabelas fato (fato_pedido,
-- fato_orcamento, fato_avaliacao, fato_agendamento,
-- fato_precificacao_categoria, fato_assinatura_plano) também são
-- sintéticas, respeitando o fluxo de negócio da API.
--
-- Pré-requisito: 03_dw_ddl.sql já executado.
-- =====================================================================

-- ---------------------------------------------------------------------
-- dim_tempo
-- ---------------------------------------------------------------------
INSERT INTO dw.dim_tempo
SELECT
    to_char(d, 'YYYYMMDD')::integer                                   AS sk_tempo,
    d                                                                  AS data,
    extract(year FROM d)::smallint                                     AS ano,
    extract(quarter FROM d)::smallint                                  AS trimestre,
    extract(month FROM d)::smallint                                    AS mes,
    to_char(d, 'TMMonth')                                              AS nome_mes,
    extract(day FROM d)::smallint                                      AS dia,
    extract(dow FROM d)::smallint                                      AS dia_semana,
    to_char(d, 'TMDay')                                                AS nome_dia_semana,
    extract(week FROM d)::smallint                                     AS semana_ano,
    extract(dow FROM d) IN (0, 6)                                      AS fim_de_semana
FROM generate_series('2022-01-01'::date, '2026-12-31'::date, interval '1 day') AS d;

-- ---------------------------------------------------------------------
-- dim_cidade (geografia de atendimento)
-- ---------------------------------------------------------------------
INSERT INTO dw.dim_cidade (codigo_cidade, nome_cidade, uf, nome_estado, regiao)
SELECT
    c.codigo,
    c.nome,
    e.sigla,
    e.nome,
    CASE e.sigla
        WHEN 'AC' THEN 'Norte' WHEN 'AP' THEN 'Norte' WHEN 'AM' THEN 'Norte' WHEN 'PA' THEN 'Norte'
        WHEN 'RO' THEN 'Norte' WHEN 'RR' THEN 'Norte' WHEN 'TO' THEN 'Norte'
        WHEN 'AL' THEN 'Nordeste' WHEN 'BA' THEN 'Nordeste' WHEN 'CE' THEN 'Nordeste' WHEN 'MA' THEN 'Nordeste'
        WHEN 'PB' THEN 'Nordeste' WHEN 'PE' THEN 'Nordeste' WHEN 'PI' THEN 'Nordeste' WHEN 'RN' THEN 'Nordeste'
        WHEN 'SE' THEN 'Nordeste'
        WHEN 'DF' THEN 'Centro-Oeste' WHEN 'GO' THEN 'Centro-Oeste' WHEN 'MT' THEN 'Centro-Oeste' WHEN 'MS' THEN 'Centro-Oeste'
        WHEN 'ES' THEN 'Sudeste' WHEN 'MG' THEN 'Sudeste' WHEN 'RJ' THEN 'Sudeste' WHEN 'SP' THEN 'Sudeste'
        WHEN 'PR' THEN 'Sul' WHEN 'RS' THEN 'Sul' WHEN 'SC' THEN 'Sul'
        ELSE 'Não informado'
    END
FROM pn10.cidade c
JOIN pn10.estado e ON e.codigo = c.codigo_estado
WHERE COALESCE(c.deletado, false) = false;

-- ---------------------------------------------------------------------
-- dim_categoria_servico
-- ---------------------------------------------------------------------
INSERT INTO dw.dim_categoria_servico (codigo_categoria, descricao, codigo_categoria_pai, descricao_categoria_pai, nivel)
SELECT
    cs.codigo,
    cs.descricao,
    cs.codigo_categoria_pai,
    pai.descricao,
    CASE WHEN cs.codigo_categoria_pai IS NULL THEN 'CATEGORIA' ELSE 'SUBCATEGORIA' END
FROM pn10.categoria_servico cs
LEFT JOIN pn10.categoria_servico pai ON pai.codigo = cs.codigo_categoria_pai
WHERE COALESCE(cs.deletado, false) = false;

-- ---------------------------------------------------------------------
-- dim_situacao_pedido (enum SituacaoPedido)
-- ---------------------------------------------------------------------
INSERT INTO dw.dim_situacao_pedido (situacao, descricao, ordem_fluxo, encerra_pedido) VALUES
    ('AGUARDANDO_ORCAMENTO',            'Aguardando orçamento de prestadores', 1, false),
    ('AGUARDANDO_AGENDAMENTO',          'Orçamento aceito, aguardando agendamento', 2, false),
    ('AGUARDANDO_ATENDIMENTO',          'Agendado, aguardando execução do serviço', 3, false),
    ('FINALIZADO_AGUARDANDO_AVALIACAO', 'Serviço executado, aguardando avaliação do cliente', 4, false),
    ('FINALIZADO',                      'Pedido concluído e avaliado', 5, true),
    ('CANCELADO',                       'Pedido cancelado pelo cliente ou prestador', 9, true);

-- ---------------------------------------------------------------------
-- dim_situacao_orcamento (enum SituacaoOrcamento)
-- ---------------------------------------------------------------------
INSERT INTO dw.dim_situacao_orcamento (situacao, descricao) VALUES
    ('NOVO',               'Orçamento enviado pelo prestador, aguardando análise'),
    ('AGUARDANDO_CLIENTE',  'Orçamento em negociação, aguardando decisão do cliente'),
    ('ACEITO',              'Orçamento aceito pelo cliente'),
    ('FINALIZADO',          'Orçamento vinculado a um pedido finalizado'),
    ('CANCELADO',           'Orçamento recusado/cancelado');

-- ---------------------------------------------------------------------
-- dim_forma_pagamento (enum FormaPagamento)
-- ---------------------------------------------------------------------
INSERT INTO dw.dim_forma_pagamento (forma, descricao) VALUES
    ('PIX',      'Pagamento instantâneo via PIX'),
    ('CARTAO',   'Pagamento com cartão de crédito/débito'),
    ('DINHEIRO', 'Pagamento em espécie');

-- ---------------------------------------------------------------------
-- dim_plano (planos comerciais dos prestadores) - sintética
-- ---------------------------------------------------------------------
INSERT INTO dw.dim_plano (codigo_plano, descricao, limite_clientes_mensal, valor_mensalidade) VALUES
    (1, 'BASICO',       10, 49.90),
    (2, 'PROFISSIONAL', 30, 99.90),
    (3, 'PREMIUM',      100, 199.90);

-- ---------------------------------------------------------------------
-- dim_cliente / dim_prestador - sintéticas
-- ---------------------------------------------------------------------
DO $$
DECLARE
    v_nomes            varchar[] := ARRAY['Ana','João','Maria','Pedro','Carla','Lucas','Fernanda','Rafael','Juliana','Bruno',
                                           'Camila','Diego','Larissa','Marcos','Patrícia','Rodrigo','Aline','Thiago','Vanessa','Gustavo',
                                           'Beatriz','Eduardo','Renata','Felipe','Priscila','André','Débora','Vinícius','Tatiane','Leonardo',
                                           'Cristina','Rogério','Simone','Márcio','Fabiana','Alex','Michele','Douglas','Sandra','Wesley'];
    v_sobrenomes        varchar[] := ARRAY['Silva','Souza','Oliveira','Santos','Pereira','Costa','Rodrigues','Almeida','Nascimento','Lima',
                                            'Araújo','Ribeiro','Carvalho','Gomes','Martins','Rocha','Barbosa','Freitas','Cardoso','Teixeira',
                                            'Moreira','Correia','Dias','Castro','Campos','Cavalcanti','Vieira','Duarte','Machado','Farias'];
    v_empresas          varchar[] := ARRAY['Serviços Express','Soluções Rápidas','Casa & Cia','Mão na Massa','Ponto Certo','Reparos Já',
                                            'Multi Serviços','Confiança Total','Obra Fácil','Bom Atendimento'];
    v_cidades_sk        integer[];
    v_planos_sk         integer[];
    i                   integer;
    v_nome              varchar;
    v_tipo_pessoa       varchar;
    v_qtd_cidades       integer;
    v_qtd_planos        integer;
BEGIN
    SELECT array_agg(sk_cidade) INTO v_cidades_sk FROM dw.dim_cidade;
    SELECT array_agg(sk_plano)  INTO v_planos_sk  FROM dw.dim_plano;
    v_qtd_cidades := array_length(v_cidades_sk, 1);
    v_qtd_planos  := array_length(v_planos_sk, 1);

    PERFORM setseed(0.42);

    -- Clientes (300) : ~90% pessoa física, 10% pessoa jurídica
    FOR i IN 1..300 LOOP
        IF random() < 0.9 THEN
            v_tipo_pessoa := 'PF';
            v_nome := v_nomes[1 + floor(random() * array_length(v_nomes, 1))::int]
                      || ' ' || v_sobrenomes[1 + floor(random() * array_length(v_sobrenomes, 1))::int];
        ELSE
            v_tipo_pessoa := 'PJ';
            v_nome := v_empresas[1 + floor(random() * array_length(v_empresas, 1))::int] || ' ' || i;
        END IF;

        INSERT INTO dw.dim_cliente (codigo_cliente, nome, tipo_pessoa, documento, sk_cidade, data_cadastro, ativo)
        VALUES (
            i,
            v_nome,
            v_tipo_pessoa,
            CASE WHEN v_tipo_pessoa = 'PF'
                 THEN lpad((random()*99999999999)::bigint::text, 11, '0')
                 ELSE lpad((random()*99999999999999)::bigint::text, 14, '0') END,
            v_cidades_sk[1 + floor(random() * v_qtd_cidades)::int],
            (date '2022-01-01' + (random() * 1400)::int),
            random() < 0.95
        );
    END LOOP;

    -- Prestadores (120) : ~75% pessoa física, 25% pessoa jurídica (MEI/empresas)
    FOR i IN 1..120 LOOP
        IF random() < 0.75 THEN
            v_tipo_pessoa := 'PF';
            v_nome := v_nomes[1 + floor(random() * array_length(v_nomes, 1))::int]
                      || ' ' || v_sobrenomes[1 + floor(random() * array_length(v_sobrenomes, 1))::int];
        ELSE
            v_tipo_pessoa := 'PJ';
            v_nome := v_empresas[1 + floor(random() * array_length(v_empresas, 1))::int] || ' ' || i;
        END IF;

        INSERT INTO dw.dim_prestador (codigo_prestador, nome, tipo_pessoa, documento, sk_cidade, sk_plano, avaliacao_media, qtd_avaliacoes, data_cadastro, ativo)
        VALUES (
            i,
            v_nome,
            v_tipo_pessoa,
            CASE WHEN v_tipo_pessoa = 'PF'
                 THEN lpad((random()*99999999999)::bigint::text, 11, '0')
                 ELSE lpad((random()*99999999999999)::bigint::text, 14, '0') END,
            v_cidades_sk[1 + floor(random() * v_qtd_cidades)::int],
            -- distribuição de planos: 50% básico, 35% profissional, 15% premium
            (CASE WHEN random() < 0.50 THEN v_planos_sk[1] WHEN random() < 0.85 THEN v_planos_sk[2] ELSE v_planos_sk[3] END),
            NULL, -- calculada posteriormente a partir de dw.fato_avaliacao
            0,
            (date '2022-01-01' + (random() * 1200)::int),
            random() < 0.92
        );
    END LOOP;
END $$;

-- ---------------------------------------------------------------------
-- fato_pedido / fato_historico_situacao_pedido / fato_orcamento
--
-- Fluxo de situação do pedido (SituacaoPedido): AGUARDANDO_ORCAMENTO ->
-- AGUARDANDO_AGENDAMENTO -> AGUARDANDO_ATENDIMENTO ->
-- FINALIZADO_AGUARDANDO_AVALIACAO -> FINALIZADO, podendo ser CANCELADO
-- em qualquer etapa. Cada pedido pode receber vários orçamentos
-- (SituacaoOrcamento), mas apenas um é selecionado.
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

        INSERT INTO dw.fato_pedido (
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
            INSERT INTO dw.fato_historico_situacao_pedido (
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

            INSERT INTO dw.fato_orcamento (
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

-- ---------------------------------------------------------------------
-- fato_avaliacao (pedidos com situação final = FINALIZADO)
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
        FROM dw.fato_pedido fp
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

        INSERT INTO dw.fato_avaliacao (
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

        UPDATE dw.fato_pedido
        SET indicador_avaliado = true, nota_avaliacao = v_nota
        WHERE sk_pedido = rec.sk_pedido;
    END LOOP;
END $$;

-- ---------------------------------------------------------------------
-- fato_agendamento (pedidos que atingiram AGUARDANDO_ATENDIMENTO ou além)
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
        FROM dw.fato_pedido fp
        JOIN dw.dim_tempo dt_abertura ON dt_abertura.sk_tempo = fp.sk_tempo_abertura
        JOIN dw.fato_historico_situacao_pedido h ON h.sk_pedido = fp.sk_pedido
        JOIN dw.dim_situacao_pedido dsp ON dsp.sk_situacao_pedido = h.sk_situacao_pedido AND dsp.situacao = 'AGUARDANDO_ATENDIMENTO'
        JOIN dw.dim_tempo dt_evento ON dt_evento.sk_tempo = h.sk_tempo
        WHERE fp.sk_prestador IS NOT NULL
    LOOP
        v_codigo := v_codigo + 1;
        v_duracao := 30 * (1 + floor(random() * 8))::int; -- 30 a 240 minutos
        v_data_fim := rec.data_inicio; -- mesmo dia (granularidade diária)

        INSERT INTO dw.fato_agendamento (
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

-- ---------------------------------------------------------------------
-- fato_precificacao_categoria (prestador x categoria de serviço atendida)
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
                INSERT INTO dw.fato_precificacao_categoria (sk_prestador, sk_categoria_servico, valor_medio_cobrado)
                VALUES (rec.sk_prestador, v_cat, round((80 + random() * 820)::numeric, 2));
            END IF;
        END LOOP;
    END LOOP;
END $$;

-- ---------------------------------------------------------------------
-- fato_assinatura_plano (snapshot do plano vigente por prestador)
-- ---------------------------------------------------------------------
INSERT INTO dw.fato_assinatura_plano (sk_prestador, sk_plano, sk_tempo_inicio, limite_clientes_mensal, valor_mensalidade, qtd_pedidos_recebidos_mes_atual)
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
    FROM dw.fato_orcamento fo
    JOIN dw.dim_tempo dt ON dt.sk_tempo = fo.sk_tempo_criacao
    WHERE (dt.ano, dt.mes) = (
        SELECT dt2.ano, dt2.mes
        FROM dw.fato_orcamento fo2
        JOIN dw.dim_tempo dt2 ON dt2.sk_tempo = fo2.sk_tempo_criacao
        ORDER BY dt2.data DESC
        LIMIT 1
    )
    GROUP BY fo.sk_prestador
) m ON m.sk_prestador = p.sk_prestador;

-- ---------------------------------------------------------------------
-- Atualiza a reputação do prestador (avaliacao_media / qtd_avaliacoes)
-- a partir do fato de avaliações, mantendo dw.dim_prestador consistente
-- ---------------------------------------------------------------------
UPDATE dw.dim_prestador p
SET avaliacao_media = a.media_nota,
    qtd_avaliacoes = a.qtd
FROM (
    SELECT sk_prestador, round(avg(nota), 2) AS media_nota, count(*) AS qtd
    FROM dw.fato_avaliacao
    GROUP BY sk_prestador
) a
WHERE a.sk_prestador = p.sk_prestador;
