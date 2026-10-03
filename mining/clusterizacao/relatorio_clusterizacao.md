# Relatório de Clusterização (Segmentação) de Clientes — Prestador Nota 10

### Objetivo:
Segmentar os clientes em grupos homogêneos de comportamento de compra via **K-Means**, para que a mineração de Regras de Associação seja feita **por segmento** (ver `mining/associacao/relatorio_regras.md`).

### Features utilizadas:
- Numéricas (padronizadas via `StandardScaler`): qtd_pedidos, valor_total, valor_medio_pedido, qtd_categorias_distintas, taxa_cancelamento, nota_media, recencia_dias
- Categóricas (`OneHotEncoder`): tipo_pessoa, regiao

### Seleção de k:
Testado k de 2 a 8; escolhido **k = 2** pelo maior Silhouette Score (0.217). Ver `elbow_silhouette.png` e `comparativo_k.csv`.

### Perfil dos clusters (médias por grupo):

|   cluster |   qtd_pedidos |   valor_total |   valor_medio_pedido |   qtd_categorias_distintas |   taxa_cancelamento |   nota_media |   recencia_dias |   qtd_clientes | rotulo_segmento              |
|----------:|--------------:|--------------:|---------------------:|---------------------------:|--------------------:|-------------:|----------------:|---------------:|:-----------------------------|
|         0 |          1.8  |        803.69 |               475.32 |                       1.78 |                0.19 |         4.24 |          813.03 |            154 | Inativos / Baixo Engajamento |
|         1 |          4.25 |       2186.42 |               542.24 |                       4.17 |                0.16 |         4.09 |          394.99 |            123 | Clientes Fiéis / Alto Valor  |

### Ações de CRM/Marketing sugeridas por segmento:
- **Clientes Fiéis / Alto Valor**: programas de fidelidade, atendimento prioritário.
- **Em Risco (Alto Cancelamento)**: ação de recuperação, contato proativo do suporte.
- **Inativos / Baixo Engajamento**: campanhas de reativação, cupons de retorno.
- **Frequentes / Ticket Baixo**: cross-sell de serviços complementares (ver regras por segmento).
- **Ocasionais**: campanhas de awareness e indicação.
