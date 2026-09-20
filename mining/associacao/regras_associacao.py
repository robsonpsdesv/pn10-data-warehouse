"""
Prestador Nota 10 — Módulo de Mineração de Regras de Associação
Algoritmos: Apriori e FP-Growth (Market Basket Analysis)

Objetivo de Negócio:
Identificar padrões e regras de associação entre categorias e subcategorias de serviços
contratados por clientes, combinações frequentes e afinidade por perfil regional/prestador.

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

def carregar_dados_dw(db_uri=None):
    """
    Carrega as transações do banco PostgreSQL (DW) ou gera a base transacional
    espelhada a partir das categorias e perfis do DW.
    """
    if db_uri is None:
        db_uri = os.getenv(
            "DATABASE_URL", 
            "postgresql://postgres:postgres@localhost:5433/prestadornota10local"
        )
    
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
            cat.descricao_categoria_pai AS macro_categoria
        FROM dw.fato_pedido fp
        JOIN dw.dim_cliente c ON fp.sk_cliente = c.sk_cliente
        JOIN dw.dim_cidade cid ON fp.sk_cidade = cid.sk_cidade
        JOIN dw.dim_categoria_servico cat ON fp.sk_categoria_servico = cat.sk_categoria_servico
        ORDER BY c.sk_cliente, fp.sk_pedido;
        """
        df = pd.read_sql(query, engine)
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
            
        for item in itens:
            rows.append({
                "sk_pedido": trans_id,
                "sk_cliente": 1000 + (trans_id % 75),
                "regiao": regiao,
                "categoria_servico": item
            })
            
    df = pd.DataFrame(rows)
    return df

def extrair_cestas_compras(df):
    """
    Agrupa os serviços por cliente/transação para formar a cesta de compras.
    """
    transacoes = df.groupby("sk_cliente")["categoria_servico"].apply(lambda s: list(set(s))).tolist()
    return transacoes

def minerar_regras(transacoes, min_support=0.08, min_threshold_lift=1.1, algoritmo="fpgrowth"):
    """
    Executa a mineração de itemsets frequentes e gera regras de associação.
    """
    te = TransactionEncoder()
    te_ary = te.fit(transacoes).transform(transacoes)
    df_encoded = pd.DataFrame(te_ary, columns=te.columns_)

    print(f"\n--- Executando Mineração de Padrões Frequentes ({algoritmo.upper()}) ---")
    if algoritmo == "fpgrowth":
        frequent_itemsets = fpgrowth(df_encoded, min_support=min_support, use_colnames=True)
    else:
        frequent_itemsets = apriori(df_encoded, min_support=min_support, use_colnames=True)

    frequent_itemsets['length'] = frequent_itemsets['itemsets'].apply(lambda x: len(x))
    print(f"Itemsets frequentes encontrados (suporte mínimo >= {min_support*100:.1f}%): {len(frequent_itemsets)}")

    if len(frequent_itemsets) == 0:
        print("Nenhum itemset encontrado com o suporte fornecido. Tente diminuir min_support.")
        return pd.DataFrame(), frequent_itemsets

    # Geração das regras de associação
    rules = association_rules(frequent_itemsets, metric="lift", min_threshold=min_threshold_lift)
    
    if len(rules) > 0:
        rules['antecedents_str'] = rules['antecedents'].apply(lambda x: ', '.join(list(x)))
        rules['consequents_str'] = rules['consequents'].apply(lambda x: ', '.join(list(x)))
        rules = rules.sort_values(by="lift", ascending=False)
        
    return rules, frequent_itemsets

def exibir_e_salvar_relatorio(rules, output_dir="mining/associacao"):
    """
    Exibe a tabela formatada de regras e exporta para CSV e Markdown.
    """
    os.makedirs(output_dir, exist_ok=True)
    
    if len(rules) == 0:
        print("Nenhuma regra forte gerada para os thresholds definidos.")
        return

    cols_exibicao = [
        "antecedents_str", "consequents_str", "support", "confidence", "lift", "leverage", "conviction"
    ]
    df_report = rules[cols_exibicao].copy()
    df_report.columns = [
        "Se o Cliente Contratou (SE)", 
        "Também Contrata (ENTÃO)", 
        "Suporte", 
        "Confiança", 
        "Lift", 
        "Alavancagem", 
        "Convicção"
    ]

    # Formatação numérica
    for col in ["Suporte", "Confiança"]:
        df_report[col] = df_report[col].apply(lambda x: f"{x*100:.2f}%")
    for col in ["Lift", "Alavancagem", "Convicção"]:
        df_report[col] = df_report[col].apply(lambda x: f"{x:.3f}" if pd.notnull(x) else "inf")

    print("\n" + "="*80)
    print("PRINCIPAIS REGRAS DE ASSOCIAÇÃO DESCOBERTAS (ORDENADAS POR LIFT)")
    print("="*80)
    print(tabulate(df_report.head(15), headers="keys", tablefmt="grid", showindex=False))

    # Salva em CSV e Markdown
    csv_path = os.path.join(output_dir, "regras_descobertas.csv")
    md_path = os.path.join(output_dir, "relatorio_regras.md")
    
    df_report.to_csv(csv_path, index=False, encoding="utf-8-sig")
    
    with open(md_path, "w", encoding="utf-8") as f:
        f.write("# Relatório de Mineração de Regras de Associação — Prestador Nota 10\n\n")
        f.write("Este relatório resume os padrões de contratação simultânea de serviços identificados via **FP-Growth** e **Apriori**.\n\n")
        f.write("### Conceitos das Métricas:\n")
        f.write("- **Suporte**: Percentual de transações em que os itens aparecem juntos.\n")
        f.write("- **Confiança**: Probabilidade de o cliente contratar o item consequente dado que contratou o antecedente.\n")
        f.write("- **Lift**: Força da regra em relação ao acaso. Lift > 1.0 indica forte correlação positiva.\n\n")
        f.write("### Tabela de Regras Extraídas:\n\n")
        f.write(df_report.head(20).to_markdown(index=False))
        f.write("\n\n### Aplicação Prática no Produto:\n")
        f.write("1. **Cross-Selling Inteligente**: Recomendar serviços complementares no momento em que o cliente abre o pedido.\n")
        f.write("2. **Pacotes Promocionais (Combos)**: Criar ofertas de combos de serviços com alta afinidade (ex: Ar Condicionado + Limpeza + Parte Elétrica).\n")

    print(f"\n[OK] Relatórios salvos em:\n  - {csv_path}\n  - {md_path}")

if __name__ == "__main__":
    print("=================================================================")
    print("  MINERAÇÃO DE REGRAS DE ASSOCIAÇÃO — PRESTADOR NOTA 10")
    print("=================================================================")
    df_transacoes = carregar_dados_dw()
    cestas = extrair_cestas_compras(df_transacoes)
    print(f"Total de cestas/clientes analisados: {len(cestas)}")

    # Executa FP-Growth
    regras, itemsets = minerar_regras(cestas, min_support=0.08, min_threshold_lift=1.15, algoritmo="fpgrowth")
    exibir_e_salvar_relatorio(regras)
