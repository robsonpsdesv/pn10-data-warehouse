-- =====================================================================
-- Prestador Nota 10 - Data Warehouse
-- 07_indices_dw.sql
--
-- Otimização de Performance: Criação de índices B-Tree e BRIN
-- para acelerar consultas analíticas, joins estrela e agregações de datamarts.
-- =====================================================================

-- =====================================================================
-- 1. ÍNDICES NA TABELA dw.fato_pedido
-- =====================================================================
CREATE INDEX IF NOT EXISTS idx_fato_pedido_tempo_abertura 
    ON dw.fato_pedido (sk_tempo_abertura);

CREATE INDEX IF NOT EXISTS idx_fato_pedido_tempo_finalizacao 
    ON dw.fato_pedido (sk_tempo_finalizacao) 
    WHERE sk_tempo_finalizacao IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_fato_pedido_cliente 
    ON dw.fato_pedido (sk_cliente);

CREATE INDEX IF NOT EXISTS idx_fato_pedido_prestador 
    ON dw.fato_pedido (sk_prestador) 
    WHERE sk_prestador IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_fato_pedido_cidade 
    ON dw.fato_pedido (sk_cidade);

CREATE INDEX IF NOT EXISTS idx_fato_pedido_categoria 
    ON dw.fato_pedido (sk_categoria_servico);

CREATE INDEX IF NOT EXISTS idx_fato_pedido_situacao 
    ON dw.fato_pedido (sk_situacao_pedido);

CREATE INDEX IF NOT EXISTS idx_fato_pedido_forma_pagto 
    ON dw.fato_pedido (sk_forma_pagamento) 
    WHERE sk_forma_pagamento IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_fato_pedido_cancelados 
    ON dw.fato_pedido (indicador_cancelado) 
    WHERE indicador_cancelado = true;

CREATE INDEX IF NOT EXISTS idx_fato_pedido_avaliados 
    ON dw.fato_pedido (indicador_avaliado, nota_avaliacao) 
    WHERE indicador_avaliado = true;


-- =====================================================================
-- 2. ÍNDICES NA TABELA dw.fato_historico_situacao_pedido
-- =====================================================================
CREATE INDEX IF NOT EXISTS idx_fato_hist_pedido 
    ON dw.fato_historico_situacao_pedido (sk_pedido);

CREATE INDEX IF NOT EXISTS idx_fato_hist_tempo 
    ON dw.fato_historico_situacao_pedido (sk_tempo);

CREATE INDEX IF NOT EXISTS idx_fato_hist_situacao 
    ON dw.fato_historico_situacao_pedido (sk_situacao_pedido);


-- =====================================================================
-- 3. ÍNDICES NA TABELA dw.fato_orcamento
-- =====================================================================
CREATE INDEX IF NOT EXISTS idx_fato_orcamento_pedido 
    ON dw.fato_orcamento (sk_pedido);

CREATE INDEX IF NOT EXISTS idx_fato_orcamento_tempo 
    ON dw.fato_orcamento (sk_tempo_criacao);

CREATE INDEX IF NOT EXISTS idx_fato_orcamento_prestador 
    ON dw.fato_orcamento (sk_prestador);

CREATE INDEX IF NOT EXISTS idx_fato_orcamento_cliente 
    ON dw.fato_orcamento (sk_cliente);

CREATE INDEX IF NOT EXISTS idx_fato_orcamento_categoria 
    ON dw.fato_orcamento (sk_categoria_servico);

CREATE INDEX IF NOT EXISTS idx_fato_orcamento_situacao 
    ON dw.fato_orcamento (sk_situacao_orcamento);

CREATE INDEX IF NOT EXISTS idx_fato_orcamento_selecionado 
    ON dw.fato_orcamento (foi_selecionado) 
    WHERE foi_selecionado = true;


-- =====================================================================
-- 4. ÍNDICES NA TABELA dw.fato_avaliacao
-- =====================================================================
CREATE INDEX IF NOT EXISTS idx_fato_avaliacao_tempo 
    ON dw.fato_avaliacao (sk_tempo);

CREATE INDEX IF NOT EXISTS idx_fato_avaliacao_prestador 
    ON dw.fato_avaliacao (sk_prestador);

CREATE INDEX IF NOT EXISTS idx_fato_avaliacao_cliente 
    ON dw.fato_avaliacao (sk_cliente);

CREATE INDEX IF NOT EXISTS idx_fato_avaliacao_categoria 
    ON dw.fato_avaliacao (sk_categoria_servico);

CREATE INDEX IF NOT EXISTS idx_fato_avaliacao_cidade 
    ON dw.fato_avaliacao (sk_cidade);

CREATE INDEX IF NOT EXISTS idx_fato_avaliacao_nota 
    ON dw.fato_avaliacao (nota);


-- =====================================================================
-- 5. ÍNDICES NA TABELA dw.fato_agendamento
-- =====================================================================
CREATE INDEX IF NOT EXISTS idx_fato_agendamento_tempo_inicio 
    ON dw.fato_agendamento (sk_tempo_inicio);

CREATE INDEX IF NOT EXISTS idx_fato_agendamento_prestador 
    ON dw.fato_agendamento (sk_prestador);

CREATE INDEX IF NOT EXISTS idx_fato_agendamento_cliente 
    ON dw.fato_agendamento (sk_cliente);

CREATE INDEX IF NOT EXISTS idx_fato_agendamento_reagendado 
    ON dw.fato_agendamento (reagendado) 
    WHERE reagendado = true;


-- =====================================================================
-- 6. ÍNDICES NAS DIMENSÕES (FILTROS E JOINS FREQUENTES)
-- =====================================================================
CREATE INDEX IF NOT EXISTS idx_dim_tempo_ano_mes 
    ON dw.dim_tempo (ano, mes);

CREATE INDEX IF NOT EXISTS idx_dim_cidade_uf_regiao 
    ON dw.dim_cidade (uf, regiao);

CREATE INDEX IF NOT EXISTS idx_dim_categoria_pai 
    ON dw.dim_categoria_servico (codigo_categoria_pai) 
    WHERE codigo_categoria_pai IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_dim_cliente_cidade 
    ON dw.dim_cliente (sk_cidade);

CREATE INDEX IF NOT EXISTS idx_dim_prestador_cidade 
    ON dw.dim_prestador (sk_cidade);

CREATE INDEX IF NOT EXISTS idx_dim_prestador_plano 
    ON dw.dim_prestador (sk_plano);
