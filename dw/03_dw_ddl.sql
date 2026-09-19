-- =====================================================================
-- Prestador Nota 10 - Data Warehouse
-- 03_dw_ddl.sql
--
-- PASSO 2 (DW) - Etapa 1/2: estrutura (DDL).
--
-- Diferente da versão anterior deste projeto, aqui as tabelas FATO ficam
-- no MESMO schema das DIMENSÕES (schema único `dw`), formando um esquema
-- estrela completo e convencional. Os datamarts (passo 3) não guardam
-- mais cópias das tabelas fato: eles serão apenas RESUMOS/AGREGAÇÕES
-- construídos a partir das tabelas fato deste schema (ver 05/06).
--
-- Execução idempotente: o schema é recriado do zero (DROP CASCADE).
-- Pré-requisito: OLTP já criado e carregado (01_oltp_ddl.sql + 02_oltp_carga.sql),
-- pois dim_cidade e dim_categoria_servico reaproveitam dados mestre de pn10.*.
-- =====================================================================

CREATE SCHEMA dw;
COMMENT ON SCHEMA dw IS 'Data Warehouse Prestador Nota 10: dimensões e fatos no mesmo schema (esquema estrela)';

-- =====================================================================
-- DIMENSÕES
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

-- ---------------------------------------------------------------------
-- dim_cidade (geografia de atendimento)
-- ---------------------------------------------------------------------
CREATE TABLE dw.dim_cidade (
    sk_cidade     serial PRIMARY KEY,
    codigo_cidade integer NOT NULL UNIQUE,
    nome_cidade   varchar(200) NOT NULL,
    uf            char(2) NOT NULL,
    nome_estado   varchar(100) NOT NULL,
    regiao        varchar(20) NOT NULL
);
COMMENT ON TABLE dw.dim_cidade IS 'Dimensão geográfica derivada de pn10.cidade/pn10.estado';

-- ---------------------------------------------------------------------
-- dim_categoria_servico
-- ---------------------------------------------------------------------
CREATE TABLE dw.dim_categoria_servico (
    sk_categoria_servico    serial PRIMARY KEY,
    codigo_categoria        integer NOT NULL UNIQUE,
    descricao               varchar(200) NOT NULL,
    codigo_categoria_pai    integer,
    descricao_categoria_pai varchar(200),
    nivel                   varchar(15) NOT NULL CHECK (nivel IN ('CATEGORIA', 'SUBCATEGORIA'))
);
COMMENT ON TABLE dw.dim_categoria_servico IS 'Dimensão de categorias/subcategorias de serviço derivada de pn10.categoria_servico';

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
COMMENT ON TABLE dw.dim_situacao_pedido IS 'Dimensão de situações do pedido (enum SituacaoPedido da API)';

-- ---------------------------------------------------------------------
-- dim_situacao_orcamento (enum SituacaoOrcamento)
-- ---------------------------------------------------------------------
CREATE TABLE dw.dim_situacao_orcamento (
    sk_situacao_orcamento serial PRIMARY KEY,
    situacao              varchar(40) NOT NULL UNIQUE,
    descricao             varchar(120) NOT NULL
);
COMMENT ON TABLE dw.dim_situacao_orcamento IS 'Dimensão de situações do orçamento (enum SituacaoOrcamento da API)';

-- ---------------------------------------------------------------------
-- dim_forma_pagamento (enum FormaPagamento)
-- ---------------------------------------------------------------------
CREATE TABLE dw.dim_forma_pagamento (
    sk_forma_pagamento serial PRIMARY KEY,
    forma              varchar(20) NOT NULL UNIQUE,
    descricao          varchar(60) NOT NULL
);
COMMENT ON TABLE dw.dim_forma_pagamento IS 'Dimensão de forma de pagamento (enum FormaPagamento da API)';

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
COMMENT ON TABLE dw.dim_plano IS 'Dimensão de planos comerciais dos prestadores (sintética)';

-- ---------------------------------------------------------------------
-- dim_cliente - sintética
-- ---------------------------------------------------------------------
CREATE TABLE dw.dim_cliente (
    sk_cliente     serial PRIMARY KEY,
    codigo_cliente integer NOT NULL UNIQUE,
    nome           varchar(150) NOT NULL,
    tipo_pessoa    varchar(2) NOT NULL CHECK (tipo_pessoa IN ('PF', 'PJ')),
    documento      varchar(20) NOT NULL,
    sk_cidade      integer NOT NULL REFERENCES dw.dim_cidade(sk_cidade),
    data_cadastro  date NOT NULL,
    ativo          boolean NOT NULL DEFAULT true
);
COMMENT ON TABLE dw.dim_cliente IS 'Dimensão de clientes (usuários que solicitam serviços) - dados sintéticos';

-- ---------------------------------------------------------------------
-- dim_prestador - sintética
-- ---------------------------------------------------------------------
CREATE TABLE dw.dim_prestador (
    sk_prestador     serial PRIMARY KEY,
    codigo_prestador integer NOT NULL UNIQUE,
    nome             varchar(150) NOT NULL,
    tipo_pessoa      varchar(2) NOT NULL CHECK (tipo_pessoa IN ('PF', 'PJ')),
    documento        varchar(20) NOT NULL,
    sk_cidade        integer NOT NULL REFERENCES dw.dim_cidade(sk_cidade),
    sk_plano         integer NOT NULL REFERENCES dw.dim_plano(sk_plano),
    avaliacao_media  numeric(3,2),
    qtd_avaliacoes   integer NOT NULL DEFAULT 0,
    data_cadastro    date NOT NULL,
    ativo            boolean NOT NULL DEFAULT true
);
COMMENT ON TABLE dw.dim_prestador IS 'Dimensão de prestadores de serviço - dados sintéticos';

-- =====================================================================
-- FATOS (agora no mesmo schema `dw` das dimensões)
-- =====================================================================

-- ---------------------------------------------------------------------
-- fato_pedido / fato_historico_situacao_pedido
-- ---------------------------------------------------------------------
CREATE TABLE dw.fato_pedido (
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
COMMENT ON TABLE dw.fato_pedido IS 'Fato: 1 linha por pedido de serviço (grão = pedido)';

CREATE TABLE dw.fato_historico_situacao_pedido (
    sk_historico                 bigserial PRIMARY KEY,
    sk_pedido                    bigint NOT NULL REFERENCES dw.fato_pedido(sk_pedido),
    codigo_pedido                integer NOT NULL,
    sk_tempo                     integer NOT NULL REFERENCES dw.dim_tempo(sk_tempo),
    sk_situacao_pedido           integer NOT NULL REFERENCES dw.dim_situacao_pedido(sk_situacao_pedido),
    sk_situacao_pedido_anterior  integer REFERENCES dw.dim_situacao_pedido(sk_situacao_pedido),
    ordem_transicao              smallint NOT NULL,
    dias_desde_situacao_anterior integer
);
COMMENT ON TABLE dw.fato_historico_situacao_pedido IS 'Fato: 1 linha por transição de situação do pedido (grão = evento de mudança de situação)';

-- ---------------------------------------------------------------------
-- fato_orcamento
-- ---------------------------------------------------------------------
CREATE TABLE dw.fato_orcamento (
    sk_orcamento            bigserial PRIMARY KEY,
    codigo_orcamento        integer NOT NULL UNIQUE,
    sk_pedido               bigint NOT NULL REFERENCES dw.fato_pedido(sk_pedido),
    codigo_pedido           integer NOT NULL,
    sk_tempo_criacao        integer NOT NULL REFERENCES dw.dim_tempo(sk_tempo),
    sk_tempo_validade       integer REFERENCES dw.dim_tempo(sk_tempo),
    sk_prestador            integer NOT NULL REFERENCES dw.dim_prestador(sk_prestador),
    sk_cliente              integer NOT NULL REFERENCES dw.dim_cliente(sk_cliente),
    sk_categoria_servico    integer NOT NULL REFERENCES dw.dim_categoria_servico(sk_categoria_servico),
    sk_situacao_orcamento   integer NOT NULL REFERENCES dw.dim_situacao_orcamento(sk_situacao_orcamento),
    solicitado_pelo_cliente boolean NOT NULL DEFAULT false,
    valor                   numeric(10,2) NOT NULL,
    foi_selecionado         boolean NOT NULL DEFAULT false,
    dias_validade           integer NOT NULL
);
COMMENT ON TABLE dw.fato_orcamento IS 'Fato: 1 linha por orçamento enviado por um prestador para um pedido (grão = orçamento)';

-- ---------------------------------------------------------------------
-- fato_avaliacao
-- ---------------------------------------------------------------------
CREATE TABLE dw.fato_avaliacao (
    sk_avaliacao              bigserial PRIMARY KEY,
    codigo_avaliacao          integer NOT NULL UNIQUE,
    sk_pedido                 bigint NOT NULL UNIQUE REFERENCES dw.fato_pedido(sk_pedido),
    codigo_pedido             integer NOT NULL,
    sk_tempo                  integer NOT NULL REFERENCES dw.dim_tempo(sk_tempo),
    sk_cliente                integer NOT NULL REFERENCES dw.dim_cliente(sk_cliente),
    sk_prestador              integer NOT NULL REFERENCES dw.dim_prestador(sk_prestador),
    sk_categoria_servico      integer NOT NULL REFERENCES dw.dim_categoria_servico(sk_categoria_servico),
    sk_cidade                 integer NOT NULL REFERENCES dw.dim_cidade(sk_cidade),
    nota                      numeric(3,1) NOT NULL CHECK (nota BETWEEN 1 AND 5),
    qtd_caracteres_comentario integer NOT NULL,
    nota_acima_media          boolean NOT NULL
);
COMMENT ON TABLE dw.fato_avaliacao IS 'Fato: 1 linha por avaliação de pedido finalizado (grão = avaliação)';

-- ---------------------------------------------------------------------
-- fato_agendamento
-- ---------------------------------------------------------------------
CREATE TABLE dw.fato_agendamento (
    sk_agendamento     bigserial PRIMARY KEY,
    codigo_agendamento integer NOT NULL UNIQUE,
    sk_pedido          bigint NOT NULL UNIQUE REFERENCES dw.fato_pedido(sk_pedido),
    codigo_pedido      integer NOT NULL,
    sk_tempo_inicio    integer NOT NULL REFERENCES dw.dim_tempo(sk_tempo),
    sk_tempo_fim       integer NOT NULL REFERENCES dw.dim_tempo(sk_tempo),
    sk_prestador       integer NOT NULL REFERENCES dw.dim_prestador(sk_prestador),
    sk_cliente         integer NOT NULL REFERENCES dw.dim_cliente(sk_cliente),
    duracao_minutos    integer NOT NULL,
    dias_antecedencia  integer NOT NULL,
    reagendado         boolean NOT NULL DEFAULT false
);
COMMENT ON TABLE dw.fato_agendamento IS 'Fato: 1 linha por agendamento de atendimento (grão = agendamento)';

-- ---------------------------------------------------------------------
-- fato_precificacao_categoria
-- ---------------------------------------------------------------------
CREATE TABLE dw.fato_precificacao_categoria (
    sk_precificacao      bigserial PRIMARY KEY,
    sk_prestador         integer NOT NULL REFERENCES dw.dim_prestador(sk_prestador),
    sk_categoria_servico integer NOT NULL REFERENCES dw.dim_categoria_servico(sk_categoria_servico),
    valor_medio_cobrado  numeric(10,2) NOT NULL,
    UNIQUE (sk_prestador, sk_categoria_servico)
);
COMMENT ON TABLE dw.fato_precificacao_categoria IS 'Fato: 1 linha por categoria de serviço atendida por um prestador (grão = prestador x categoria)';

-- ---------------------------------------------------------------------
-- fato_assinatura_plano
-- ---------------------------------------------------------------------
CREATE TABLE dw.fato_assinatura_plano (
    sk_assinatura                   bigserial PRIMARY KEY,
    sk_prestador                    integer NOT NULL UNIQUE REFERENCES dw.dim_prestador(sk_prestador),
    sk_plano                        integer NOT NULL REFERENCES dw.dim_plano(sk_plano),
    sk_tempo_inicio                 integer NOT NULL REFERENCES dw.dim_tempo(sk_tempo),
    limite_clientes_mensal          integer NOT NULL,
    valor_mensalidade               numeric(10,2) NOT NULL,
    qtd_pedidos_recebidos_mes_atual integer NOT NULL DEFAULT 0
);
COMMENT ON TABLE dw.fato_assinatura_plano IS 'Fato: 1 linha por assinatura vigente de plano do prestador (grão = prestador)';
