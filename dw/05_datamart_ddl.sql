-- =====================================================================
-- Prestador Nota 10 - Data Warehouse
-- 05_datamart_ddl.sql
--
-- PASSO 3 (Datamart) - Etapa 1/2: estrutura (DDL).
--
-- Mudança de arquitetura: os datamarts NÃO guardam mais cópias das
-- tabelas fato em grão fino. Cada schema de datamart contém apenas
-- tabelas de RESUMO (agregações/rollups) construídas a partir das
-- tabelas fato do schema `dw` (ver 06_datamart_carga.sql), prontas para
-- consumo direto por ferramentas de BI ou como insumo para as próximas
-- etapas do pipeline (regras de associação, ensemble).
--
-- Execução idempotente: os schemas são recriados do zero (DROP CASCADE).
-- Pré-requisito: 03_dw_ddl.sql + 04_dw_carga.sql já executados.
-- =====================================================================

DROP SCHEMA IF EXISTS dm_planos CASCADE;
DROP SCHEMA IF EXISTS dm_prestadores CASCADE;
DROP SCHEMA IF EXISTS dm_agendamentos CASCADE;
DROP SCHEMA IF EXISTS dm_avaliacoes CASCADE;
DROP SCHEMA IF EXISTS dm_orcamentos CASCADE;
DROP SCHEMA IF EXISTS dm_pedidos CASCADE;

CREATE SCHEMA dm_pedidos;
CREATE SCHEMA dm_orcamentos;
CREATE SCHEMA dm_avaliacoes;
CREATE SCHEMA dm_agendamentos;
CREATE SCHEMA dm_prestadores;
CREATE SCHEMA dm_planos;

COMMENT ON SCHEMA dm_pedidos      IS 'Datamart: resumos do ciclo de vida operacional dos pedidos de serviço';
COMMENT ON SCHEMA dm_orcamentos   IS 'Datamart: resumos de orçamentos/propostas comerciais enviados por prestadores';
COMMENT ON SCHEMA dm_avaliacoes   IS 'Datamart: resumos de satisfação do cliente e reputação dos prestadores';
COMMENT ON SCHEMA dm_agendamentos IS 'Datamart: resumos de agenda e execução do atendimento';
COMMENT ON SCHEMA dm_prestadores  IS 'Datamart: resumos de perfil e precificação dos prestadores';
COMMENT ON SCHEMA dm_planos       IS 'Datamart: resumos de assinaturas e planos comerciais';

-- =====================================================================
-- dm_pedidos: resumos do fato dw.fato_pedido
-- =====================================================================

CREATE TABLE dm_pedidos.resumo_pedido_mes_categoria (
    ano                          smallint NOT NULL,
    mes                          smallint NOT NULL,
    sk_categoria_servico         integer NOT NULL REFERENCES dw.dim_categoria_servico(sk_categoria_servico),
    categoria_servico            varchar(200) NOT NULL,
    categoria_pai                varchar(200),
    sk_situacao_pedido           integer NOT NULL REFERENCES dw.dim_situacao_pedido(sk_situacao_pedido),
    situacao                     varchar(40) NOT NULL,
    qtd_pedidos                  integer NOT NULL,
    valor_medio_orcamento        numeric(10,2),
    dias_medio_finalizacao       numeric(6,1),
    qtd_avaliados                integer NOT NULL,
    nota_media                   numeric(3,2),
    PRIMARY KEY (ano, mes, sk_categoria_servico, sk_situacao_pedido)
);
COMMENT ON TABLE dm_pedidos.resumo_pedido_mes_categoria IS 'Resumo mensal de pedidos por categoria e situação (grão = ano/mês/categoria/situação)';

CREATE TABLE dm_pedidos.resumo_pedido_regiao (
    regiao                  varchar(20) NOT NULL PRIMARY KEY,
    qtd_pedidos             integer NOT NULL,
    ticket_medio            numeric(10,2),
    taxa_cancelamento       numeric(5,2) NOT NULL,
    nota_media              numeric(3,2),
    dias_medio_finalizacao  numeric(6,1)
);
COMMENT ON TABLE dm_pedidos.resumo_pedido_regiao IS 'Resumo de pedidos por região geográfica de atendimento (grão = região)';

-- =====================================================================
-- dm_orcamentos: resumos do fato dw.fato_orcamento
-- =====================================================================

CREATE TABLE dm_orcamentos.resumo_orcamento_prestador (
    sk_prestador           integer NOT NULL PRIMARY KEY REFERENCES dw.dim_prestador(sk_prestador),
    prestador              varchar(150) NOT NULL,
    plano                  varchar(60) NOT NULL,
    qtd_orcamentos_enviados integer NOT NULL,
    qtd_selecionados        integer NOT NULL,
    taxa_conversao          numeric(5,2) NOT NULL,
    valor_medio             numeric(10,2),
    valor_medio_selecionado numeric(10,2)
);
COMMENT ON TABLE dm_orcamentos.resumo_orcamento_prestador IS 'Resumo de orçamentos enviados e taxa de conversão por prestador (grão = prestador)';

CREATE TABLE dm_orcamentos.resumo_orcamento_categoria (
    sk_categoria_servico integer NOT NULL PRIMARY KEY REFERENCES dw.dim_categoria_servico(sk_categoria_servico),
    categoria_servico    varchar(200) NOT NULL,
    qtd_orcamentos       integer NOT NULL,
    valor_medio          numeric(10,2),
    taxa_selecao         numeric(5,2) NOT NULL
);
COMMENT ON TABLE dm_orcamentos.resumo_orcamento_categoria IS 'Resumo de orçamentos por categoria de serviço (grão = categoria)';

-- =====================================================================
-- dm_avaliacoes: resumos do fato dw.fato_avaliacao
-- =====================================================================

CREATE TABLE dm_avaliacoes.resumo_avaliacao_categoria (
    sk_categoria_servico  integer NOT NULL PRIMARY KEY REFERENCES dw.dim_categoria_servico(sk_categoria_servico),
    categoria_servico     varchar(200) NOT NULL,
    qtd_avaliacoes        integer NOT NULL,
    nota_media            numeric(3,2),
    qtd_nota_1            integer NOT NULL,
    qtd_nota_2            integer NOT NULL,
    qtd_nota_3            integer NOT NULL,
    qtd_nota_4            integer NOT NULL,
    qtd_nota_5            integer NOT NULL,
    pct_nota_acima_media  numeric(5,2) NOT NULL
);
COMMENT ON TABLE dm_avaliacoes.resumo_avaliacao_categoria IS 'Resumo de avaliações e distribuição de notas por categoria de serviço (grão = categoria)';

CREATE TABLE dm_avaliacoes.resumo_avaliacao_prestador (
    sk_prestador   integer NOT NULL PRIMARY KEY REFERENCES dw.dim_prestador(sk_prestador),
    prestador      varchar(150) NOT NULL,
    qtd_avaliacoes integer NOT NULL,
    nota_media     numeric(3,2)
);
COMMENT ON TABLE dm_avaliacoes.resumo_avaliacao_prestador IS 'Resumo de avaliações por prestador (grão = prestador)';

-- =====================================================================
-- dm_agendamentos: resumos do fato dw.fato_agendamento
-- =====================================================================

CREATE TABLE dm_agendamentos.resumo_agendamento_mes (
    ano                        smallint NOT NULL,
    mes                        smallint NOT NULL,
    qtd_agendamentos           integer NOT NULL,
    duracao_media_minutos     numeric(6,1),
    taxa_reagendamento         numeric(5,2) NOT NULL,
    dias_antecedencia_media    numeric(6,1),
    PRIMARY KEY (ano, mes)
);
COMMENT ON TABLE dm_agendamentos.resumo_agendamento_mes IS 'Resumo mensal de agendamentos (grão = ano/mês)';

CREATE TABLE dm_agendamentos.resumo_agendamento_prestador (
    sk_prestador           integer NOT NULL PRIMARY KEY REFERENCES dw.dim_prestador(sk_prestador),
    prestador              varchar(150) NOT NULL,
    qtd_agendamentos       integer NOT NULL,
    duracao_media_minutos numeric(6,1),
    taxa_reagendamento     numeric(5,2) NOT NULL
);
COMMENT ON TABLE dm_agendamentos.resumo_agendamento_prestador IS 'Resumo de agendamentos por prestador (grão = prestador)';

-- =====================================================================
-- dm_prestadores: resumos do fato dw.fato_precificacao_categoria
-- =====================================================================

CREATE TABLE dm_prestadores.resumo_prestador_categoria (
    sk_categoria_servico integer NOT NULL PRIMARY KEY REFERENCES dw.dim_categoria_servico(sk_categoria_servico),
    categoria_servico    varchar(200) NOT NULL,
    qtd_prestadores      integer NOT NULL,
    valor_medio_cobrado  numeric(10,2),
    valor_min_cobrado    numeric(10,2),
    valor_max_cobrado    numeric(10,2)
);
COMMENT ON TABLE dm_prestadores.resumo_prestador_categoria IS 'Resumo de prestadores e precificação por categoria de serviço (grão = categoria)';

CREATE TABLE dm_prestadores.resumo_prestador_regiao (
    regiao          varchar(20) NOT NULL PRIMARY KEY,
    qtd_prestadores integer NOT NULL,
    nota_media      numeric(3,2)
);
COMMENT ON TABLE dm_prestadores.resumo_prestador_regiao IS 'Resumo de prestadores por região geográfica (grão = região)';

-- =====================================================================
-- dm_planos: resumos do fato dw.fato_assinatura_plano
-- =====================================================================

CREATE TABLE dm_planos.resumo_plano (
    sk_plano                        integer NOT NULL PRIMARY KEY REFERENCES dw.dim_plano(sk_plano),
    plano                           varchar(60) NOT NULL,
    qtd_prestadores                 integer NOT NULL,
    receita_mensal_estimada         numeric(12,2) NOT NULL,
    nota_media_prestadores          numeric(3,2),
    qtd_pedidos_recebidos_mes_total integer NOT NULL
);
COMMENT ON TABLE dm_planos.resumo_plano IS 'Resumo de assinaturas por plano comercial (grão = plano)';
