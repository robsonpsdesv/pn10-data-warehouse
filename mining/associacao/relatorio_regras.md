# Relatório de Mineração de Regras de Associação — Prestador Nota 10

Este relatório resume os padrões de contratação simultânea de serviços identificados via **FP-Growth** e **Apriori**.

### Conceitos das Métricas:
- **Suporte**: Percentual de transações em que os itens aparecem juntos.
- **Confiança**: Probabilidade de o cliente contratar o item consequente dado que contratou o antecedente.
- **Lift**: Força da regra em relação ao acaso. Lift > 1.0 indica forte correlação positiva.

### Tabela de Regras Extraídas:

| Se o Cliente Contratou (SE)                                                                     | Também Contrata (ENTÃO)                                                                         | Suporte   | Confiança   |   Lift |   Alavancagem |   Convicção |
|:------------------------------------------------------------------------------------------------|:------------------------------------------------------------------------------------------------|:----------|:------------|-------:|--------------:|------------:|
| Reparo de Telhado, Pintura Residencial, Consultoria Técnica                                     | Instalação de Luminárias, Pequenos Reparos de Alvenaria, Pintura Externa                        | 8.00%     | 75.00%      |  5.625 |         0.066 |       3.467 |
| Reparo de Telhado, Pequenos Reparos de Alvenaria, Consultoria Técnica, Pintura Residencial      | Instalação de Luminárias, Pintura Externa                                                       | 8.00%     | 75.00%      |  5.625 |         0.066 |       3.467 |
| Reparo de Telhado, Pintura Residencial, Consultoria Técnica                                     | Instalação de Luminárias, Pintura Externa                                                       | 8.00%     | 75.00%      |  5.625 |         0.066 |       3.467 |
| Instalação de Luminárias, Pintura Externa                                                       | Reparo de Telhado, Pintura Residencial, Consultoria Técnica                                     | 8.00%     | 60.00%      |  5.625 |         0.066 |       2.233 |
| Instalação de Luminárias, Pintura Externa                                                       | Reparo de Telhado, Pequenos Reparos de Alvenaria, Consultoria Técnica, Pintura Residencial      | 8.00%     | 60.00%      |  5.625 |         0.066 |       2.233 |
| Instalação de Luminárias, Pequenos Reparos de Alvenaria, Pintura Externa                        | Reparo de Telhado, Pintura Residencial, Consultoria Técnica                                     | 8.00%     | 60.00%      |  5.625 |         0.066 |       2.233 |
| Pintura Externa, Pintura Residencial, Pequenos Reparos de Alvenaria                             | Instalação de Luminárias, Reparo de Telhado, Consultoria Técnica                                | 8.00%     | 46.15%      |  4.945 |         0.064 |       1.684 |
| Instalação de Luminárias, Reparo de Telhado, Consultoria Técnica                                | Pintura Externa, Pintura Residencial, Pequenos Reparos de Alvenaria                             | 8.00%     | 85.71%      |  4.945 |         0.064 |       5.787 |
| Instalação de Luminárias, Reparo de Telhado, Pequenos Reparos de Alvenaria, Consultoria Técnica | Pintura Externa, Pintura Residencial                                                            | 8.00%     | 85.71%      |  4.945 |         0.064 |       5.787 |
| Instalação de Luminárias, Reparo de Telhado, Consultoria Técnica                                | Pintura Externa, Pintura Residencial                                                            | 8.00%     | 85.71%      |  4.945 |         0.064 |       5.787 |
| Pintura Externa, Pintura Residencial                                                            | Instalação de Luminárias, Reparo de Telhado, Consultoria Técnica                                | 8.00%     | 46.15%      |  4.945 |         0.064 |       1.684 |
| Pintura Externa, Pintura Residencial                                                            | Instalação de Luminárias, Reparo de Telhado, Pequenos Reparos de Alvenaria, Consultoria Técnica | 8.00%     | 46.15%      |  4.945 |         0.064 |       1.684 |
| Instalação de Luminárias, Pintura Externa                                                       | Reparo de Telhado, Pequenos Reparos de Alvenaria, Consultoria Técnica                           | 9.33%     | 70.00%      |  4.773 |         0.074 |       2.844 |
| Reparo de Telhado, Pequenos Reparos de Alvenaria, Consultoria Técnica                           | Instalação de Luminárias, Pintura Externa                                                       | 9.33%     | 63.64%      |  4.773 |         0.074 |       2.383 |
| Instalação de Luminárias, Pintura Residencial, Pintura Externa                                  | Reparo de Telhado, Pequenos Reparos de Alvenaria, Consultoria Técnica                           | 8.00%     | 66.67%      |  4.545 |         0.062 |       2.56  |
| Reparo de Telhado, Pequenos Reparos de Alvenaria, Consultoria Técnica                           | Instalação de Luminárias, Pintura Residencial, Pintura Externa                                  | 8.00%     | 54.55%      |  4.545 |         0.062 |       1.936 |
| Reparo de Telhado, Consultoria Técnica                                                          | Pintura Externa, Instalação de Luminárias                                                       | 9.33%     | 58.33%      |  4.375 |         0.072 |       2.08  |
| Reparo de Telhado, Consultoria Técnica                                                          | Instalação de Luminárias, Pequenos Reparos de Alvenaria, Pintura Externa                        | 9.33%     | 58.33%      |  4.375 |         0.072 |       2.08  |
| Instalação de Luminárias, Pintura Externa                                                       | Reparo de Telhado, Pequenos Reparos de Alvenaria, Pintura Residencial                           | 9.33%     | 70.00%      |  4.375 |         0.072 |       2.8   |
| Reparo de Telhado, Pintura Residencial                                                          | Instalação de Luminárias, Pequenos Reparos de Alvenaria, Pintura Externa                        | 9.33%     | 58.33%      |  4.375 |         0.072 |       2.08  |

### Aplicação Prática no Produto:
1. **Cross-Selling Inteligente**: Recomendar serviços complementares no momento em que o cliente abre o pedido.
2. **Pacotes Promocionais (Combos)**: Criar ofertas de combos de serviços com alta afinidade (ex: Ar Condicionado + Limpeza + Parte Elétrica).
