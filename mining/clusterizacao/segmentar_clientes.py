"""
Prestador Nota 10 — Módulo de Clusterização (Segmentação) de Clientes
Algoritmo: K-Means (seleção de k via Silhouette Score)

Objetivo de Negócio:
Segmentar a base de clientes em grupos homogêneos de comportamento de compra
(RFM + diversidade de categorias + satisfação + cancelamento), para que a
mineração de Regras de Associação (mining/associacao/regras_associacao.py)
seja aplicada SEPARADAMENTE em cada grupo, em vez de na base inteira.

Esta é a primeira etapa do pipeline de Ensemble (aprendizagem por conjuntos)
pedido no trabalho: Clusterização de Clientes -> Regras de Associação por Grupo.

Saídas:
- mining/clusterizacao/clientes_segmentados.csv  (1 linha por cliente + cluster)
- mining/clusterizacao/comparativo_k.csv          (silhouette por k testado)
- mining/clusterizacao/elbow_silhouette.png        (gráfico de apoio à escolha de k)
- mining/clusterizacao/relatorio_clusterizacao.md  (perfil de cada cluster)
- tabela dw.dim_cliente_segmento no Postgres (consumida pelo módulo de associação)
"""

import os
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from tabulate import tabulate

from sklearn.preprocessing import StandardScaler, OneHotEncoder
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline
from sklearn.cluster import KMeans
from sklearn.metrics import silhouette_score

DATABASE_URL_DEFAULT = "postgresql+psycopg2://postgres:postgres@localhost:5433/prestadornota10local"

FEATURES_NUM = [
    "qtd_pedidos", "valor_total", "valor_medio_pedido",
    "qtd_categorias_distintas", "taxa_cancelamento", "nota_media", "recencia_dias",
]
FEATURES_CAT = ["tipo_pessoa", "regiao"]


def carregar_dados_dw(db_uri=None):
    """
    Carrega, por cliente, as features de comportamento de compra (RFM + extras)
    a partir do DW PostgreSQL. Considera apenas clientes com pelo menos 1 pedido
    (clientes sem histórico de compra não têm cesta para a etapa de associação).
    """
    if db_uri is None:
        db_uri = os.getenv("DATABASE_URL", DATABASE_URL_DEFAULT)

    try:
        from sqlalchemy import create_engine
        engine = create_engine(db_uri, connect_args={"connect_timeout": 3})
        query = """
        SELECT
            c.sk_cliente,
            c.codigo_cliente,
            c.nome,
            c.tipo_pessoa,
            cid.regiao,
            COUNT(fp.sk_pedido) AS qtd_pedidos,
            COALESCE(SUM(fp.valor_orcamento_selecionado), 0) AS valor_total,
            COALESCE(AVG(fp.valor_orcamento_selecionado), 0) AS valor_medio_pedido,
            COUNT(DISTINCT fp.sk_categoria_servico) AS qtd_categorias_distintas,
            AVG(fp.indicador_cancelado::int) AS taxa_cancelamento,
            AVG(fp.nota_avaliacao) FILTER (WHERE fp.indicador_avaliado) AS nota_media,
            (CURRENT_DATE - MAX(dt.data)) AS recencia_dias
        FROM dw.dim_cliente c
        JOIN dw.fato_pedido fp ON fp.sk_cliente = c.sk_cliente
        JOIN dw.dim_tempo dt ON dt.sk_tempo = fp.sk_tempo_abertura
        JOIN dw.dim_cidade cid ON cid.sk_cidade = c.sk_cidade
        GROUP BY c.sk_cliente, c.codigo_cliente, c.nome, c.tipo_pessoa, cid.regiao
        HAVING COUNT(fp.sk_pedido) > 0;
        """
        df = pd.read_sql(query, engine)
        df["nota_media"] = df["nota_media"].fillna(df["nota_media"].mean())
        df["recencia_dias"] = df["recencia_dias"].fillna(df["recencia_dias"].max())
        print(f"[OK] Features de {len(df)} clientes carregadas do DW.")
        return df, engine
    except Exception as e:
        print(f"[INFO] Banco indisponível ({e}). Gerando dataset representativo do DW para modelagem...")
        return gerar_dataset_sintetico(), None


def gerar_dataset_sintetico(n_clientes=277):
    """Fallback para execução autônoma do módulo sem acesso ao Postgres."""
    np.random.seed(42)
    regioes = ["Centro-Oeste", "Sudeste", "Sul", "Nordeste", "Norte"]
    df = pd.DataFrame({
        "sk_cliente": range(1, n_clientes + 1),
        "codigo_cliente": range(1, n_clientes + 1),
        "nome": [f"Cliente Sintético {i}" for i in range(1, n_clientes + 1)],
        "tipo_pessoa": np.random.choice(["PF", "PJ"], n_clientes, p=[0.8, 0.2]),
        "regiao": np.random.choice(regioes, n_clientes, p=[0.35, 0.35, 0.15, 0.1, 0.05]),
        "qtd_pedidos": np.random.poisson(lam=2.8, size=n_clientes).clip(1, None),
        "valor_total": np.random.gamma(shape=5.0, scale=150.0, size=n_clientes),
        "qtd_categorias_distintas": np.random.randint(1, 6, n_clientes),
        "taxa_cancelamento": np.random.beta(1.5, 8, n_clientes),
        "nota_media": np.clip(np.random.normal(4.2, 0.6, n_clientes), 1, 5),
        "recencia_dias": np.random.exponential(scale=60, size=n_clientes).astype(int),
    })
    df["valor_medio_pedido"] = df["valor_total"] / df["qtd_pedidos"]
    return df


def escolher_k(X_transformado, k_min=2, k_max=8, output_dir="mining/clusterizacao"):
    """Testa k em [k_min, k_max], escolhe o melhor via Silhouette Score e salva o gráfico comparativo."""
    os.makedirs(output_dir, exist_ok=True)
    resultados = []
    for k in range(k_min, k_max + 1):
        km = KMeans(n_clusters=k, n_init=10, random_state=42)
        labels = km.fit_predict(X_transformado)
        sil = silhouette_score(X_transformado, labels)
        resultados.append({"k": k, "inertia": km.inertia_, "silhouette": sil})

    df_k = pd.DataFrame(resultados)
    melhor_k = int(df_k.loc[df_k["silhouette"].idxmax(), "k"])

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(11, 4))
    ax1.plot(df_k["k"], df_k["inertia"], marker="o")
    ax1.set_title("Método do Cotovelo (Inertia)")
    ax1.set_xlabel("k (nº de clusters)")
    ax1.set_ylabel("Inertia")

    ax2.plot(df_k["k"], df_k["silhouette"], marker="o", color="darkorange")
    ax2.axvline(melhor_k, color="green", linestyle="--", label=f"k escolhido = {melhor_k}")
    ax2.set_title("Silhouette Score por k")
    ax2.set_xlabel("k (nº de clusters)")
    ax2.set_ylabel("Silhouette Score")
    ax2.legend()

    fig.tight_layout()
    fig_path = os.path.join(output_dir, "elbow_silhouette.png")
    fig.savefig(fig_path, dpi=120)
    plt.close(fig)

    df_k.to_csv(os.path.join(output_dir, "comparativo_k.csv"), index=False)
    print(f"[OK] k escolhido = {melhor_k} (silhouette={df_k['silhouette'].max():.3f}). Gráfico: {fig_path}")
    return melhor_k, df_k


def rotular_cluster(perfil, medias_globais):
    """Heurística simples de negócio para nomear o cluster a partir do seu perfil médio."""
    alto_valor = perfil["valor_total"] >= medias_globais["valor_total"]
    alta_freq = perfil["qtd_pedidos"] >= medias_globais["qtd_pedidos"]
    alto_cancelamento = perfil["taxa_cancelamento"] >= medias_globais["taxa_cancelamento"] * 1.3
    recente = perfil["recencia_dias"] <= medias_globais["recencia_dias"]

    if alto_cancelamento:
        return "Em Risco (Alto Cancelamento)"
    if alto_valor and alta_freq:
        return "Clientes Fiéis / Alto Valor"
    if not recente and not alta_freq:
        return "Inativos / Baixo Engajamento"
    if alta_freq and not alto_valor:
        return "Frequentes / Ticket Baixo"
    return "Ocasionais"


def segmentar(df, k_min=2, k_max=8, output_dir="mining/clusterizacao"):
    os.makedirs(output_dir, exist_ok=True)

    preprocessor = ColumnTransformer(transformers=[
        ("num", StandardScaler(), FEATURES_NUM),
        ("cat", OneHotEncoder(handle_unknown="ignore", sparse_output=False), FEATURES_CAT),
    ])
    X = preprocessor.fit_transform(df[FEATURES_NUM + FEATURES_CAT])

    melhor_k, df_k = escolher_k(X, k_min=k_min, k_max=k_max, output_dir=output_dir)

    kmeans_final = KMeans(n_clusters=melhor_k, n_init=10, random_state=42)
    df = df.copy()
    df["cluster"] = kmeans_final.fit_predict(X)

    medias_globais = df[FEATURES_NUM].mean()
    perfil_clusters = df.groupby("cluster")[FEATURES_NUM].mean()
    rotulos = {c: rotular_cluster(perfil_clusters.loc[c], medias_globais) for c in perfil_clusters.index}
    df["rotulo_segmento"] = df["cluster"].map(rotulos)

    contagem = df["cluster"].value_counts().sort_index()
    perfil_clusters["qtd_clientes"] = contagem
    perfil_clusters["rotulo_segmento"] = perfil_clusters.index.map(rotulos)

    print("\n" + "=" * 90)
    print(f"PERFIL DOS {melhor_k} CLUSTERS DE CLIENTES (K-MEANS)")
    print("=" * 90)
    print(tabulate(perfil_clusters.round(2), headers="keys", tablefmt="grid"))

    return df, perfil_clusters, df_k, melhor_k


def persistir_resultados(df, perfil_clusters, df_k, melhor_k, engine, output_dir="mining/clusterizacao"):
    os.makedirs(output_dir, exist_ok=True)

    cols_csv = ["sk_cliente", "codigo_cliente", "nome", "tipo_pessoa", "regiao"] + FEATURES_NUM + ["cluster", "rotulo_segmento"]
    csv_path = os.path.join(output_dir, "clientes_segmentados.csv")
    df[cols_csv].to_csv(csv_path, index=False, encoding="utf-8-sig")
    print(f"[OK] Segmentação por cliente salva em: {csv_path}")

    if engine is not None:
        try:
            from sqlalchemy import text
            cols_db = ["sk_cliente", "cluster", "rotulo_segmento", "qtd_pedidos", "valor_total",
                       "valor_medio_pedido", "qtd_categorias_distintas", "taxa_cancelamento",
                       "nota_media", "recencia_dias"]
            with engine.begin() as conn:
                conn.execute(text("TRUNCATE TABLE dw.dim_cliente_segmento RESTART IDENTITY"))
            df[cols_db].to_sql("dim_cliente_segmento", engine, schema="dw", if_exists="append", index=False)
            print("[OK] Tabela dw.dim_cliente_segmento atualizada no Postgres.")
        except Exception as e:
            print(f"[AVISO] Não foi possível gravar dw.dim_cliente_segmento ({e}). "
                  f"Rode dw/09_segmentacao_clientes_ddl.sql antes de executar este script.")

    md_path = os.path.join(output_dir, "relatorio_clusterizacao.md")
    with open(md_path, "w", encoding="utf-8") as f:
        f.write("# Relatório de Clusterização (Segmentação) de Clientes — Prestador Nota 10\n\n")
        f.write("### Objetivo:\n")
        f.write("Segmentar os clientes em grupos homogêneos de comportamento de compra via **K-Means**, "
                "para que a mineração de Regras de Associação seja feita **por segmento** "
                "(ver `mining/associacao/relatorio_regras.md`).\n\n")
        f.write("### Features utilizadas:\n")
        f.write("- Numéricas (padronizadas via `StandardScaler`): " + ", ".join(FEATURES_NUM) + "\n")
        f.write("- Categóricas (`OneHotEncoder`): " + ", ".join(FEATURES_CAT) + "\n\n")
        f.write(f"### Seleção de k:\nTestado k de {df_k['k'].min()} a {df_k['k'].max()}; "
                f"escolhido **k = {melhor_k}** pelo maior Silhouette Score "
                f"({df_k['silhouette'].max():.3f}). Ver `elbow_silhouette.png` e `comparativo_k.csv`.\n\n")
        f.write("### Perfil dos clusters (médias por grupo):\n\n")
        f.write(perfil_clusters.round(2).to_markdown())
        f.write("\n\n### Ações de CRM/Marketing sugeridas por segmento:\n")
        f.write("- **Clientes Fiéis / Alto Valor**: programas de fidelidade, atendimento prioritário.\n")
        f.write("- **Em Risco (Alto Cancelamento)**: ação de recuperação, contato proativo do suporte.\n")
        f.write("- **Inativos / Baixo Engajamento**: campanhas de reativação, cupons de retorno.\n")
        f.write("- **Frequentes / Ticket Baixo**: cross-sell de serviços complementares (ver regras por segmento).\n")
        f.write("- **Ocasionais**: campanhas de awareness e indicação.\n")
    print(f"[OK] Relatório de clusterização salvo em: {md_path}")


if __name__ == "__main__":
    print("=================================================================")
    print("  CLUSTERIZAÇÃO (SEGMENTAÇÃO) DE CLIENTES — PRESTADOR NOTA 10")
    print("=================================================================")
    dados, engine = carregar_dados_dw()
    df_segmentado, perfil, df_k, melhor_k = segmentar(dados)
    persistir_resultados(df_segmentado, perfil, df_k, melhor_k, engine)
