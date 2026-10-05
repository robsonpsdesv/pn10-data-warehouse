#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Gerador do Documento Físico (HTML e PDF) de Alta Qualidade
Relatório Técnico Completo: Ensemble (Clusterização + Regras de Associação)
Projeto Prestador Nota 10 - IFG
"""

import os
import sys
import base64
import subprocess
import shutil

def b64_img(path):
    with open(path, "rb") as f:
        return f"data:image/png;base64,{base64.b64encode(f.read()).decode('utf-8')}"

def gerar_html():
    img_elbow = b64_img("mining/clusterizacao/elbow_silhouette.png")
    img_schema = b64_img("mining/clusterizacao/screenshots/01_schema_dw_tabelas.png")
    img_detalhe = b64_img("mining/clusterizacao/screenshots/02_vw_segmentacao_clientes.png")
    img_resumo = b64_img("mining/clusterizacao/screenshots/03_vw_resumo_segmento_cliente_tabela.png")
    img_grafico = b64_img("mining/clusterizacao/screenshots/04_grafico_clientes_por_segmento.png")

    html = f"""<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<title>Relatório Técnico Completo — Ensemble: Clusterização + Regras de Associação</title>
<style>
  @page {{
    size: A4 portrait;
    margin: 18mm 15mm 18mm 15mm;
  }}

  * {{
    box-sizing: border-box;
    -webkit-print-color-adjust: exact !important;
    print-color-adjust: exact !important;
  }}

  body {{
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
    color: #2d3748;
    background-color: #ffffff;
    line-height: 1.55;
    font-size: 10pt;
    margin: 0;
    padding: 0;
  }}

  /* Capa ABNT Elegante */
  .capa {{
    height: 100vh;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    text-align: center;
    page-break-after: always;
    break-after: page;
    padding: 30mm 15mm 20mm 15mm;
  }}

  .capa-header {{
    border-bottom: 2px solid #2b6cb0;
    padding-bottom: 15px;
  }}

  .capa-inst {{
    font-size: 13.5pt;
    font-weight: 700;
    color: #1a365d;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    margin-bottom: 5px;
  }}

  .capa-campus {{
    font-size: 10.5pt;
    font-weight: 600;
    color: #4a5568;
    text-transform: uppercase;
    margin-bottom: 4px;
  }}

  .capa-disc {{
    font-size: 10pt;
    color: #2b6cb0;
    font-weight: 600;
  }}

  .capa-corpo {{
    margin-top: auto;
    margin-bottom: auto;
  }}

  .capa-titulo {{
    font-size: 19pt;
    font-weight: 800;
    color: #1a202c;
    line-height: 1.3;
    margin-bottom: 15px;
    text-transform: uppercase;
  }}

  .capa-subtitulo {{
    font-size: 12pt;
    font-weight: 500;
    color: #4a5568;
    line-height: 1.4;
    max-width: 90%;
    margin-left: auto;
    margin-right: auto;
  }}

  .capa-badge {{
    display: inline-block;
    background: #ebf8ff;
    color: #2b6cb0;
    border: 1px solid #bee3f8;
    border-radius: 20px;
    padding: 4px 14px;
    font-size: 8.5pt;
    font-weight: 700;
    text-transform: uppercase;
    margin-bottom: 20px;
  }}

  .capa-footer {{
    border-top: 1px solid #e2e8f0;
    padding-top: 15px;
  }}

  .capa-autor {{
    font-size: 11.5pt;
    font-weight: 700;
    color: #2d3748;
    margin-bottom: 4px;
  }}

  .capa-local {{
    font-size: 9.5pt;
    color: #718096;
    text-transform: uppercase;
  }}

  /* Folha de Rosto / Resumo */
  .folha-rosto {{
    page-break-after: always;
    break-after: page;
  }}

  .natureza-box {{
    margin-left: 30%;
    background: #f7fafc;
    border-left: 3px solid #2b6cb0;
    padding: 10px 14px;
    font-size: 8.5pt;
    color: #4a5568;
    line-height: 1.45;
    text-align: justify;
    margin-bottom: 18px;
  }}

  .resumo-box {{
    background: #ffffff;
    border: 1px solid #e2e8f0;
    border-radius: 6px;
    padding: 14px 18px;
    margin-bottom: 18px;
  }}

  .resumo-title {{
    font-size: 10.5pt;
    font-weight: 700;
    color: #1a365d;
    margin-top: 0;
    margin-bottom: 6px;
    text-transform: uppercase;
  }}

  .palavras-chave {{
    font-size: 8.5pt;
    color: #4a5568;
    margin-top: 8px;
  }}

  /* Sumário Estruturado */
  .toc-box {{
    background: #f7fafc;
    border: 1px solid #e2e8f0;
    border-radius: 6px;
    padding: 14px 18px;
    margin-bottom: 20px;
  }}

  .toc-item {{
    display: flex;
    justify-content: space-between;
    font-size: 9pt;
    padding: 3px 0;
    border-bottom: 1px dotted #cbd5e0;
  }}

  .toc-item strong {{
    color: #1a365d;
  }}

  /* Estrutura de Títulos */
  h1, h2, h3, h4 {{
    color: #1a365d;
    font-weight: 700;
    page-break-after: avoid;
    break-after: avoid;
  }}

  h1 {{
    font-size: 14pt;
    border-bottom: 2px solid #2b6cb0;
    padding-bottom: 5px;
    margin-top: 22px;
    margin-bottom: 12px;
    text-transform: uppercase;
  }}

  h2 {{
    font-size: 11.5pt;
    color: #2b6cb0;
    margin-top: 16px;
    margin-bottom: 8px;
  }}

  h3 {{
    font-size: 10.5pt;
    color: #2d3748;
    margin-top: 14px;
    margin-bottom: 6px;
  }}

  p {{
    text-align: justify;
    margin-top: 0;
    margin-bottom: 8px;
  }}

  /* Quebras de página controladas */
  .page-break {{
    page-break-before: always;
    break-before: page;
  }}

  .avoid-break {{
    page-break-inside: avoid;
    break-inside: avoid;
  }}

  /* Tabelas Técnicas */
  table {{
    width: 100%;
    border-collapse: collapse;
    margin: 10px 0;
    font-size: 8.5pt;
    page-break-inside: avoid;
    break-inside: avoid;
  }}

  th, td {{
    padding: 6px 8px;
    text-align: left;
    border: 1px solid #cbd5e0;
  }}

  th {{
    background-color: #2b6cb0;
    color: #ffffff;
    font-weight: 600;
    text-transform: uppercase;
    font-size: 7.5pt;
    letter-spacing: 0.3px;
  }}

  tr:nth-child(even) {{
    background-color: #f7fafc;
  }}

  .text-center {{
    text-align: center;
  }}

  .text-right {{
    text-align: right;
  }}

  /* Caixas de Destaque */
  .callout {{
    background-color: #ebf8ff;
    border-left: 4px solid #3182ce;
    border-radius: 4px;
    padding: 10px 14px;
    margin: 12px 0;
    font-size: 9pt;
    page-break-inside: avoid;
    break-inside: avoid;
  }}

  .callout-success {{
    background-color: #f0fff4;
    border-left-color: #38a169;
  }}

  .callout-warning {{
    background-color: #fffaf0;
    border-left-color: #dd6b20;
  }}

  .callout-title {{
    font-weight: 700;
    color: #1a365d;
    margin-bottom: 3px;
  }}

  /* Figuras e Imagens */
  .figure-box {{
    text-align: center;
    margin: 12px 0;
    page-break-inside: avoid;
    break-inside: avoid;
  }}

  .figure-img {{
    max-width: 98%;
    height: auto;
    border: 1px solid #cbd5e0;
    border-radius: 5px;
    box-shadow: 0 1px 4px rgba(0,0,0,0.06);
  }}

  .figure-caption {{
    font-size: 8pt;
    color: #4a5568;
    margin-top: 4px;
    font-style: italic;
  }}

  /* Código */
  pre, code {{
    font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, Courier, monospace;
    font-size: 7.5pt;
  }}

  pre {{
    background-color: #1a202c;
    color: #e2e8f0;
    padding: 8px 12px;
    border-radius: 5px;
    overflow-x: auto;
    line-height: 1.4;
    margin: 8px 0;
    page-break-inside: avoid;
    break-inside: avoid;
  }}

  code {{
    background-color: #edf2f7;
    color: #2b6cb0;
    padding: 1px 3px;
    border-radius: 3px;
  }}

  pre code {{
    background-color: transparent;
    color: inherit;
    padding: 0;
  }}

  ul, ol {{
    margin-top: 0;
    margin-bottom: 8px;
    padding-left: 18px;
  }}

  li {{
    margin-bottom: 3px;
    text-align: justify;
  }}

  .header-decor {{
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-bottom: 1px solid #e2e8f0;
    padding-bottom: 3px;
    margin-bottom: 12px;
    font-size: 7.5pt;
    color: #718096;
    text-transform: uppercase;
  }}

  .footer-decor {{
    margin-top: 25px;
    padding-top: 8px;
    border-top: 1px solid #e2e8f0;
    display: flex;
    justify-content: space-between;
    font-size: 7.5pt;
    color: #a0aec0;
  }}
</style>
</head>
<body>

<!-- CAPA -->
<div class="capa">
  <div class="capa-header">
    <div class="capa-inst">Instituto Federal de Educação, Ciência e Tecnologia de Goiás</div>
    <div class="capa-campus">Câmpus Goiânia • Pós-Graduação / Especialização / Mestrado</div>
    <div class="capa-disc">Tópicos Avançados em Inteligência Artificial I</div>
  </div>

  <div class="capa-corpo">
    <div class="capa-badge">Relatório Técnico Oficial • Documento Físico</div>
    <div class="capa-titulo">Ensemble Híbrido: Clusterização de Clientes Integrada a Regras de Associação</div>
    <div class="capa-subtitulo">
      Segmentação Comportamental com K-Means e Mineração de Padrões Transacionais por Agrupamento via FP-Growth sobre Data Warehouse Dimensional
    </div>
  </div>

  <div class="capa-footer">
    <div class="capa-autor">Ivânio / Equipe Prestador Nota 10</div>
    <div class="capa-local">Goiânia – GO<br>2026</div>
  </div>
</div>

<!-- FOLHA DE ROSTO E RESUMO -->
<div class="folha-rosto">
  <div class="header-decor">
    <span>IFG — Tópicos Avançados em Inteligência Artificial I</span>
    <span>Projeto Prestador Nota 10</span>
  </div>

  <div class="natureza-box">
    <strong>Natureza do Trabalho:</strong> Relatório Técnico e Científico apresentado como entregável formal da disciplina <em>Tópicos Avançados em Inteligência Artificial I</em>. Documenta o projeto, modelagem do Data Warehouse, esteira de ETL, aplicação do conceito de ensemble metodológico (aprendizagem não-supervisionada seguida de mineração de regras de associação por grupo), além do módulo preditivo complementar supervisionado.
  </div>

  <div class="resumo-box">
    <div class="resumo-title">Resumo Executivo</div>
    <p>
      Este relatório documenta a concepção, implementação e validação de um pipeline analítico de mineração de dados orientado a CRM e marketing para a plataforma <strong>Prestador Nota 10</strong>. A premissa central estabelece que a extração indiscriminada de regras de associação sobre uma base de transações global gera elevado volume de regras triviais e dilui padrões característicos de clientes de maior valor. Para superar essa limitação, implementou-se o conceito de <em>ensemble</em> sob uma abordagem híbrida: a partir de um Data Warehouse modelado em esquema estrela no PostgreSQL com dimensões conformadas e fatos atômicos, os clientes foram primeiramente clusterizados via algoritmo <strong>K-Means</strong> com seleção de hiperparâmetro baseada em <em>Silhouette Score</em>. Em seguida, a base transacional foi particionada e o algoritmo <strong>FP-Growth</strong> foi executado de forma dedicada dentro de cada segmento identificado. Os resultados empíricos demonstram que no grupo de clientes fiéis e de alto valor (ticket médio R$ 542,24) emergiram regras de alta dependência estatística (ex.: <em>Chaveiros e ferragens &rarr; Hidráulica</em> com confiança de 52,00% e Lift de 1,390), ao passo que no grupo de clientes inativos e de baixo engajamento não foram identificados itemsets frequentes, validando experimentalmente o benefício da segmentação prévia. Adicionalmente, um módulo supervisionado com ensemble heterogêneo (Random Forest, Gradient Boosting, AdaBoost, Voting e Stacking) foi consolidado para predição de cancelamento de pedidos.
    </p>
    <div class="palavras-chave">
      <strong>Palavras-chave:</strong> Data Warehouse; Ensemble Learning; K-Means; Regras de Associação; FP-Growth; Segmentação de Clientes; CRM Analítico.
    </div>
  </div>

  <div class="toc-box">
    <div class="resumo-title" style="margin-bottom: 6px;">Sumário Estruturado</div>
    <div class="toc-item"><span><strong>1. Introdução e Motivação de Negócio</strong> — Contexto, objetivos e conceito de ensemble</span> <span>Seção 1</span></div>
    <div class="toc-item"><span><strong>2. Arquitetura do Data Warehouse</strong> — Camadas OLTP, DW, Datamarts e integração</span> <span>Seção 2</span></div>
    <div class="toc-item"><span><strong>3. Etapa 1: Clusterização de Clientes (K-Means)</strong> — Features, seleção de k e perfis</span> <span>Seção 3</span></div>
    <div class="toc-item"><span><strong>4. Visualização Analítica no Metabase</strong> — Evidências reais e dashboards</span> <span>Seção 4</span></div>
    <div class="toc-item"><span><strong>5. Etapa 2: Regras de Associação por Segmento</strong> — FP-Growth, métricas e achados</span> <span>Seção 5</span></div>
    <div class="toc-item"><span><strong>6. Módulo Complementar: Ensemble de Churn</strong> — Classificação supervisionada</span> <span>Seção 6</span></div>
    <div class="toc-item"><span><strong>7. Recomendações Estratégicas e Ações de CRM</strong> — Matriz de ações e conclusões</span> <span>Seção 7</span></div>
    <div class="toc-item"><span><strong>8. Guia de Reprodutibilidade e Entregáveis</strong> — Scripts e inventário de arquivos</span> <span>Seção 8</span></div>
  </div>

  <h2 style="margin-top: 14px;">Matriz de Conformidade com a Demanda</h2>
  <table>
    <thead>
      <tr>
        <th style="width: 25%;">Requisito Requisitado</th>
        <th style="width: 15%;" class="text-center">Status</th>
        <th style="width: 60%;">Evidência Técnica no Repositório</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><strong>1. DW / Datamart Construído e Povoado</strong></td>
        <td class="text-center"><span style="color:#276749; font-weight:700;">Conforme (100%)</span></td>
        <td>Esquema dimensional <code>dw</code> e datamarts <code>dm_*</code> estruturados e povoados por <code>dw/01..08_*.sql</code>, abrangendo fatos de pedidos, orçamentos, avaliações e agendamentos com integridade referencial.</td>
      </tr>
      <tr>
        <td><strong>2. Aplicação de Ensemble</strong></td>
        <td class="text-center"><span style="color:#276749; font-weight:700;">Conforme (&gt;100%)</span></td>
        <td>Implementação dupla: (a) Ensemble Híbrido Metodológico (Clusterização &rarr; Regras por Segmento) e (b) Ensemble Preditivo Supervisionado (Bagging, Boosting e Stacking) para predição de churn.</td>
      </tr>
      <tr>
        <td><strong>3. Clusterização / Classificação de Clientes</strong></td>
        <td class="text-center"><span style="color:#276749; font-weight:700;">Conforme (100%)</span></td>
        <td>Segmentação não-supervisionada via <code>K-Means</code> sobre 9 features comportamentais (RFM, cancelamento e região), com seleção objetiva de <em>k=2</em> via Silhouette Score e persistência física em <code>dw.dim_cliente_segmento</code>.</td>
      </tr>
      <tr>
        <td><strong>4. Regras de Associação por Grupo/Classe</strong></td>
        <td class="text-center"><span style="color:#276749; font-weight:700;">Conforme (100%)</span></td>
        <td>Mineração via <code>FP-Growth</code> particionada por cluster, demonstrando geração de 8 regras no cluster fiel (Lift até 1.39) e isolamento da esparsidade no cluster inativo.</td>
      </tr>
      <tr>
        <td><strong>5. Bibliotecas Python</strong></td>
        <td class="text-center"><span style="color:#276749; font-weight:700;">Conforme (100%)</span></td>
        <td>Uso de <code>scikit-learn</code>, <code>mlxtend</code>, <code>pandas</code>, <code>sqlalchemy</code>, <code>matplotlib</code> e <code>tabulate</code> estruturados em <code>mining/requirements.txt</code>.</td>
      </tr>
      <tr>
        <td><strong>6. Entregáveis: Código e Relatório Técnico</strong></td>
        <td class="text-center"><span style="color:#276749; font-weight:700;">Conforme (100%)</span></td>
        <td>Código modular versionado, scripts orquestradores <code>.sh</code> e <code>.ps1</code>, relatórios técnicos, visualizações no Metabase e documento físico em PDF.</td>
      </tr>
    </tbody>
  </table>
</div>

<!-- SEÇÃO 1: INTRODUÇÃO -->
<div class="page-break">
  <div class="header-decor">
    <span>IFG — Relatório Técnico Completo</span>
    <span>Seção 1: Introdução e Motivação</span>
  </div>

  <h1>1. Introdução e Motivação de Negócio</h1>

  <h2>1.1. Contexto do Problema</h2>
  <p>
    A plataforma <strong>Prestador Nota 10</strong> opera como um ecossistema digital bilateral (marketplace de serviços), conectando clientes que necessitam de intervenções técnicas e domésticas a prestadores de serviços qualificados. O ciclo transacional engloba a abertura de pedidos, cotação de orçamentos concorrentes, aceitação de propostas, agendamento de atendimentos e avaliação de conformidade.
  </p>
  <p>
    No gerenciamento de relacionamento com clientes (CRM), um dos objetivos primordiais é estimular o <em>cross-selling</em> (venda cruzada) e o aumento do valor do tempo de vida do cliente (<em>Customer Lifetime Value</em> — LTV). Tradicionalmente, técnicas de Mineração de Regras de Associação (*Market Basket Analysis*) são empregadas para responder à pergunta: <em>"Se um cliente contrata o serviço A, qual a probabilidade de ele também necessitar do serviço B?"</em>
  </p>

  <h2>1.2. O Desafio da Mineração Global Indiscriminada</h2>
  <p>
    A aplicação direta e simplista de algoritmos como Apriori ou FP-Growth sobre todo o histórico transacional consolidado incorre em severos problemas práticos:
  </p>
  <ul>
    <li><strong>Diluição Estatística:</strong> Clientes fiéis com múltiplos pedidos representam uma fração menor da base, enquanto clientes esporádicos (que contrataram apenas uma vez e nunca mais retornaram) compõem a maioria volumétrica. Quando agregados sem distinção, os clientes de contratação única aumentam o denominador da base sem contribuir com cestas correlacionadas, reduzindo artificialmente o suporte de padrões reais existentes entre os clientes mais engajados.</li>
    <li><strong>Regras Espúrias e Não-Acionáveis:</strong> Serviços de altíssima frequência marginal (como reformas residenciais básicas) tendem a se associar a qualquer outro serviço simplesmente pelo acaso, gerando métricas de confiança elevadas, mas com <em>Lift</em> próximo a 1,0 (independência estatística).</li>
  </ul>

  <h2>1.3. O Conceito de Ensemble Adotado</h2>
  <p>
    Para solucionar esse desafio, o presente trabalho operacionalizou o conceito de <strong>Ensemble (Aprendizagem por Conjuntos)</strong> em uma perspectiva híbrida e em múltiplos estágios:
  </p>
  <div class="callout callout-success">
    <div class="callout-title">Definição do Pipeline de Ensemble Híbrido:</div>
    Em vez de aplicar um modelo isolado, combinam-se duas famílias de técnicas de aprendizado de máquina em cascata:
    <br>
    <strong>1º Estágio (Não-Supervisionado):</strong> Clusterização com K-Means para particionar a população de clientes em segmentos homogêneos segundo seu perfil transacional e RFM (Recência, Frequência, Monetário).
    <br>
    <strong>2º Estágio (Mineração Simbólica Condicionada):</strong> Aplicação de FP-Growth isoladamente dentro de cada segmento, descobrindo regras de associação especializadas e altamente acionáveis para cada perfil de público.
  </div>

  <h2>1.4. Diagrama Geral do Pipeline Implementado</h2>
  <div class="figure-box">
    <svg width="680" height="110" viewBox="0 0 680 110" style="background:#ffffff; border:1px solid #cbd5e0; border-radius:6px;">
      <!-- DW -->
      <rect x="15" y="25" width="105" height="60" rx="4" fill="#ebf8ff" stroke="#2b6cb0" stroke-width="1.5"/>
      <text x="67" y="50" text-anchor="middle" font-weight="700" font-size="9.5" fill="#1a365d">dw.fato_pedido</text>
      <text x="67" y="66" text-anchor="middle" font-size="8" fill="#4a5568">Data Warehouse</text>

      <path d="M 120 55 L 145 55" stroke="#2b6cb0" stroke-width="2" marker-end="url(#arrow)"/>

      <!-- Features -->
      <rect x="150" y="25" width="115" height="60" rx="4" fill="#f7fafc" stroke="#4a5568" stroke-width="1.5"/>
      <text x="207" y="48" text-anchor="middle" font-weight="700" font-size="9" fill="#1a365d">Feature Engineering</text>
      <text x="207" y="62" text-anchor="middle" font-size="7.5" fill="#4a5568">RFM + Diversidade</text>
      <text x="207" y="74" text-anchor="middle" font-size="7.5" fill="#4a5568">+ Satisfação + Região</text>

      <path d="M 265 55 L 290 55" stroke="#2b6cb0" stroke-width="2"/>

      <!-- K-Means -->
      <rect x="295" y="25" width="105" height="60" rx="4" fill="#feebc8" stroke="#dd6b20" stroke-width="1.5"/>
      <text x="347" y="48" text-anchor="middle" font-weight="700" font-size="9" fill="#7b341e">K-Means</text>
      <text x="347" y="62" text-anchor="middle" font-size="7.5" fill="#7b341e">Seleção de k ótimo</text>
      <text x="347" y="74" text-anchor="middle" font-size="7.5" fill="#7b341e">via Silhouette Score</text>

      <path d="M 400 55 L 425 55" stroke="#2b6cb0" stroke-width="2"/>

      <!-- Segmento Table -->
      <rect x="430" y="25" width="115" height="60" rx="4" fill="#fffaf0" stroke="#c05621" stroke-width="1.5"/>
      <text x="487" y="48" text-anchor="middle" font-weight="700" font-size="8.5" fill="#7b341e">Tabela Intermediária</text>
      <text x="487" y="62" text-anchor="middle" font-size="7.5" fill="#7b341e">dw.dim_cliente_segmento</text>
      <text x="487" y="74" text-anchor="middle" font-size="7.5" fill="#7b341e">(Persistência Física)</text>

      <path d="M 545 55 L 570 55" stroke="#2b6cb0" stroke-width="2"/>

      <!-- FP Growth -->
      <rect x="575" y="25" width="95" height="60" rx="4" fill="#c6f6d5" stroke="#276749" stroke-width="1.5"/>
      <text x="622" y="48" text-anchor="middle" font-weight="700" font-size="9" fill="#22543d">FP-Growth</text>
      <text x="622" y="62" text-anchor="middle" font-size="7.5" fill="#22543d">Mineração POR</text>
      <text x="622" y="74" text-anchor="middle" font-size="7.5" fill="#22543d">SEGMENTO</text>
    </svg>
    <div class="figure-caption">Figura 1 — Fluxo de ponta a ponta do ensemble híbrido (Data Warehouse &rarr; K-Means &rarr; FP-Growth por Segmento).</div>
  </div>
</div>

<!-- SEÇÃO 2: ARQUITETURA DO DW -->
<div class="page-break">
  <div class="header-decor">
    <span>IFG — Relatório Técnico Completo</span>
    <span>Seção 2: Arquitetura Dimensional</span>
  </div>

  <h1>2. Arquitetura do Data Warehouse e Engenharia de Dados</h1>

  <h2>2.1. Modelagem Dimensional e Camadas</h2>
  <p>
    A estrutura de armazenamento analítico foi desenvolvida no PostgreSQL local (porta 5433 / banco <code>prestadornota10local</code>), distribuída em três camadas desacopladas:
  </p>
  <ul>
    <li><strong>Camada Transacional (OLTP — Schema <code>pn10</code>):</strong> Espelho relacional normalizado da API (tabelas <code>pedido</code>, <code>orcamento_pedido</code>, <code>avaliacao_pedido</code>, <code>agendamento</code>, <code>pessoa</code>, <code>empresa</code>, <code>usuario</code>, <code>categoria_servico</code>), criada por <code>01_oltp_ddl.sql</code> e populada com 800 pedidos sintéticos por <code>02_oltp_carga.sql</code>.</li>
    <li><strong>Camada Dimensional Central (DW — Schema <code>dw</code>):</strong> Esquema estrela unificado contendo as dimensões conformadas e as tabelas fato no menor grão transacional (DDL em <code>03_dw_ddl.sql</code> e ETL em <code>04_dw_carga.sql</code>).</li>
    <li><strong>Camada de Datamarts (Schemas <code>dm_*</code>):</strong> Seis datamarts departamentais construídos por <code>05_datamart_ddl.sql</code> e carregados por <code>06_datamart_carga.sql</code> contendo agregações sumarizadas (*rollups*) para otimização de painéis de BI.</li>
  </ul>

  <h2>2.2. Diagrama Conceitual do Esquema Estrela (Schema dw)</h2>
  <div class="figure-box">
    <svg width="680" height="230" viewBox="0 0 680 230" style="background:#ffffff; border:1px solid #cbd5e0; border-radius:6px;">
      <!-- Fato Central -->
      <rect x="250" y="55" width="180" height="120" rx="6" fill="#ebf8ff" stroke="#2b6cb0" stroke-width="2"/>
      <text x="340" y="80" text-anchor="middle" font-weight="700" font-size="11" fill="#1a365d">dw.fato_pedido</text>
      <line x1="250" y1="90" x2="430" y2="90" stroke="#2b6cb0" stroke-width="1"/>
      <text x="260" y="107" font-size="8" fill="#4a5568">sk_pedido (PK)</text>
      <text x="260" y="121" font-size="8" fill="#4a5568">sk_cliente (FK)</text>
      <text x="260" y="135" font-size="8" fill="#4a5568">sk_categoria_servico (FK)</text>
      <text x="260" y="149" font-size="8" fill="#4a5568">valor_orcamento_selecionado</text>
      <text x="260" y="163" font-size="8" fill="#4a5568">indicador_cancelado</text>

      <!-- Dim Cliente -->
      <rect x="30" y="15" width="150" height="65" rx="4" fill="#f7fafc" stroke="#4a5568" stroke-width="1.5"/>
      <text x="105" y="35" text-anchor="middle" font-weight="700" font-size="9.5" fill="#1a365d">dw.dim_cliente</text>
      <text x="40" y="53" font-size="8" fill="#4a5568">sk_cliente (PK)</text>
      <text x="40" y="67" font-size="8" fill="#4a5568">nome, tipo_pessoa</text>
      <line x1="180" y1="47" x2="250" y2="95" stroke="#718096" stroke-width="1.5" stroke-dasharray="3,3"/>

      <!-- Dim Categoria -->
      <rect x="30" y="150" width="150" height="65" rx="4" fill="#f7fafc" stroke="#4a5568" stroke-width="1.5"/>
      <text x="105" y="170" text-anchor="middle" font-weight="700" font-size="9.5" fill="#1a365d">dw.dim_categoria_servico</text>
      <text x="40" y="188" font-size="8" fill="#4a5568">sk_categoria_servico (PK)</text>
      <text x="40" y="202" font-size="8" fill="#4a5568">descricao_categoria_pai</text>
      <line x1="180" y1="182" x2="250" y2="135" stroke="#718096" stroke-width="1.5" stroke-dasharray="3,3"/>

      <!-- Dim Tempo -->
      <rect x="500" y="15" width="150" height="65" rx="4" fill="#f7fafc" stroke="#4a5568" stroke-width="1.5"/>
      <text x="575" y="35" text-anchor="middle" font-weight="700" font-size="9.5" fill="#1a365d">dw.dim_tempo</text>
      <text x="510" y="53" font-size="8" fill="#4a5568">sk_tempo (PK)</text>
      <text x="510" y="67" font-size="8" fill="#4a5568">data, mes, ano, trimestre</text>
      <line x1="500" y1="47" x2="430" y2="95" stroke="#718096" stroke-width="1.5" stroke-dasharray="3,3"/>

      <!-- Dim Segmento -->
      <rect x="500" y="150" width="150" height="65" rx="4" fill="#fffaf0" stroke="#dd6b20" stroke-width="1.5"/>
      <text x="575" y="170" text-anchor="middle" font-weight="700" font-size="9.5" fill="#c05621">dw.dim_cliente_segmento</text>
      <text x="510" y="188" font-size="8" fill="#7b341e">sk_cliente (PK)</text>
      <text x="510" y="202" font-size="8" fill="#7b341e">cluster, rotulo_segmento</text>
      <line x1="500" y1="182" x2="430" y2="135" stroke="#dd6b20" stroke-width="1.5" stroke-dasharray="3,3"/>
    </svg>
    <div class="figure-caption">Figura 2 — Arquitetura dimensional estrela com integração da tabela de segmentação de clientes.</div>
  </div>

  <h2>2.3. Tabela de Integração: dw.dim_cliente_segmento</h2>
  <p>
    Para viabilizar a comunicação desacoplada entre a clusterização Python e a etapa de regras de associação, o script <code>dw/09_segmentacao_clientes_ddl.sql</code> define a tabela física <code>dw.dim_cliente_segmento</code>. Esta tabela armazena a atribuição de cluster e rótulo de negócio para cada cliente, viabilizando consultas analíticas no Metabase e filtragem de cestas via SQL:
  </p>
  <pre><code>CREATE TABLE dw.dim_cliente_segmento (
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
    data_execucao            timestamp NOT NULL DEFAULT now()
);</code></pre>
</div>

<!-- SEÇÃO 3: CLUSTERIZAÇÃO K-MEANS -->
<div class="page-break">
  <div class="header-decor">
    <span>IFG — Relatório Técnico Completo</span>
    <span>Seção 3: Segmentação de Clientes</span>
  </div>

  <h1>3. Etapa 1: Clusterização e Segmentação de Clientes (K-Means)</h1>

  <h2>3.1. Engenharia de Features e Transformações</h2>
  <p>
    A partir de consultas agregadas sobre <code>dw.fato_pedido</code> e suas dimensões, extraíram-se atributos comportamentais no nível de grão de cliente. Foram filtrados exclusivamente os clientes com pelo menos 1 pedido registrado (277 clientes no total):
  </p>
  <table>
    <thead>
      <tr>
        <th style="width: 25%;">Atributo</th>
        <th style="width: 15%;">Tipo</th>
        <th style="width: 20%;">Tratamento</th>
        <th style="width: 40%;">Significado no Modelo de Negócio</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><code>qtd_pedidos</code></td>
        <td>Numérica</td>
        <td><code>StandardScaler</code></td>
        <td>Frequência de engajamento do cliente na plataforma.</td>
      </tr>
      <tr>
        <td><code>valor_total</code></td>
        <td>Numérica</td>
        <td><code>StandardScaler</code></td>
        <td>Dimensão Monetária (faturamento gerado pelo cliente).</td>
      </tr>
      <tr>
        <td><code>valor_medio_pedido</code></td>
        <td>Numérica</td>
        <td><code>StandardScaler</code></td>
        <td>Ticket médio por contratação de serviço.</td>
      </tr>
      <tr>
        <td><code>qtd_categorias_distintas</code></td>
        <td>Numérica</td>
        <td><code>StandardScaler</code></td>
        <td>Diversidade de necessidades atendidas na plataforma.</td>
      </tr>
      <tr>
        <td><code>taxa_cancelamento</code></td>
        <td>Numérica</td>
        <td><code>StandardScaler</code></td>
        <td>Percentual de pedidos abortados ou cancelados.</td>
      </tr>
      <tr>
        <td><code>nota_media</code></td>
        <td>Numérica</td>
        <td>Imputação + Scaler</td>
        <td>Índice de satisfação manifestada nas avaliações.</td>
      </tr>
      <tr>
        <td><code>recencia_dias</code></td>
        <td>Numérica</td>
        <td>Imputação + Scaler</td>
        <td>Dias transcorridos desde a última solicitação de serviço.</td>
      </tr>
      <tr>
        <td><code>tipo_pessoa</code></td>
        <td>Categórica</td>
        <td><code>OneHotEncoder</code></td>
        <td>Segmentação entre Pessoa Física (PF) e Pessoa Jurídica (PJ).</td>
      </tr>
      <tr>
        <td><code>regiao</code></td>
        <td>Categórica</td>
        <td><code>OneHotEncoder</code></td>
        <td>Localização geográfica das solicitações do cliente.</td>
      </tr>
    </tbody>
  </table>

  <h2>3.2. Seleção de Hiperparâmetro (k) e Avaliação de Silhueta</h2>
  <p>
    O algoritmo K-Means foi treinado para diferentes valores de <em>k</em> (2 a 8). O gráfico comparativo abaixo apresenta a curva de inércia e o coeficiente de silhueta médio calculado:
  </p>
  <div class="figure-box">
    <img src="{img_elbow}" class="figure-img" style="max-height: 200px;" alt="Curva de Cotovelo e Silhouette Score">
    <div class="figure-caption">Figura 3 — Curva de Inércia (Cotovelo) e Coeficiente de Silhueta para <em>k</em> &isin; [2, 8].</div>
  </div>
  <p>
    O valor ótimo identificado foi <strong>k = 2</strong>, apresentando o maior coeficiente de silhueta (<strong>0,217</strong>). Para valores maiores (3 a 8), o índice decaiu para a faixa de 0,17 a 0,18, demonstrando que partições mais granulares criariam subgrupos artificiais sem separabilidade real.
  </p>

  <h2>3.3. Perfil dos Segmentos Descobertos</h2>
  <table>
    <thead>
      <tr>
        <th class="text-center">Cluster</th>
        <th class="text-center">Clientes</th>
        <th class="text-right">Pedidos Méd.</th>
        <th class="text-right">Valor Total</th>
        <th class="text-right">Ticket Médio</th>
        <th class="text-center">Categorias</th>
        <th class="text-center">Cancelamento</th>
        <th class="text-center">Recência</th>
        <th>Rótulo Estratégico</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td class="text-center"><strong>0</strong></td>
        <td class="text-center">154 (55,6%)</td>
        <td class="text-right">1,80</td>
        <td class="text-right">R$ 803,69</td>
        <td class="text-right">R$ 475,32</td>
        <td class="text-center">1,78</td>
        <td class="text-center">19,0%</td>
        <td class="text-center">813 dias</td>
        <td><strong>Inativos / Baixo Engajamento</strong></td>
      </tr>
      <tr>
        <td class="text-center"><strong>1</strong></td>
        <td class="text-center">123 (44,4%)</td>
        <td class="text-right">4,25</td>
        <td class="text-right">R$ 2.186,42</td>
        <td class="text-right">R$ 542,24</td>
        <td class="text-center">4,17</td>
        <td class="text-center">16,0%</td>
        <td class="text-center">395 dias</td>
        <td><strong>Clientes Fiéis / Alto Valor</strong></td>
      </tr>
    </tbody>
  </table>
</div>

<!-- SEÇÃO 4: VISUALIZAÇÃO NO METABASE -->
<div class="page-break">
  <div class="header-decor">
    <span>IFG — Relatório Técnico Completo</span>
    <span>Seção 4: Visualização no Metabase</span>
  </div>

  <h1>4. Evidências Visuais e Dashboards no Metabase</h1>
  <p>
    Para validar o consumo operacional dos dados minerados, a tabela <code>dw.dim_cliente_segmento</code> foi exposta no Metabase através das views analíticas <code>dw.vw_segmentacao_clientes</code> e <code>dw.vw_resumo_segmento_cliente</code> (arquivo <code>metabase/views/vw_segmentacao_clientes.sql</code>).
  </p>

  <div class="figure-box">
    <img src="{img_schema}" class="figure-img" style="max-height: 160px;" alt="Schema dw no Metabase">
    <div class="figure-caption">Figura 4 — Catálogo de Dados do Metabase exibindo as tabelas físicas e views da segmentação.</div>
  </div>

  <div class="figure-box">
    <img src="{img_detalhe}" class="figure-img" style="max-height: 180px;" alt="Detalhe de Segmentação por Cliente">
    <div class="figure-caption">Figura 5 — View <code>dw.vw_segmentacao_clientes</code>: detalhe individualizado dos 277 clientes com atributos e rótulos.</div>
  </div>

  <div style="display: flex; gap: 10px; margin: 12px 0;">
    <div style="flex: 1; text-align: center;">
      <img src="{img_resumo}" style="width: 100%; border: 1px solid #cbd5e0; border-radius: 4px;" alt="Resumo dos Segmentos">
      <div class="figure-caption">Figura 6 — Card de resumo médio por cluster.</div>
    </div>
    <div style="flex: 1; text-align: center;">
      <img src="{img_grafico}" style="width: 100%; border: 1px solid #cbd5e0; border-radius: 4px;" alt="Gráfico de Clientes por Segmento">
      <div class="figure-caption">Figura 7 — Distribuição de clientes por segmento (154 x 123).</div>
    </div>
  </div>
</div>

<!-- SEÇÃO 5: REGRAS DE ASSOCIAÇÃO -->
<div class="page-break">
  <div class="header-decor">
    <span>IFG — Relatório Técnico Completo</span>
    <span>Seção 5: Regras de Associação</span>
  </div>

  <h1>5. Etapa 2: Regras de Associação por Segmento (FP-Growth)</h1>

  <h2>5.1. Modelagem da Cesta de Compras e Rollup de Categorias</h2>
  <p>
    Em serviços, a transação não é instantânea. Cada cesta foi modelada como o <strong>conjunto de categorias distintas contratadas pelo cliente</strong> ao longo de seu histórico.
  </p>
  <p>
    Para evitar que a grande diversidade de subcategorias finas (~130 subcategorias) gerasse suporte nulo para pares de itens, aplicou-se um <em>rollup</em> para a <strong>Macro Categoria de Serviço</strong> (campo <code>dim_categoria_servico.descricao_categoria_pai</code>, ~25 categorias).
  </p>

  <h2>5.2. Resultados no Segmento "Clientes Fiéis / Alto Valor" (123 clientes)</h2>
  <p>
    Executando o algoritmo <strong>FP-Growth</strong> com suporte mínimo de 8% e limiar de corte por Lift &gt; 1,10, identificaram-se 8 regras estatisticamente relevantes:
  </p>
  <table>
    <thead>
      <tr>
        <th style="width: 32%;">Se Contratou (SE)</th>
        <th style="width: 32%;">Também Contrata (ENTÃO)</th>
        <th style="width: 9%;" class="text-right">Suporte</th>
        <th style="width: 9%;" class="text-right">Confiança</th>
        <th style="width: 6%;" class="text-right">Lift</th>
        <th style="width: 6%;" class="text-right">Alavanc.</th>
        <th style="width: 6%;" class="text-right">Convic.</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><strong>Chaveiros e ferragens</strong></td>
        <td><strong>Hidráulica</strong></td>
        <td class="text-right">10,57%</td>
        <td class="text-right"><strong>52,00%</strong></td>
        <td class="text-right"><strong>1,390</strong></td>
        <td class="text-right">0,030</td>
        <td class="text-right">1,304</td>
      </tr>
      <tr>
        <td><strong>Hidráulica</strong></td>
        <td><strong>Chaveiros e ferragens</strong></td>
        <td class="text-right">10,57%</td>
        <td class="text-right">28,26%</td>
        <td class="text-right"><strong>1,390</strong></td>
        <td class="text-right">0,030</td>
        <td class="text-right">1,111</td>
      </tr>
      <tr>
        <td><strong>Chaveiros e ferragens</strong></td>
        <td><strong>Residencial</strong></td>
        <td class="text-right">9,76%</td>
        <td class="text-right">48,00%</td>
        <td class="text-right">1,181</td>
        <td class="text-right">0,015</td>
        <td class="text-right">1,141</td>
      </tr>
      <tr>
        <td><strong>Residencial</strong></td>
        <td><strong>Chaveiros e ferragens</strong></td>
        <td class="text-right">9,76%</td>
        <td class="text-right">24,00%</td>
        <td class="text-right">1,181</td>
        <td class="text-right">0,015</td>
        <td class="text-right">1,048</td>
      </tr>
      <tr>
        <td><strong>Automotivo</strong></td>
        <td><strong>Computadores e Tecnologia</strong></td>
        <td class="text-right">8,13%</td>
        <td class="text-right">22,73%</td>
        <td class="text-right">1,165</td>
        <td class="text-right">0,012</td>
        <td class="text-right">1,042</td>
      </tr>
      <tr>
        <td><strong>Computadores e Tecnologia</strong></td>
        <td><strong>Automotivo</strong></td>
        <td class="text-right">8,13%</td>
        <td class="text-right">41,67%</td>
        <td class="text-right">1,165</td>
        <td class="text-right">0,012</td>
        <td class="text-right">1,101</td>
      </tr>
      <tr>
        <td><strong>Hidráulica</strong></td>
        <td><strong>Residencial</strong></td>
        <td class="text-right">17,07%</td>
        <td class="text-right">45,65%</td>
        <td class="text-right">1,123</td>
        <td class="text-right">0,019</td>
        <td class="text-right">1,092</td>
      </tr>
      <tr>
        <td><strong>Residencial</strong></td>
        <td><strong>Hidráulica</strong></td>
        <td class="text-right">17,07%</td>
        <td class="text-right">42,00%</td>
        <td class="text-right">1,123</td>
        <td class="text-right">0,019</td>
        <td class="text-right">1,079</td>
      </tr>
    </tbody>
  </table>

  <h2>5.3. Resultados no Segmento "Inativos / Baixo Engajamento" (154 clientes)</h2>
  <div class="callout callout-warning">
    <div class="callout-title">Diagnóstico Empírico da Segmentação:</div>
    No segmento de clientes inativos, a aplicação do FP-Growth com suporte decrescente (8% &rarr; 6% &rarr; 4,5% &rarr; 3% &rarr; 2%) <strong>não produziu nenhum itemset frequente com 2 ou mais itens</strong>.
    <br><br>
    <strong>Validação da Hipótese:</strong> Como esse grupo possui média de apenas 1,80 pedidos por cliente e recência de 813 dias, os clientes não possuem cesta multitemática. Misturar este grupo à base total apenas diluiria as regras do grupo fiel.
  </div>
</div>

<!-- SEÇÃO 6: ENSEMBLE SUPERVISIONADO -->
<div class="page-break">
  <div class="header-decor">
    <span>IFG — Relatório Técnico Completo</span>
    <span>Seção 6: Módulo Supervisionado de Churn</span>
  </div>

  <h1>6. Módulo Complementar: Ensemble de Classificadores para Churn</h1>

  <h2>6.1. Definição do Experimento Supervisionado</h2>
  <p>
    Para complementar o trabalho, o módulo <code>mining/ensemble/treinar_ensemble.py</code> foi corrigido para treinar múltiplos algoritmos de ensemble supervisionados com o objetivo de predizer a variável binária <code>indicador_cancelado</code> de <code>dw.fato_pedido</code>.
  </p>
  <p>
    Foram treinados modelos representativos das três grandes famílias de ensemble: <strong>Bagging</strong> (Random Forest), <strong>Boosting</strong> (Gradient Boosting e AdaBoost) e <strong>Meta-Ensembles</strong> (Voting Classifier e Stacking Classifier com meta-modelo em Regressão Logística).
  </p>

  <h2>6.2. Comparativo de Desempenho sobre Dados Reais do DW</h2>
  <table>
    <thead>
      <tr>
        <th>Modelo Avaliado</th>
        <th class="text-center">Família</th>
        <th class="text-center">CV ROC-AUC</th>
        <th class="text-right">Acurácia (Teste)</th>
        <th class="text-right">Precisão</th>
        <th class="text-right">Recall</th>
        <th class="text-right">F1-Score</th>
        <th class="text-right">ROC-AUC Teste</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><strong>Gradient Boosting</strong></td>
        <td class="text-center">Boosting</td>
        <td class="text-center">0,508 (&plusmn;0,051)</td>
        <td class="text-right">79,50%</td>
        <td class="text-right"><strong>23,08%</strong></td>
        <td class="text-right"><strong>8,82%</strong></td>
        <td class="text-right"><strong>12,77%</strong></td>
        <td class="text-right"><strong>0,583</strong></td>
      </tr>
      <tr>
        <td><strong>Stacking Classifier</strong></td>
        <td class="text-center">Stacking</td>
        <td class="text-center">0,485 (&plusmn;0,053)</td>
        <td class="text-right">83,00%</td>
        <td class="text-right">0,00%</td>
        <td class="text-right">0,00%</td>
        <td class="text-right">0,00%</td>
        <td class="text-right">0,577</td>
      </tr>
      <tr>
        <td><strong>Voting Classifier</strong></td>
        <td class="text-center">Soft Voting</td>
        <td class="text-center">0,491 (&plusmn;0,050)</td>
        <td class="text-right">80,00%</td>
        <td class="text-right">0,00%</td>
        <td class="text-right">0,00%</td>
        <td class="text-right">0,00%</td>
        <td class="text-right">0,572</td>
      </tr>
      <tr>
        <td><strong>Random Forest</strong></td>
        <td class="text-center">Bagging</td>
        <td class="text-center">0,489 (&plusmn;0,054)</td>
        <td class="text-right">83,00%</td>
        <td class="text-right">0,00%</td>
        <td class="text-right">0,00%</td>
        <td class="text-right">0,00%</td>
        <td class="text-right">0,533</td>
      </tr>
      <tr>
        <td><strong>AdaBoost</strong></td>
        <td class="text-center">Boosting</td>
        <td class="text-center">0,482 (&plusmn;0,053)</td>
        <td class="text-right">83,00%</td>
        <td class="text-right">0,00%</td>
        <td class="text-right">0,00%</td>
        <td class="text-right">0,00%</td>
        <td class="text-right">0,531</td>
      </tr>
    </tbody>
  </table>

  <h2>6.3. Importância dos Atributos (Feature Importances - Gradient Boosting)</h2>
  <table>
    <thead>
      <tr>
        <th style="width: 60%;">Variável Explicativa</th>
        <th style="width: 20%;" class="text-right">Importância (%)</th>
        <th style="width: 20%;">Impacto Operacional</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><code>valor_orcamento</code></td>
        <td class="text-right"><strong>22,24%</strong></td>
        <td>Sensibilidade ao preço cobrado.</td>
      </tr>
      <tr>
        <td><code>avaliacao_prestador</code></td>
        <td class="text-right"><strong>12,30%</strong></td>
        <td>Reputação e confiança no prestador.</td>
      </tr>
      <tr>
        <td><code>dias_para_primeiro_orcamento</code></td>
        <td class="text-right"><strong>7,37%</strong></td>
        <td>Agilidade e tempo de espera inicial.</td>
      </tr>
      <tr>
        <td><code>qtd_orcamentos_recebidos</code></td>
        <td class="text-right">4,39%</td>
        <td>Poder de escolha do cliente.</td>
      </tr>
      <tr>
        <td><code>qtd_categorias_servico</code></td>
        <td class="text-right">4,34%</td>
        <td>Complexidade do escopo do pedido.</td>
      </tr>
      <tr>
        <td><code>mensalidade_plano_prestador</code></td>
        <td class="text-right">3,16%</td>
        <td>Nível de engajamento do prestador.</td>
      </tr>
    </tbody>
  </table>
</div>

<!-- SEÇÃO 7: RECOMENDAÇÕES E REPRODUTIBILIDADE -->
<div class="page-break">
  <div class="header-decor">
    <span>IFG — Relatório Técnico Completo</span>
    <span>Seção 7 e 8: Recomendações e Reprodutibilidade</span>
  </div>

  <h1>7. Recomendações de Negócio e Ações de CRM</h1>

  <h2>7.1. Matriz de Ações por Segmento</h2>
  <table>
    <thead>
      <tr>
        <th style="width: 25%;">Segmento</th>
        <th style="width: 35%;">Padrão Descoberto</th>
        <th style="width: 40%;">Plano de Ação Tático de CRM</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><strong>Clientes Fiéis / Alto Valor (123 clientes)</strong></td>
        <td>Alta afinidade entre <em>Chaveiros</em>, <em>Hidráulica</em> e <em>Residencial</em> (Lift até 1.39 e confiança de 52%).</td>
        <td>
          1. <strong>Cross-Sell no Carrinho:</strong> Oferecer agendamento de revisão hidráulica ao contratar chaveiro.<br>
          2. <strong>Combos "Casa Segura":</strong> Pacote integrado com desconto comercial.<br>
          3. <strong>Fidelidade VIP:</strong> Prioridade na fila de resposta dos orçamentos.
        </td>
      </tr>
      <tr>
        <td><strong>Inativos / Baixo Engajamento (154 clientes)</strong></td>
        <td>Contratações pontuais e isoladas; ausência de regras frequentes; recência média de 813 dias.</td>
        <td>
          1. <strong>Não ofertar cross-sell precoce</strong> baseado em regras (alto risco de rejeição).<br>
          2. <strong>Campanhas de Reativação:</strong> Cupom de retorno com validade de 15 dias.<br>
          3. <strong>Pesquisa de Abandono:</strong> Investigar fricções de preço ou usabilidade.
        </td>
      </tr>
    </tbody>
  </table>

  <h1>8. Guia de Reprodutibilidade e Entregáveis</h1>

  <h2>8.1. Comandos de Execução</h2>
  <pre><code># Execução completa ponta a ponta:
chmod +x executar_pipeline.sh && ./executar_pipeline.sh

# No Windows (PowerShell):
.\executar_pipeline.ps1

# Execução individual dos scripts de mineração:
python3 mining/clusterizacao/segmentar_clientes.py
python3 mining/associacao/regras_associacao.py
python3 mining/ensemble/treinar_ensemble.py</code></pre>

  <h2>8.2. Inventário de Arquivos do Trabalho</h2>
  <ul>
    <li><strong>Documento Físico (PDF):</strong> <code>RELATORIO_TECNICO_FINAL.pdf</code> (e cópia em <code>mining/</code>).</li>
    <li><strong>Documento Fonte (HTML):</strong> <code>RELATORIO_TECNICO_FINAL.html</code>.</li>
    <li><strong>Scripts SQL:</strong> <code>dw/01_oltp_ddl.sql</code> até <code>dw/09_segmentacao_clientes_ddl.sql</code>.</li>
    <li><strong>Módulos Python:</strong> <code>mining/clusterizacao/</code>, <code>mining/associacao/</code> e <code>mining/ensemble/</code>.</li>
    <li><strong>Views e Dashboards Metabase:</strong> <code>metabase/views/vw_segmentacao_clientes.sql</code>.</li>
  </ul>

  <div style="margin-top: 30px; padding-top: 15px; border-top: 1px solid #cbd5e0; text-align: center;">
    <div style="display: inline-block; text-align: center;">
      <div style="width: 250px; border-top: 1px solid #2d3748; margin-bottom: 4px;"></div>
      <span style="font-weight: 700; font-size: 9.5pt; color: #1a202c;">Ivânio / Equipe Prestador Nota 10</span><br>
      <span style="font-size: 8pt; color: #4a5568;">Instituto Federal de Educação, Ciência e Tecnologia de Goiás (IFG)</span>
    </div>
  </div>
</div>

</body>
</html>
"""
    return html

def main():
    print("[1/3] Gerando HTML autocontido com imagens em base64...")
    html_content = gerar_html()
    
    html_path = "RELATORIO_TECNICO_FINAL.html"
    with open(html_path, "w", encoding="utf-8") as f:
        f.write(html_content)
    print(f"      Salvo em: {html_path} ({len(html_content)} bytes)")
    
    mining_html_path = "mining/RELATORIO_TECNICO_FINAL.html"
    with open(mining_html_path, "w", encoding="utf-8") as f:
        f.write(html_content)
    print(f"      Cópia salva em: {mining_html_path}")

    print("[2/3] Compilando Documento Físico (PDF) via Chromium Headless sem cabeçalhos de navegador...")
    pdf_path = "RELATORIO_TECNICO_FINAL.pdf"
    cmd = [
        "chromium",
        "--headless",
        "--disable-gpu",
        "--no-sandbox",
        "--no-pdf-header-footer",
        "--run-all-compositor-stages-before-draw",
        f"--print-to-pdf={os.path.abspath(pdf_path)}",
        os.path.abspath(html_path)
    ]
    subprocess.run(cmd, check=True)
    
    mining_pdf_path = "mining/RELATORIO_TECNICO_FINAL.pdf"
    shutil.copyfile(pdf_path, mining_pdf_path)
    
    print(f"[3/3] SUCESSO! Documentos físicos gerados:")
    print(f"      - {pdf_path} ({os.path.getsize(pdf_path)} bytes)")
    print(f"      - {mining_pdf_path} ({os.path.getsize(mining_pdf_path)} bytes)")
    print(f"      - {html_path} (Versão HTML pronta para impressão via navegador)")

if __name__ == "__main__":
    main()
