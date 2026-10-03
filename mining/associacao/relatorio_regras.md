# Relatório de Mineração de Regras de Associação — Prestador Nota 10

Este relatório resume os padrões de contratação simultânea de categorias de serviço, minerados **separadamente para cada segmento de cliente** gerado por `mining/clusterizacao/segmentar_clientes.py` (K-Means), via **FP-Growth**.

### Conceitos das Métricas:
- **Suporte**: Percentual de clientes do segmento cuja cesta contém os itens juntos.
- **Confiança**: Probabilidade de o cliente contratar o item consequente dado que contratou o antecedente.
- **Lift**: Força da regra em relação ao acaso. Lift > 1.0 indica correlação positiva.

## Segmento: Clientes Fiéis / Alto Valor

- Clientes (cestas) analisados: **123**
- Suporte mínimo utilizado: **8.0%** (reduzido automaticamente a partir de 8% até encontrar itemsets frequentes)

| Se o Cliente Contratou (SE)          | Também Contrata (ENTÃO)              | Suporte   | Confiança   |   Lift |   Alavancagem |   Convicção |
|:-------------------------------------|:-------------------------------------|:----------|:------------|-------:|--------------:|------------:|
| Chaveiros e ferragens                | Hidráulica                           | 10.57%    | 52.00%      |  1.39  |         0.03  |       1.304 |
| Hidráulica                           | Chaveiros e ferragens                | 10.57%    | 28.26%      |  1.39  |         0.03  |       1.111 |
| Chaveiros e ferragens                | Residencial                          | 9.76%     | 48.00%      |  1.181 |         0.015 |       1.141 |
| Residencial                          | Chaveiros e ferragens                | 9.76%     | 24.00%      |  1.181 |         0.015 |       1.048 |
| Automotivo                           | Computadores, Celulares e Tecnologia | 8.13%     | 22.73%      |  1.165 |         0.012 |       1.042 |
| Computadores, Celulares e Tecnologia | Automotivo                           | 8.13%     | 41.67%      |  1.165 |         0.012 |       1.101 |
| Hidráulica                           | Residencial                          | 17.07%    | 45.65%      |  1.123 |         0.019 |       1.092 |
| Residencial                          | Hidráulica                           | 17.07%    | 42.00%      |  1.123 |         0.019 |       1.079 |

## Segmento: Inativos / Baixo Engajamento

- Clientes (cestas) analisados: **154**
- Suporte mínimo testado: nenhum itemset frequente encontrado mesmo reduzindo o suporte. Segmento provavelmente pequeno/heterogêneo demais para regras estatisticamente confiáveis.

### Aplicação Prática no Produto (por segmento):
1. **Cross-Selling Inteligente**: Recomendar, no momento da abertura do pedido, a macro categoria consequente da regra mais forte do segmento do cliente.
2. **Pacotes Promocionais (Combos)**: Criar combos de serviços com alta afinidade **dentro de cada segmento** (ex.: combo voltado a 'Clientes Fiéis / Alto Valor' pode ser diferente do combo para 'Em Risco').
3. **Comparação entre segmentos**: regras que aparecem em um segmento e não em outro indicam preferências específicas daquele grupo — use para personalizar campanhas de CRM.
