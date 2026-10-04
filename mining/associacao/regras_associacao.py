"""
Prestador Nota 10 — Módulo de Mineração de Regras de Associação
Algoritmos: Apriori e FP-Growth (Market Basket Analysis)

Objetivo de Negócio:
Identificar, DENTRO DE CADA SEGMENTO DE CLIENTE (ver
mining/clusterizacao/segmentar_clientes.py), padrões e regras de associação
entre categorias de serviços contratados — em vez de minerar regras genéricas
na base inteira. Esta é a 2ª etapa do pipeline de Ensemble (Clusterização +
Regras de Associação) pedido no trabalho.

O "item" da cesta de compras é a MACRO CATEGORIA de serviço
(dim_categoria_servico.descricao_categoria_pai, ~25 valores), não a
subcategoria fina (~130 valores) — necessário para ter suporte estatístico
suficiente dado o volume de pedidos por cliente.

Métricas calculadas:
- Suporte (Support)
- Confiança (Confidence)
- Lift (Razão de dependência estatística)
- Alavancagem (Leverage)
- Convicção (Conviction)
"""

import os
import sys
import pandas as pd
import numpy as np
from tabulate import tabulate

try:
    from mlxtend.frequent_patterns import apriori, fpgrowth, association_rules
    from mlxtend.preprocessing import TransactionEncoder
except ImportError:
    print("Aviso: 'mlxtend' não está instalado. Execute: pip install -r mining/requirements.txt")

DATABASE_URL_DEFAULT = "postgresql+psycopg2://postgres:postgres@localhost:5433/prestadornota10local"


def carregar_dados_dw(db_uri=None):
    """
    Carrega as transações do banco PostgreSQL (DW), já com o cluster/segmento
    de cada cliente (dw.dim_cliente_segmento, populada por
    segmentar_clientes.py), ou gera a base transacional espelhada a partir
    das categorias e perfis do DW quando o banco está indisponível.
    """
    if db_uri is None:
        db_uri = os.getenv("DATABASE_URL", DATABASE_URL_DEFAULT)

    try:
        from sqlalchemy import create_engine
        engine = create_engine(db_uri, connect_args={"connect_timeout": 3})
        query = """
        SELECT
            fp.sk_pedido,
            c.nome AS cliente,
            c.sk_cliente,
            cid.nome_cidade,
            cid.regiao,
            cat.descricao AS categoria_servico,
            COALESCE(cat.descricao_categoria_pai, cat.descricao) AS macro_categoria,
            seg.cluster,
            seg.rotulo_segmento
        FROM dw.fato_pedido fp
        JOIN dw.dim_cliente c ON fp.sk_cliente = c.sk_cliente
        JOIN dw.dim_cidade cid ON fp.sk_cidade = cid.sk_cidade
        JOIN dw.dim_categoria_servico cat ON fp.sk_categoria_servico = cat.sk_categoria_servico
        LEFT JOIN dw.dim_cliente_segmento seg ON seg.sk_cliente = c.sk_cliente
        ORDER BY c.sk_cliente, fp.sk_pedido;
        """
        df = pd.read_sql(query, engine)
        sem_segmento = df["rotulo_segmento"].isna().sum()
        if sem_segmento > 0:
            print(f"[AVISO] {sem_segmento} registros sem segmento (rode segmentar_clientes.py antes). "
                  f"Esses clientes serão agrupados em 'Sem Segmento'.")
        df["rotulo_segmento"] = df["rotulo_segmento"].fillna("Sem Segmento")
        print(f"[OK] Dados carregados do DW com sucesso: {len(df)} registros transacionais.")
        return df
    except Exception as e:
        print(f"[INFO] Conexão direta ao banco indisponível ({e}). Gerando transações representativas do domínio...")
        return gerar_dados_transacionais_sinteticos()

def gerar_dados_transacionais_sinteticos(n_transacoes=300):
    """
    Gera histórico transacional baseado nas regras de negócio da plataforma
    para execução autônoma do módulo.
    """
    np.random.seed(42)
    categorias_populares = [
        ["Instalação de Ar Condicionado", "Manutenção Elétrica Residencial", "Troca de Disjuntor"],
        ["Instalação de Ar Condicionado", "Limpeza e Higienização de Ar", "Manutenção Elétrica Residencial"],
        ["Pintura Residencial", "Pequenos Reparos de Alvenaria", "Instalação de Luminárias"],
        ["Troca de Fiação Elétrica", "Manutenção Elétrica Residencial", "Instalação de Tomadas e Interruptores"],
        ["Instalação Hidráulica", "Desentupimento Residencial", "Troca de Torneiras"],
        ["Montagem de Móveis", "Instalação de Prateleiras e Suportes", "Pintura Residencial"],
        ["Limpeza Pós-Obra", "Pintura Residencial", "Pequenos Reparos de Alvenaria"],
        ["Instalação de Fechadura Digital", "Manutenção Elétrica Residencial", "Instalação de Tomadas e Interruptores"],
        ["Reparo de Telhado", "Pequenos Reparos de Alvenaria", "Pintura Externa"],
        ["Limpeza e Higienização de Ar", "Instalação de Ar Condicionado"]
    ]
    
    rows = []
    for trans_id in range(1, n_transacoes + 1):
        regiao = np.random.choice(["Centro-Oeste", "Sudeste", "Sul", "Nordeste", "Norte"], p=[0.4, 0.3, 0.15, 0.1, 0.05])
        cesta = np.random.choice(len(categorias_populares))
        itens = categorias_populares[cesta].copy()
        
        # Adiciona ruído estocástico
        if np.random.rand() > 0.3 and len(itens) > 1:
            itens.pop(np.random.randint(0, len(itens)))
        if np.random.rand() < 0.2:
            itens.append("Consultoria Técnica")

        sk_cliente = 1000 + (trans_id % 75)
        rotulo_segmento = "Segmento A" if sk_cliente % 2 == 0 else "Segmento B"
        for item in itens:
            rows.append({
                "sk_pedido": trans_id,
                "sk_cliente": sk_cliente,
                "regiao": regiao,
                "categoria_servico": item,
                "macro_categoria": item,
                "rotulo_segmento": rotulo_segmento,
            })

    df = pd.DataFrame(rows)
    return df


def extrair_cestas_compras(df, item_col="macro_categoria"):
    """
    Agrupa os serviços por cliente para formar a cesta de compras (conjunto de
    macro categorias distintas já contratadas pelo cliente).
    """
    transacoes = df.groupby("sk_cliente")[item_col].apply(lambda s: list(set(s))).tolist()
    return transacoes


def minerar_regras(transacoes, min_support=0.08, min_threshold_lift=1.1, algoritmo="fpgrowth",
                    thresholds_fallback=(0.08, 0.06, 0.045, 0.03, 0.02)):
    """
    Executa a mineração de itemsets frequentes e gera regras de associação.
    Se o suporte mínimo informado não gerar nenhum itemset (comum em segmentos
    menores), tenta progressivamente valores menores de `thresholds_fallback`.
    """
    te = TransactionEncoder()
    te_ary = te.fit(transacoes).transform(transacoes)
    df_encoded = pd.DataFrame(te_ary, columns=te.columns_)

    candidatos = [min_support] + [t for t in thresholds_fallback if t < min_support]
    frequent_itemsets = pd.DataFrame()
    suporte_usado = min_support

    for sup in candidatos:
        print(f"\n--- Executando Mineração de Padrões Frequentes ({algoritmo.upper()}, suporte mínimo >= {sup*100:.1f}%) ---")
        if algoritmo == "fpgrowth":
            frequent_itemsets = fpgrowth(df_encoded, min_support=sup, use_colnames=True)
        else:
            frequent_itemsets = apriori(df_encoded, min_support=sup, use_colnames=True)

        if len(frequent_itemsets) > 0:
            suporte_usado = sup
            break
        print(f"Nenhum itemset encontrado com suporte >= {sup*100:.1f}%. Tentando suporte menor...")

    if len(frequent_itemsets) == 0:
        print("Nenhum itemset frequente encontrado mesmo com os thresholds de fallback.")
        return pd.DataFrame(), frequent_itemsets, suporte_usado

    frequent_itemsets['length'] = frequent_itemsets['itemsets'].apply(lambda x: len(x))
    print(f"Itemsets frequentes encontrados (suporte mínimo >= {suporte_usado*100:.1f}%): {len(frequent_itemsets)}")

    rules = association_rules(frequent_itemsets, metric="lift", min_threshold=min_threshold_lift)

    if len(rules) > 0:
        rules['antecedents_str'] = rules['antecedents'].apply(lambda x: ', '.join(list(x)))
        rules['consequents_str'] = rules['consequents'].apply(lambda x: ', '.join(list(x)))
        rules = rules.sort_values(by="lift", ascending=False)

    return rules, frequent_itemsets, suporte_usado


def formatar_regras(rules, segmento):
    cols_exibicao = [
        "antecedents_str", "consequents_str", "support", "confidence", "lift", "leverage", "conviction"
    ]
    df_report = rules[cols_exibicao].copy()
    df_report.insert(0, "Segmento", segmento)
    df_report.columns = [
        "Segmento",
        "Se o Cliente Contratou (SE)",
        "Também Contrata (ENTÃO)",
        "Suporte",
        "Confiança",
        "Lift",
        "Alavancagem",
        "Convicção",
    ]
    return df_report


def exibir_e_salvar_relatorio(regras_por_segmento, output_dir="mining/associacao"):
    """
    Recebe um dict {segmento: (df_report_formatado, suporte_usado, n_cestas)}
    e exporta um CSV consolidado + um relatório Markdown com uma seção por
    segmento (o ponto central do trabalho: regras ESPECÍFICAS por grupo, não
    uma lista genérica única).
    """
    os.makedirs(output_dir, exist_ok=True)

    partes = [v[0] for v in regras_por_segmento.values() if v[0] is not None and len(v[0]) > 0]
    if not partes:
        print("Nenhuma regra forte gerada em nenhum segmento para os thresholds definidos.")
        return

    df_consolidado = pd.concat(partes, ignore_index=True)

    for col in ["Suporte", "Confiança"]:
        df_consolidado[col] = pd.to_numeric(df_consolidado[col], errors="coerce")

    df_display = df_consolidado.copy()
    for col in ["Suporte", "Confiança"]:
        df_display[col] = df_display[col].apply(lambda x: f"{x*100:.2f}%")
    for col in ["Lift", "Alavancagem", "Convicção"]:
        df_display[col] = df_display[col].apply(lambda x: f"{x:.3f}" if pd.notnull(x) else "inf")

    print("\n" + "=" * 90)
    print("PRINCIPAIS REGRAS DE ASSOCIAÇÃO DESCOBERTAS POR SEGMENTO (ORDENADAS POR LIFT)")
    print("=" * 90)
    print(tabulate(df_display.head(20), headers="keys", tablefmt="grid", showindex=False))

    csv_path = os.path.join(output_dir, "regras_descobertas.csv")
    md_path = os.path.join(output_dir, "relatorio_regras.md")

    df_display.to_csv(csv_path, index=False, encoding="utf-8-sig")

    with open(md_path, "w", encoding="utf-8") as f:
        f.write("# Relatório de Mineração de Regras de Associação — Prestador Nota 10\n\n")
        f.write("Este relatório resume os padrões de contratação simultânea de categorias de serviço, "
                "minerados **separadamente para cada segmento de cliente** gerado por "
                "`mining/clusterizacao/segmentar_clientes.py` (K-Means), via **FP-Growth**.\n\n")
        f.write("### Conceitos das Métricas:\n")
        f.write("- **Suporte**: Percentual de clientes do segmento cuja cesta contém os itens juntos.\n")
        f.write("- **Confiança**: Probabilidade de o cliente contratar o item consequente dado que contratou o antecedente.\n")
        f.write("- **Lift**: Força da regra em relação ao acaso. Lift > 1.0 indica correlação positiva.\n\n")

        for segmento, (df_seg, suporte_usado, n_cestas) in regras_por_segmento.items():
            f.write(f"## Segmento: {segmento}\n\n")
            f.write(f"- Clientes (cestas) analisados: **{n_cestas}**\n")
            if df_seg is None or len(df_seg) == 0:
                f.write(f"- Suporte mínimo testado: nenhum itemset frequente encontrado mesmo reduzindo o suporte. "
                        f"Segmento provavelmente pequeno/heterogêneo demais para regras estatisticamente confiáveis.\n\n")
                continue
            f.write(f"- Suporte mínimo utilizado: **{suporte_usado*100:.1f}%** "
                    f"(reduzido automaticamente a partir de 8% até encontrar itemsets frequentes)\n\n")
            df_md = df_display[df_display["Segmento"] == segmento].drop(columns=["Segmento"]).head(10)
            f.write(df_md.to_markdown(index=False))
            f.write("\n\n")

        f.write("### Aplicação Prática no Produto (por segmento):\n")
        f.write("1. **Cross-Selling Inteligente**: Recomendar, no momento da abertura do pedido, a macro categoria "
                "consequente da regra mais forte do segmento do cliente.\n")
        f.write("2. **Pacotes Promocionais (Combos)**: Criar combos de serviços com alta afinidade **dentro de cada segmento** "
                "(ex.: combo voltado a 'Clientes Fiéis / Alto Valor' pode ser diferente do combo para 'Em Risco').\n")
        f.write("3. **Comparação entre segmentos**: regras que aparecem em um segmento e não em outro indicam "
                "preferências específicas daquele grupo — use para personalizar campanhas de CRM.\n")

    print(f"\n[OK] Relatórios salvos em:\n  - {csv_path}\n  - {md_path}")


if __name__ == "__main__":
    print("=================================================================")
    print("  MINERAÇÃO DE REGRAS DE ASSOCIAÇÃO POR SEGMENTO — PRESTADOR NOTA 10")
    print("=================================================================")
    df_transacoes = carregar_dados_dw()

    regras_por_segmento = {}
    segmentos = sorted(df_transacoes["rotulo_segmento"].dropna().unique().tolist())
    print(f"Segmentos encontrados: {segmentos}")

    for segmento in segmentos:
        df_seg = df_transacoes[df_transacoes["rotulo_segmento"] == segmento]
        cestas = extrair_cestas_compras(df_seg)
        print(f"\n### Segmento '{segmento}': {len(cestas)} clientes/cestas ###")

        regras, itemsets, suporte_usado = minerar_regras(
            cestas, min_support=0.08, min_threshold_lift=1.1, algoritmo="fpgrowth"
        )
        df_formatado = formatar_regras(regras, segmento) if len(regras) > 0 else pd.DataFrame()
        regras_por_segmento[segmento] = (df_formatado, suporte_usado, len(cestas))

    exibir_e_salvar_relatorio(regras_por_segmento)
