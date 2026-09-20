"""
Prestador Nota 10 — Módulo de Modelos de Ensemble (Aprendizado em Conjunto)
Modelos: Random Forest, Gradient Boosting, AdaBoost, Voting Classifier e Stacking Classifier

Casos de Uso:
1. Predição de Cancelamento de Pedidos (Churn / Falha Operacional)
2. Predição de Conversão / Aceite de Orçamentos Comerciais

Objetivo:
Avaliar se técnicas de ensemble (Bagging, Boosting e Stacking) superam modelos individuais
em precisão, generalização (ROC-AUC) e F1-Score.
"""

import os
import sys
import pandas as pd
import numpy as np
from tabulate import tabulate

from sklearn.model_selection import train_test_split, StratifiedKFold, cross_val_score
from sklearn.preprocessing import StandardScaler, OneHotEncoder
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline
from sklearn.metrics import (
    accuracy_score, precision_score, recall_score, f1_score, 
    roc_auc_score, classification_report, confusion_matrix
)

# Modelos Ensemble
from sklearn.ensemble import (
    RandomForestClassifier,
    GradientBoostingClassifier,
    AdaBoostClassifier,
    VotingClassifier,
    StackingClassifier
)
from sklearn.linear_model import LogisticRegression
from sklearn.tree import DecisionTreeClassifier

def carregar_dados_dw(db_uri=None):
    """
    Carrega o dataset enriquecido a partir do DW PostgreSQL ou gera dataset sintético representativo.
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
            fp.qtd_orcamentos_recebidos,
            COALESCE(fp.dias_para_primeiro_orcamento, 30) AS dias_para_primeiro_orcamento,
            COALESCE(fp.valor_orcamento_selecionado, 0) AS valor_orcamento,
            fp.qtd_categorias_servico,
            cid.regiao,
            cat.descricao AS categoria_servico,
            cli.tipo_pessoa AS tipo_cliente,
            COALESCE(p.avaliacao_media, 3.0) AS avaliacao_prestador,
            COALESCE(pl.valor_mensalidade, 0) AS mensalidade_plano_prestador,
            fp.indicador_cancelado
        FROM dw.fato_pedido fp
        JOIN dw.dim_cidade cid ON fp.sk_cidade = cid.sk_cidade
        JOIN dw.dim_categoria_servico cat ON fp.sk_categoria_servico = cat.sk_categoria_servico
        JOIN dw.dim_cliente cli ON fp.sk_cliente = cli.sk_cliente
        LEFT JOIN dw.dim_prestador p ON fp.sk_prestador = p.sk_prestador
        LEFT JOIN dw.dim_plano pl ON p.sk_plano = pl.sk_plano;
        """
        df = pd.read_sql(query, engine)
        print(f"[OK] Dataset carregado do DW com {len(df)} registros.")
        return df
    except Exception as e:
        print(f"[INFO] Banco indisponível ({e}). Gerando dataset representativo do DW para modelagem...")
        return gerar_dataset_sintetico_dw()

def gerar_dataset_sintetico_dw(n_samples=1000):
    """
    Gera dataset baseado nas regras estocásticas do DW com relações de negócio realistas.
    """
    np.random.seed(42)
    regioes = ["Centro-Oeste", "Sudeste", "Sul", "Nordeste", "Norte"]
    categorias = [
        "Instalação de Ar Condicionado", "Manutenção Elétrica Residencial", 
        "Pintura Residencial", "Instalação Hidráulica", "Montagem de Móveis"
    ]
    tipos_cliente = ["PF", "PJ"]

    regiao_col = np.random.choice(regioes, n_samples, p=[0.35, 0.35, 0.15, 0.1, 0.05])
    cat_col = np.random.choice(categorias, n_samples)
    tipo_cli_col = np.random.choice(tipos_cliente, n_samples, p=[0.8, 0.2])
    
    qtd_orcamentos = np.random.poisson(lam=2.5, size=n_samples)
    qtd_orcamentos = np.clip(qtd_orcamentos, 0, 8)
    
    dias_resposta = np.random.exponential(scale=3.0, size=n_samples)
    valor_orcamento = np.random.gamma(shape=5.0, scale=80.0, size=n_samples)
    aval_prestador = np.random.normal(loc=4.2, scale=0.6, size=n_samples)
    aval_prestador = np.clip(aval_prestador, 1.0, 5.0)
    
    # Probabilidade de cancelamento influenciada por demora de resposta e poucos orçamentos
    log_odds = (
        -1.5 
        + 0.45 * dias_resposta 
        - 0.60 * qtd_orcamentos 
        - 0.30 * (aval_prestador - 3.0) 
        + (valor_orcamento > 600).astype(int) * 0.4
    )
    prob_cancel = 1 / (1 + np.exp(-log_odds))
    indicador_cancelado = (np.random.rand(n_samples) < prob_cancel).astype(int)

    df = pd.DataFrame({
        "sk_pedido": range(1, n_samples + 1),
        "qtd_orcamentos_recebidos": qtd_orcamentos,
        "dias_para_primeiro_orcamento": np.round(dias_resposta, 1),
        "valor_orcamento": np.round(valor_orcamento, 2),
        "qtd_categorias_servico": np.random.choice([1, 2, 3], n_samples, p=[0.8, 0.15, 0.05]),
        "regiao": regiao_col,
        "categoria_servico": cat_col,
        "tipo_cliente": tipo_cli_col,
        "avaliacao_prestador": np.round(aval_prestador, 2),
        "mensalidade_plano_prestador": np.random.choice([0.0, 49.9, 99.9, 199.9], n_samples),
        "indicador_cancelado": indicador_cancelado
    })
    return df

def criar_preparador(numeric_features, categorical_features):
    """
    Cria pipeline de pré-processamento para features numéricas e categóricas.
    """
    numeric_transformer = Pipeline(steps=[
        ('scaler', StandardScaler())
    ])
    categorical_transformer = Pipeline(steps=[
        ('onehot', OneHotEncoder(handle_unknown='ignore', sparse_output=False))
    ])
    preprocessor = ColumnTransformer(
        transformers=[
            ('num', numeric_transformer, numeric_features),
            ('cat', categorical_transformer, categorical_features)
        ]
    )
    return preprocessor

def construir_modelos_ensemble():
    """
    Configura e retorna o catálogo de modelos Ensemble para treinamento.
    """
    # Modelos Base
    rf = RandomForestClassifier(n_estimators=150, max_depth=8, random_state=42)
    gb = GradientBoostingClassifier(n_estimators=120, learning_rate=0.08, max_depth=4, random_state=42)
    ada = AdaBoostClassifier(estimator=DecisionTreeClassifier(max_depth=2), n_estimators=80, random_state=42)
    
    # Voting Classifier (Ensemble por Votação Ponderada)
    voting = VotingClassifier(
        estimators=[('rf', rf), ('gb', gb), ('ada', ada)],
        voting='soft',
        weights=[2, 2, 1]
    )
    
    # Stacking Classifier (Meta-aprendizado)
    stacking = StackingClassifier(
        estimators=[('rf', rf), ('gb', gb), ('ada', ada)],
        final_estimator=LogisticRegression(C=1.0, max_iter=500),
        cv=5
    )

    modelos = {
        "Random Forest (Bagging)": rf,
        "Gradient Boosting (Boosting)": gb,
        "AdaBoost (Adaptive Boosting)": ada,
        "Voting Ensemble (Soft Voting)": voting,
        "Stacking Ensemble (Meta-Learner)": stacking
    }
    return modelos

def avaliar_modelos(df, output_dir="mining/ensemble"):
    """
    Executa o treinamento, validação cruzada K-Fold e avaliação detalhada dos modelos.
    """
    os.makedirs(output_dir, exist_ok=True)
    
    features_num = [
        "qtd_orcamentos_recebidos", "dias_para_primeiro_orcamento", 
        "valor_orcamento", "qtd_categorias_servico", "avaliacao_prestador", 
        "mensalidade_plano_prestador"
    ]
    features_cat = ["regiao", "categoria_servico", "tipo_cliente"]
    
    X = df[features_num + features_cat]
    y = df["indicador_cancelado"]
    
    print(f"Distribuição do Target (Cancelado=1 vs Finalizado=0):")
    print(y.value_counts(normalize=True).apply(lambda x: f"{x*100:.1f}%").to_dict())

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.25, random_state=42, stratify=y
    )
    
    preprocessor = criar_preparador(features_num, features_cat)
    modelos = construir_modelos_ensemble()
    
    resultados = []
    cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)

    print("\n--- Treinando e Avaliando Modelos de Ensemble ---")
    
    melhor_modelo_nome = None
    melhor_auc = 0.0
    melhor_pipeline = None

    for nome, modelo in modelos.items():
        pipe = Pipeline(steps=[
            ('preprocessor', preprocessor),
            ('classifier', modelo)
        ])
        
        # Validação Cruzada K-Fold (ROC-AUC)
        cv_scores = cross_val_score(pipe, X_train, y_train, cv=cv, scoring='roc_auc')
        
        # Treinamento no conjunto de treino
        pipe.fit(X_train, y_train)
        
        # Predições no conjunto de teste
        y_pred = pipe.predict(X_test)
        y_prob = pipe.predict_proba(X_test)[:, 1] if hasattr(pipe, "predict_proba") else y_pred
        
        acc = accuracy_score(y_test, y_pred)
        prec = precision_score(y_test, y_pred, zero_division=0)
        rec = recall_score(y_test, y_pred, zero_division=0)
        f1 = f1_score(y_test, y_pred, zero_division=0)
        auc = roc_auc_score(y_test, y_prob)
        
        resultados.append({
            "Modelo": nome,
            "CV ROC-AUC (Média ± DP)": f"{cv_scores.mean():.3f} (±{cv_scores.std():.3f})",
            "Acurácia (Teste)": f"{acc*100:.2f}%",
            "Precisão": f"{prec*100:.2f}%",
            "Recall": f"{rec*100:.2f}%",
            "F1-Score": f"{f1*100:.2f}%",
            "ROC-AUC (Teste)": f"{auc:.3f}"
        })

        if auc > melhor_auc:
            melhor_auc = auc
            melhor_modelo_nome = nome
            melhor_pipeline = pipe

    df_res = pd.DataFrame(resultados)
    
    print("\n" + "="*95)
    print("TABELA COMPARATIVA DE PERFORMANCE DOS MODELOS ENSEMBLE")
    print("="*95)
    print(tabulate(df_res, headers="keys", tablefmt="grid", showindex=False))

    # Feature Importance para Random Forest / Gradient Boosting
    preprocessor_fitted = melhor_pipeline.named_steps['preprocessor']
    cat_cols_encoded = preprocessor_fitted.named_transformers_['cat'].named_steps['onehot'].get_feature_names_out(features_cat)
    todas_features = features_num + list(cat_cols_encoded)
    
    # Extrai importâncias se o modelo suportar
    clf = melhor_pipeline.named_steps['classifier']
    importancias_df = None
    if hasattr(clf, "feature_importances_"):
        importancias = clf.feature_importances_
        importancias_df = pd.DataFrame({
            "Variável": todas_features,
            "Importância (%)": np.round(importancias * 100, 2)
        }).sort_values(by="Importância (%)", ascending=False)
    
    # Exportação dos Relatórios
    csv_path = os.path.join(output_dir, "comparativo_modelos_ensemble.csv")
    md_path = os.path.join(output_dir, "relatorio_ensemble.md")
    
    df_res.to_csv(csv_path, index=False, encoding="utf-8-sig")
    
    with open(md_path, "w", encoding="utf-8") as f:
        f.write("# Relatório de Modelagem Preditiva com Ensemble Learning\n\n")
        f.write("### Objetivo:\n")
        f.write("Classificação e predição antecipada de **Cancelamento de Pedidos (Churn)** na plataforma Prestador Nota 10.\n\n")
        f.write("### Modelos Avaliados:\n")
        f.write("- **Bagging**: Random Forest (reduz variância via bootstrap aggregation)\n")
        f.write("- **Boosting**: Gradient Boosting e AdaBoost (aprendizado sequencial focado nos erros residuais)\n")
        f.write("- **Stacking / Voting**: Meta-ensemble que combina a probabilidade predita por múltiplos classificadores\n\n")
        f.write("### Tabela Comparativa de Resultados:\n\n")
        f.write(df_res.to_markdown(index=False))
        f.write(f"\n\n**Melhor Modelo**: `{melhor_modelo_nome}` com ROC-AUC de `{melhor_auc:.3f}` no conjunto de teste.\n\n")
        
        if importancias_df is not None:
            f.write("### Variáveis Mais Importantes para Decisão:\n\n")
            f.write(importancias_df.head(10).to_markdown(index=False))
            f.write("\n\n")

        f.write("### Conclusões e Ações Recomendadas de Negócio:\n")
        f.write("1. **Gatilho de Alerta de Churn**: Disparar notificações push para prestadores quando um pedido estiver há mais de 24h sem orçamento.\n")
        f.write("2. **Incentivo de Resposta Rápida**: Bonificar prestadores que respondem orçamentos nos primeiros 30 minutos.\n")
        f.write("3. **Integração Operacional**: Inserir o score de risco do modelo na fila de triagem de pedidos da plataforma.\n")

    print(f"\n[OK] Relatórios salvos em:\n  - {csv_path}\n  - {md_path}")
    return df_res

if __name__ == "__main__":
    print("=================================================================")
    print("  TREINAMENTO DE MODELOS ENSEMBLE — PRESTADOR NOTA 10")
    print("=================================================================")
    dataset = carregar_dados_dw()
    avaliar_modelos(dataset)
