-- =====================================================================
-- Prestador Nota 10 - Data Warehouse
-- 01_dimensoes_conformadas.sql
--
-- Dimensões conformadas (compartilhadas por todos os datamarts).
-- dim_tempo, dim_cidade e dim_categoria_servico são carregadas a partir
-- dos dados mestres/de referência já existentes no schema operacional
-- (public.cidade, public.estado, public.categoria_servico), pois são
-- dados de apoio (não transacionais) legítimos para reaproveitar.
-- As demais dimensões (situações e forma de pagamento) refletem os
-- enums de domínio do código-fonte da API (SituacaoPedido,
-- SituacaoOrcamento, FormaPagamento). dim_plano é sintética, pois a
-- tabela public.plano está vazia na base operacional.
-- =====================================================================

-- ---------------------------------------------------------------------
-- dim_tempo
-- ---------------------------------------------------------------------
CREATE TABLE dw.dim_tempo (
    sk_tempo         integer PRIMARY KEY,
    data             date NOT NULL UNIQUE,
    ano              smallint NOT NULL,
    trimestre        smallint NOT NULL,
    mes              smallint NOT NULL,
    nome_mes         varchar(20) NOT NULL,
    dia              smallint NOT NULL,
    dia_semana       smallint NOT NULL, -- 0=domingo .. 6=sábado
    nome_dia_semana  varchar(20) NOT NULL,
    semana_ano       smallint NOT NULL,
    fim_de_semana    boolean NOT NULL
);
COMMENT ON TABLE dw.dim_tempo IS 'Dimensão de tempo em grão diário, de 2022-01-01 a 2026-12-31';

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
CREATE TABLE dw.dim_cidade (
    sk_cidade    serial PRIMARY KEY,
    codigo_cidade integer NOT NULL UNIQUE,
    nome_cidade  varchar(200) NOT NULL,
    uf           char(2) NOT NULL,
    nome_estado  varchar(100) NOT NULL,
    regiao       varchar(20) NOT NULL
);
COMMENT ON TABLE dw.dim_cidade IS 'Dimensão geográfica derivada de public.cidade/public.estado';

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
FROM public.cidade c
JOIN public.estado e ON e.codigo = c.codigo_estado
WHERE COALESCE(c.deletado, false) = false;

-- ---------------------------------------------------------------------
-- dim_categoria_servico
-- ---------------------------------------------------------------------
CREATE TABLE dw.dim_categoria_servico (
    sk_categoria_servico     serial PRIMARY KEY,
    codigo_categoria         integer NOT NULL UNIQUE,
    descricao                varchar(200) NOT NULL,
    codigo_categoria_pai     integer,
    descricao_categoria_pai  varchar(200),
    nivel                    varchar(15) NOT NULL CHECK (nivel IN ('CATEGORIA', 'SUBCATEGORIA'))
);
COMMENT ON TABLE dw.dim_categoria_servico IS 'Dimensão de categorias/subcategorias de serviço derivada de public.categoria_servico';

INSERT INTO dw.dim_categoria_servico (codigo_categoria, descricao, codigo_categoria_pai, descricao_categoria_pai, nivel)
SELECT
    cs.codigo,
    cs.descricao,
    cs.codigo_categoria_pai,
    pai.descricao,
    CASE WHEN cs.codigo_categoria_pai IS NULL THEN 'CATEGORIA' ELSE 'SUBCATEGORIA' END
FROM public.categoria_servico cs
LEFT JOIN public.categoria_servico pai ON pai.codigo = cs.codigo_categoria_pai
WHERE COALESCE(cs.deletado, false) = false;

-- ---------------------------------------------------------------------
-- dim_situacao_pedido (enum SituacaoPedido)
-- ---------------------------------------------------------------------
CREATE TABLE dw.dim_situacao_pedido (
    sk_situacao_pedido serial PRIMARY KEY,
    situacao           varchar(40) NOT NULL UNIQUE,
    descricao          varchar(120) NOT NULL,
    ordem_fluxo        smallint NOT NULL,
    encerra_pedido     boolean NOT NULL
);
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
CREATE TABLE dw.dim_situacao_orcamento (
    sk_situacao_orcamento serial PRIMARY KEY,
    situacao              varchar(40) NOT NULL UNIQUE,
    descricao             varchar(120) NOT NULL
);
INSERT INTO dw.dim_situacao_orcamento (situacao, descricao) VALUES
    ('NOVO',               'Orçamento enviado pelo prestador, aguardando análise'),
    ('AGUARDANDO_CLIENTE',  'Orçamento em negociação, aguardando decisão do cliente'),
    ('ACEITO',              'Orçamento aceito pelo cliente'),
    ('FINALIZADO',          'Orçamento vinculado a um pedido finalizado'),
    ('CANCELADO',           'Orçamento recusado/cancelado');

-- ---------------------------------------------------------------------
-- dim_forma_pagamento (enum FormaPagamento)
-- ---------------------------------------------------------------------
CREATE TABLE dw.dim_forma_pagamento (
    sk_forma_pagamento serial PRIMARY KEY,
    forma              varchar(20) NOT NULL UNIQUE,
    descricao          varchar(60) NOT NULL
);
INSERT INTO dw.dim_forma_pagamento (forma, descricao) VALUES
    ('PIX',      'Pagamento instantâneo via PIX'),
    ('CARTAO',   'Pagamento com cartão de crédito/débito'),
    ('DINHEIRO', 'Pagamento em espécie');

-- ---------------------------------------------------------------------
-- dim_plano (planos comerciais dos prestadores) - sintética
-- ---------------------------------------------------------------------
CREATE TABLE dw.dim_plano (
    sk_plano               serial PRIMARY KEY,
    codigo_plano           integer NOT NULL UNIQUE,
    descricao              varchar(60) NOT NULL,
    limite_clientes_mensal integer NOT NULL,
    valor_mensalidade      numeric(10,2) NOT NULL,
    ativo                  boolean NOT NULL DEFAULT true
);
INSERT INTO dw.dim_plano (codigo_plano, descricao, limite_clientes_mensal, valor_mensalidade) VALUES
    (1, 'BASICO',       10, 49.90),
    (2, 'PROFISSIONAL', 30, 99.90),
    (3, 'PREMIUM',      100, 199.90);
