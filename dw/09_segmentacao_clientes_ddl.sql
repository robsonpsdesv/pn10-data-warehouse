-- =====================================================================
-- Prestador Nota 10 - Data Warehouse
-- 09_segmentacao_clientes_ddl.sql
--
-- Tabela de destino da clusterização de clientes (etapa de Ensemble:
-- Clusterização + Regras de Associação). É POPULADA pelo script Python
-- mining/clusterizacao/segmentar_clientes.py (K-Means sobre features de
-- comportamento de compra extraídas do DW), não por este arquivo.
-- Este script apenas garante a estrutura (idempotente).
-- =====================================================================

DROP TABLE IF EXISTS dw.dim_cliente_segmento;

CREATE TABLE dw.dim_cliente_segmento (
    sk_cliente               integer PRIMARY KEY REFERENCES dw.dim_cliente(sk_cliente),
    cluster                  smallint NOT NULL,
    rotulo_segmento          varchar(60) NOT NULL,
    qtd_pedidos              integer NOT NULL,
    valor_total              numeric(12,2) NOT NULL,
    valor_medio_pedido       numeric(12,2) NOT NULL,
    qtd_categorias_distintas integer NOT NULL,
    taxa_cancelamento        numeric(5,4) NOT NULL,
    nota_media               numeric(3,2),
    recencia_dias            integer,
    data_execucao             timestamp NOT NULL DEFAULT now()
);
COMMENT ON TABLE dw.dim_cliente_segmento IS 'Resultado da clusterização de clientes (K-Means) usada como entrada para a mineração de regras de associação por segmento. Populada por mining/clusterizacao/segmentar_clientes.py.';
COMMENT ON COLUMN dw.dim_cliente_segmento.cluster IS 'Índice numérico do cluster (0..k-1) retornado pelo K-Means';
COMMENT ON COLUMN dw.dim_cliente_segmento.rotulo_segmento IS 'Rótulo de negócio atribuído ao cluster (ex: Alto Valor, Em Risco de Churn, Ocasional, Novo Cliente)';

CREATE INDEX IF NOT EXISTS idx_dim_cliente_segmento_cluster
    ON dw.dim_cliente_segmento (cluster);
