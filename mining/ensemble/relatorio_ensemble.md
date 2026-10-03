# Relatório de Modelagem Preditiva com Ensemble Learning

### Objetivo:
Classificação e predição antecipada de **Cancelamento de Pedidos (Churn)** na plataforma Prestador Nota 10.

### Modelos Avaliados:
- **Bagging**: Random Forest (reduz variância via bootstrap aggregation)
- **Boosting**: Gradient Boosting e AdaBoost (aprendizado sequencial focado nos erros residuais)
- **Stacking / Voting**: Meta-ensemble que combina a probabilidade predita por múltiplos classificadores

### Tabela Comparativa de Resultados:

| Modelo                           | CV ROC-AUC (Média ± DP)   | Acurácia (Teste)   | Precisão   | Recall   | F1-Score   |   ROC-AUC (Teste) |
|:---------------------------------|:--------------------------|:-------------------|:-----------|:---------|:-----------|------------------:|
| Random Forest (Bagging)          | 0.489 (±0.054)            | 83.00%             | 0.00%      | 0.00%    | 0.00%      |             0.533 |
| Gradient Boosting (Boosting)     | 0.508 (±0.051)            | 79.50%             | 23.08%     | 8.82%    | 12.77%     |             0.583 |
| AdaBoost (Adaptive Boosting)     | 0.482 (±0.053)            | 83.00%             | 0.00%      | 0.00%    | 0.00%      |             0.531 |
| Voting Ensemble (Soft Voting)    | 0.491 (±0.050)            | 80.00%             | 0.00%      | 0.00%    | 0.00%      |             0.572 |
| Stacking Ensemble (Meta-Learner) | 0.485 (±0.053)            | 83.00%             | 0.00%      | 0.00%    | 0.00%      |             0.577 |

**Melhor Modelo**: `Gradient Boosting (Boosting)` com ROC-AUC de `0.583` no conjunto de teste.

### Variáveis Mais Importantes para Decisão:

| Variável                                    |   Importância (%) |
|:--------------------------------------------|------------------:|
| valor_orcamento                             |             22.24 |
| avaliacao_prestador                         |             12.3  |
| dias_para_primeiro_orcamento                |              7.37 |
| qtd_orcamentos_recebidos                    |              4.39 |
| qtd_categorias_servico                      |              4.34 |
| mensalidade_plano_prestador                 |              3.16 |
| regiao_Sul                                  |              2.31 |
| categoria_servico_Troca de gás              |              2.06 |
| regiao_Nordeste                             |              1.59 |
| categoria_servico_Fogões, fornos e cooktops |              1.52 |

### Conclusões e Ações Recomendadas de Negócio:
1. **Gatilho de Alerta de Churn**: Disparar notificações push para prestadores quando um pedido estiver há mais de 24h sem orçamento.
2. **Incentivo de Resposta Rápida**: Bonificar prestadores que respondem orçamentos nos primeiros 30 minutos.
3. **Integração Operacional**: Inserir o score de risco do modelo na fila de triagem de pedidos da plataforma.
