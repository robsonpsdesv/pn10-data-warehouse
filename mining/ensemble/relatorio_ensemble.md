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
| Random Forest (Bagging)          | 0.792 (±0.039)            | 84.80%             | 78.26%     | 35.29%   | 48.65%     |             0.832 |
| Gradient Boosting (Boosting)     | 0.784 (±0.040)            | 85.20%             | 70.59%     | 47.06%   | 56.47%     |             0.822 |
| AdaBoost (Adaptive Boosting)     | 0.783 (±0.043)            | 85.60%             | 74.19%     | 45.10%   | 56.10%     |             0.818 |
| Voting Ensemble (Soft Voting)    | 0.797 (±0.035)            | 85.60%             | 75.86%     | 43.14%   | 55.00%     |             0.834 |
| Stacking Ensemble (Meta-Learner) | 0.800 (±0.035)            | 85.60%             | 75.86%     | 43.14%   | 55.00%     |             0.835 |

**Melhor Modelo**: `Stacking Ensemble (Meta-Learner)` com ROC-AUC de `0.835` no conjunto de teste.

### Conclusões e Ações Recomendadas de Negócio:
1. **Gatilho de Alerta de Churn**: Disparar notificações push para prestadores quando um pedido estiver há mais de 24h sem orçamento.
2. **Incentivo de Resposta Rápida**: Bonificar prestadores que respondem orçamentos nos primeiros 30 minutos.
3. **Integração Operacional**: Inserir o score de risco do modelo na fila de triagem de pedidos da plataforma.
