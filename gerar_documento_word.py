#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Gerador do Relatório Técnico Oficial em formato Word (.docx) para Edição
Projeto Prestador Nota 10 — IFG
Disciplina: Tópicos Avançados em Inteligência Artificial I
"""

import os
import shutil
import docx
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml import parse_xml, OxmlElement
from docx.oxml.ns import nsdecls, qn

def set_cell_background(cell, hex_color):
    """Define a cor de fundo de uma célula da tabela."""
    tcPr = cell._tc.get_or_add_tcPr()
    # Remove existing shading if any
    for child in list(tcPr):
        if child.tag.endswith('shd'):
            tcPr.remove(child)
    shd = parse_xml(f'<w:shd {nsdecls("w")} w:fill="{hex_color}"/>')
    tcPr.append(shd)

def set_cell_margins(cell, top=100, bottom=100, left=150, right=150):
    """Define margens internas (padding) de uma célula."""
    tcPr = cell._tc.get_or_add_tcPr()
    tcMar = parse_xml(f'''
        <w:tcMar {nsdecls("w")}>
            <w:top w:w="{top}" w:type="dxa"/>
            <w:bottom w:w="{bottom}" w:type="dxa"/>
            <w:left w:w="{left}" w:type="dxa"/>
            <w:right w:w="{right}" w:type="dxa"/>
        </w:tcMar>
    ''')
    tcPr.append(tcMar)

def set_table_borders(table, border_color="CBD5E0", inside_color="E2E8F0"):
    """Define bordas limpas e elegantes para a tabela."""
    tblPr = table._tbl.tblPr
    tblBorders = parse_xml(f'''
        <w:tblBorders {nsdecls("w")}>
            <w:top w:val="single" w:sz="6" w:space="0" w:color="{border_color}"/>
            <w:bottom w:val="single" w:sz="6" w:space="0" w:color="{border_color}"/>
            <w:left w:val="none"/>
            <w:right w:val="none"/>
            <w:insideH w:val="single" w:sz="4" w:space="0" w:color="{inside_color}"/>
            <w:insideV w:val="none"/>
        </w:tblBorders>
    ''')
    tblPr.append(tblBorders)

def make_callout(doc, title, text, border_color="3182CE", bg_color="EBF8FF"):
    """Cria uma caixa de destaque visual com borda esquerda colorida."""
    table = doc.add_table(rows=1, cols=1)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    
    # Define bordas apenas na esquerda
    tblPr = table._tbl.tblPr
    tblBorders = parse_xml(f'''
        <w:tblBorders {nsdecls("w")}>
            <w:top w:val="none"/>
            <w:bottom w:val="none"/>
            <w:left w:val="single" w:sz="36" w:space="0" w:color="{border_color}"/>
            <w:right w:val="none"/>
            <w:insideH w:val="none"/>
            <w:insideV w:val="none"/>
        </w:tblBorders>
    ''')
    tblPr.append(tblBorders)
    
    cell = table.rows[0].cells[0]
    cell.width = Inches(6.5)
    set_cell_background(cell, bg_color)
    set_cell_margins(cell, top=140, bottom=140, left=200, right=180)
    
    # Conteúdo
    p = cell.paragraphs[0]
    p.paragraph_format.space_before = Pt(0)
    p.paragraph_format.space_after = Pt(4)
    p.paragraph_format.line_spacing = 1.15
    run_title = p.add_run(title)
    run_title.bold = True
    run_title.font.name = "Calibri"
    run_title.font.size = Pt(10)
    # Cor do título conforme a borda
    r_val = int(border_color[0:2], 16)
    g_val = int(border_color[2:4], 16)
    b_val = int(border_color[4:6], 16)
    run_title.font.color.rgb = RGBColor(r_val, g_val, b_val)
    
    # Linhas de texto
    for line in text.split("\n"):
        line = line.strip()
        if not line:
            continue
        p2 = cell.add_paragraph()
        p2.paragraph_format.space_before = Pt(2)
        p2.paragraph_format.space_after = Pt(2)
        p2.paragraph_format.line_spacing = 1.15
        p2.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
        run_txt = p2.add_run(line)
        run_txt.font.name = "Calibri"
        run_txt.font.size = Pt(9.5)
        run_txt.font.color.rgb = RGBColor(0x2D, 0x37, 0x48)

    # Espaço após o callout
    p_spacer = doc.add_paragraph()
    p_spacer.paragraph_format.space_before = Pt(0)
    p_spacer.paragraph_format.space_after = Pt(4)

def make_code_block(doc, code_text):
    """Cria uma caixa de código formatada em fonte monoespaçada."""
    table = doc.add_table(rows=1, cols=1)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    
    tblPr = table._tbl.tblPr
    tblBorders = parse_xml(f'''
        <w:tblBorders {nsdecls("w")}>
            <w:top w:val="single" w:sz="4" w:space="0" w:color="CBD5E0"/>
            <w:bottom w:val="single" w:sz="4" w:space="0" w:color="CBD5E0"/>
            <w:left w:val="single" w:sz="4" w:space="0" w:color="CBD5E0"/>
            <w:right w:val="single" w:sz="4" w:space="0" w:color="CBD5E0"/>
        </w:tblBorders>
    ''')
    tblPr.append(tblBorders)
    
    cell = table.rows[0].cells[0]
    cell.width = Inches(6.5)
    set_cell_background(cell, "F7FAFC")
    set_cell_margins(cell, top=120, bottom=120, left=180, right=180)
    
    lines = code_text.strip().split("\n")
    p = cell.paragraphs[0]
    p.paragraph_format.space_before = Pt(0)
    p.paragraph_format.space_after = Pt(1)
    p.paragraph_format.line_spacing = 1.1
    run = p.add_run(lines[0])
    run.font.name = "Consolas"
    run.font.size = Pt(8.5)
    run.font.color.rgb = RGBColor(0x1A, 0x20, 0x2C)
    
    for line in lines[1:]:
        p_line = cell.add_paragraph()
        p_line.paragraph_format.space_before = Pt(0)
        p_line.paragraph_format.space_after = Pt(1)
        p_line.paragraph_format.line_spacing = 1.1
        run_l = p_line.add_run(line)
        run_l.font.name = "Consolas"
        run_l.font.size = Pt(8.5)
        run_l.font.color.rgb = RGBColor(0x1A, 0x20, 0x2C)
        
    p_spacer = doc.add_paragraph()
    p_spacer.paragraph_format.space_before = Pt(0)
    p_spacer.paragraph_format.space_after = Pt(4)

def format_table(table, col_widths, alignments):
    """Aplica formatação ABNT/executiva elegante a tabelas Word."""
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    
    set_table_borders(table)
    
    # tblHeader e cantSplit na linha de cabeçalho
    hdr_row = table.rows[0]
    hdr_trPr = hdr_row._tr.get_or_add_trPr()
    hdr_trPr.append(parse_xml(f'<w:tblHeader {nsdecls("w")}/>'))
    hdr_trPr.append(parse_xml(f'<w:cantSplit {nsdecls("w")}/>'))
    
    for i, cell in enumerate(hdr_row.cells):
        cell.width = col_widths[i]
        set_cell_background(cell, "2B6CB0")
        set_cell_margins(cell, top=100, bottom=100, left=120, right=120)
        for p in cell.paragraphs:
            p.paragraph_format.space_before = Pt(0)
            p.paragraph_format.space_after = Pt(0)
            p.alignment = alignments[i]
            for run in p.runs:
                run.bold = True
                run.font.name = "Calibri"
                run.font.size = Pt(8.5)
                run.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
                
    # Linhas de dados
    for r_idx, row in enumerate(table.rows[1:], start=1):
        trPr = row._tr.get_or_add_trPr()
        trPr.append(parse_xml(f'<w:cantSplit {nsdecls("w")}/>'))
        bg_color = "F7FAFC" if (r_idx % 2 == 1) else "FFFFFF"
        for c_idx, cell in enumerate(row.cells):
            cell.width = col_widths[c_idx]
            set_cell_background(cell, bg_color)
            set_cell_margins(cell, top=70, bottom=70, left=110, right=110)
            for p in cell.paragraphs:
                p.paragraph_format.space_before = Pt(0)
                p.paragraph_format.space_after = Pt(0)
                p.paragraph_format.line_spacing = 1.15
                p.alignment = alignments[c_idx]
                for run in p.runs:
                    run.font.name = "Calibri"
                    run.font.size = Pt(8.5)
                    run.font.color.rgb = RGBColor(0x2D, 0x37, 0x48)

def add_heading_1(doc, text):
    """Adiciona título de primeiro nível com estilo personalizado."""
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(16)
    p.paragraph_format.space_after = Pt(6)
    p.paragraph_format.keep_with_next = True
    run = p.add_run(text)
    run.bold = True
    run.font.name = "Calibri"
    run.font.size = Pt(14)
    run.font.color.rgb = RGBColor(0x1A, 0x36, 0x5D)
    
    # Borda inferior decorativa
    pBdr = parse_xml(f'''
        <w:pBdr {nsdecls("w")}>
            <w:bottom w:val="single" w:sz="12" w:space="4" w:color="2B6CB0"/>
        </w:pBdr>
    ''')
    p._p.get_or_add_pPr().append(pBdr)
    return p

def add_heading_2(doc, text):
    """Adiciona título de segundo nível."""
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(12)
    p.paragraph_format.space_after = Pt(4)
    p.paragraph_format.keep_with_next = True
    run = p.add_run(text)
    run.bold = True
    run.font.name = "Calibri"
    run.font.size = Pt(12)
    run.font.color.rgb = RGBColor(0x2B, 0x6C, 0xB0)
    return p

def add_heading_3(doc, text):
    """Adiciona título de terceiro nível."""
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(8)
    p.paragraph_format.space_after = Pt(3)
    p.paragraph_format.keep_with_next = True
    run = p.add_run(text)
    run.bold = True
    run.font.name = "Calibri"
    run.font.size = Pt(10.5)
    run.font.color.rgb = RGBColor(0x2D, 0x37, 0x48)
    return p

def add_body_p(doc, text, bold_prefix=None):
    """Adiciona parágrafo padrão justificado."""
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(0)
    p.paragraph_format.space_after = Pt(5)
    p.paragraph_format.line_spacing = 1.15
    p.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    
    if bold_prefix:
        r_pre = p.add_run(bold_prefix)
        r_pre.bold = True
        r_pre.font.name = "Calibri"
        r_pre.font.size = Pt(10)
        r_pre.font.color.rgb = RGBColor(0x1A, 0x20, 0x2C)
        
    r = p.add_run(text)
    r.font.name = "Calibri"
    r.font.size = Pt(10)
    r.font.color.rgb = RGBColor(0x2D, 0x37, 0x48)
    return p

def add_bullet_p(doc, text, bold_prefix=None):
    """Adiciona item de lista com marcador."""
    p = doc.add_paragraph(style='List Bullet')
    p.paragraph_format.space_before = Pt(0)
    p.paragraph_format.space_after = Pt(3)
    p.paragraph_format.line_spacing = 1.15
    p.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    
    if bold_prefix:
        r_pre = p.add_run(bold_prefix)
        r_pre.bold = True
        r_pre.font.name = "Calibri"
        r_pre.font.size = Pt(9.5)
        r_pre.font.color.rgb = RGBColor(0x1A, 0x20, 0x2C)
        
    r = p.add_run(text)
    r.font.name = "Calibri"
    r.font.size = Pt(9.5)
    r.font.color.rgb = RGBColor(0x2D, 0x37, 0x48)
    return p

def add_figure(doc, image_path, caption, width=Inches(6.2)):
    """Insere imagem centralizada com legenda formatada."""
    p_img = doc.add_paragraph()
    p_img.paragraph_format.space_before = Pt(8)
    p_img.paragraph_format.space_after = Pt(3)
    p_img.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p_img.paragraph_format.keep_with_next = True
    
    run_img = p_img.add_run()
    run_img.add_picture(image_path, width=width)
    
    p_cap = doc.add_paragraph()
    p_cap.paragraph_format.space_before = Pt(2)
    p_cap.paragraph_format.space_after = Pt(8)
    p_cap.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.CENTER
    
    run_cap = p_cap.add_run(caption)
    run_cap.italic = True
    run_cap.font.name = "Calibri"
    run_cap.font.size = Pt(8.5)
    run_cap.font.color.rgb = RGBColor(0x4A, 0x55, 0x68)

def construir_relatorio_word():
    print("Iniciando geração do Relatório Técnico Oficial em formato Word (.docx)...")
    
    doc = Document()
    
    # Configuração de Margens da Página (A4: 2.0 cm top/bottom, 2.3 cm left/right)
    for section in doc.sections:
        section.page_width = Inches(8.27)
        section.page_height = Inches(11.69)
        section.top_margin = Inches(0.8)
        section.bottom_margin = Inches(0.8)
        section.left_margin = Inches(0.9)
        section.right_margin = Inches(0.9)
        
        # Cabeçalho padrão
        header = section.header
        hp = header.paragraphs[0]
        hp.paragraph_format.space_after = Pt(0)
        hp.alignment = WD_ALIGN_PARAGRAPH.RIGHT
        hrun = hp.add_run("IFG — Tópicos Avançados em IA I  |  Projeto Prestador Nota 10")
        hrun.font.name = "Calibri"
        hrun.font.size = Pt(7.5)
        hrun.font.color.rgb = RGBColor(0xA0, 0xAE, 0xC0)
        
        # Rodapé com numeração
        footer = section.footer
        fp = footer.paragraphs[0]
        fp.paragraph_format.space_before = Pt(0)
        fp.alignment = WD_ALIGN_PARAGRAPH.CENTER
        frun = fp.add_run("Relatório Técnico Oficial — Documento de Engenharia e Mineração de Dados")
        frun.font.name = "Calibri"
        frun.font.size = Pt(7.5)
        frun.font.color.rgb = RGBColor(0xA0, 0xAE, 0xC0)

    # -------------------------------------------------------------
    # CAPA ABNT / EXECUTIVA
    # -------------------------------------------------------------
    p_inst = doc.add_paragraph()
    p_inst.paragraph_format.space_before = Pt(36)
    p_inst.paragraph_format.space_after = Pt(2)
    p_inst.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r_inst = p_inst.add_run("INSTITUTO FEDERAL DE EDUCAÇÃO, CIÊNCIA E TECNOLOGIA DE GOIÁS")
    r_inst.bold = True
    r_inst.font.name = "Calibri"
    r_inst.font.size = Pt(13)
    r_inst.font.color.rgb = RGBColor(0x1A, 0x36, 0x5D)
    
    p_campus = doc.add_paragraph()
    p_campus.paragraph_format.space_before = Pt(0)
    p_campus.paragraph_format.space_after = Pt(2)
    p_campus.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r_campus = p_campus.add_run("CÂMPUS GOIÂNIA • PÓS-GRADUAÇÃO / ESPECIALIZAÇÃO / MESTRADO")
    r_campus.font.name = "Calibri"
    r_campus.font.size = Pt(10)
    r_campus.font.color.rgb = RGBColor(0x4A, 0x55, 0x68)
    
    p_disc = doc.add_paragraph()
    p_disc.paragraph_format.space_before = Pt(0)
    p_disc.paragraph_format.space_after = Pt(16)
    p_disc.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r_disc = p_disc.add_run("DISCIPLINA: TÓPICOS AVANÇADOS EM INTELIGÊNCIA ARTIFICIAL I")
    r_disc.bold = True
    r_disc.font.name = "Calibri"
    r_disc.font.size = Pt(10)
    r_disc.font.color.rgb = RGBColor(0x2B, 0x6C, 0xB0)
    
    # Linha divisória horizontal
    p_div = doc.add_paragraph()
    p_div.paragraph_format.space_before = Pt(0)
    p_div.paragraph_format.space_after = Pt(70)
    pBdr_capa = parse_xml(f'''
        <w:pBdr {nsdecls("w")}>
            <w:bottom w:val="single" w:sz="18" w:space="2" w:color="2B6CB0"/>
        </w:pBdr>
    ''')
    p_div._p.get_or_add_pPr().append(pBdr_capa)
    
    # Badge
    p_badge = doc.add_paragraph()
    p_badge.paragraph_format.space_before = Pt(0)
    p_badge.paragraph_format.space_after = Pt(12)
    p_badge.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r_badge = p_badge.add_run("RELATÓRIO TÉCNICO OFICIAL • DOCUMENTO EDITÁVEL (WORD)")
    r_badge.bold = True
    r_badge.font.name = "Calibri"
    r_badge.font.size = Pt(9)
    r_badge.font.color.rgb = RGBColor(0x2B, 0x6C, 0xB0)
    
    # Título Principal
    p_tit = doc.add_paragraph()
    p_tit.paragraph_format.space_before = Pt(0)
    p_tit.paragraph_format.space_after = Pt(12)
    p_tit.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r_tit = p_tit.add_run("ENSEMBLE HÍBRIDO: CLUSTERIZAÇÃO DE CLIENTES INTEGRADA A REGRAS DE ASSOCIAÇÃO")
    r_tit.bold = True
    r_tit.font.name = "Calibri"
    r_tit.font.size = Pt(18)
    r_tit.font.color.rgb = RGBColor(0x1A, 0x20, 0x2C)
    
    # Subtítulo
    p_sub = doc.add_paragraph()
    p_sub.paragraph_format.space_before = Pt(0)
    p_sub.paragraph_format.space_after = Pt(120)
    p_sub.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r_sub = p_sub.add_run("Segmentação Comportamental com K-Means e Mineração de Padrões Transacionais por Agrupamento via FP-Growth sobre Data Warehouse Dimensional")
    r_sub.font.name = "Calibri"
    r_sub.font.size = Pt(11)
    r_sub.font.color.rgb = RGBColor(0x4A, 0x55, 0x68)
    
    # Rodapé da Capa
    p_aut = doc.add_paragraph()
    p_aut.paragraph_format.space_before = Pt(0)
    p_aut.paragraph_format.space_after = Pt(4)
    p_aut.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r_aut = p_aut.add_run("Autor: Ivânio / Equipe Prestador Nota 10")
    r_aut.bold = True
    r_aut.font.name = "Calibri"
    r_aut.font.size = Pt(11)
    r_aut.font.color.rgb = RGBColor(0x2D, 0x37, 0x48)
    
    p_loc = doc.add_paragraph()
    p_loc.paragraph_format.space_before = Pt(0)
    p_loc.paragraph_format.space_after = Pt(0)
    p_loc.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r_loc = p_loc.add_run("Goiânia – GO\n2026")
    r_loc.font.name = "Calibri"
    r_loc.font.size = Pt(9.5)
    r_loc.font.color.rgb = RGBColor(0x71, 0x80, 0x96)
    
    doc.add_page_break()

    # -------------------------------------------------------------
    # FOLHA DE ROSTO / RESUMO EXECUTIVO / SUMÁRIO
    # -------------------------------------------------------------
    make_callout(
        doc,
        title="Natureza e Contexto Acadêmico:",
        text="Relatório Técnico e Científico apresentado como entregável formal da disciplina Tópicos Avançados em Inteligência Artificial I do Instituto Federal de Educação, Ciência e Tecnologia de Goiás (IFG). O documento consolida o projeto de modelagem de Data Warehouse, esteira de ETL relacional para dimensional, pipeline de ensemble híbrido (K-Means seguido de FP-Growth particionado por segmento de cliente) e módulo complementar preditivo de churn.",
        border_color="2B6CB0",
        bg_color="F7FAFC"
    )
    
    add_heading_1(doc, "Resumo Executivo")
    add_body_p(
        doc,
        "Este relatório documenta a concepção, implementação e validação de um pipeline analítico de mineração de dados orientado a CRM e marketing para a plataforma Prestador Nota 10. A premissa central estabelece que a extração indiscriminada de regras de associação sobre uma base de transações global gera elevado volume de regras triviais e dilui padrões característicos de clientes de maior valor. Para superar essa limitação, implementou-se o conceito de ensemble sob uma abordagem híbrida: a partir de um Data Warehouse modelado em esquema estrela no PostgreSQL com dimensões conformadas e fatos atômicos, os clientes foram primeiramente clusterizados via algoritmo K-Means com seleção de hiperparâmetro baseada em Silhouette Score. Em seguida, a base transacional foi particionada e o algoritmo FP-Growth foi executado de forma dedicada dentro de cada segmento identificado. Os resultados empíricos demonstram que no grupo de clientes fiéis e de alto valor (ticket médio R$ 542,24) emergiram regras de alta dependência estatística (ex.: Chaveiros e ferragens → Hidráulica com confiança de 52,00% e Lift de 1,390), ao passo que no grupo de clientes inativos e de baixo engajamento não foram identificados itemsets frequentes, validando experimentalmente o benefício da segmentação prévia. Adicionalmente, um módulo supervisionado com ensemble heterogêneo (Random Forest, Gradient Boosting, AdaBoost, Voting e Stacking) foi consolidado para predição de cancelamento de pedidos."
    )
    add_body_p(
        doc,
        "Data Warehouse; Ensemble Learning; K-Means; Regras de Associação; FP-Growth; Segmentação de Clientes; CRM Analítico.",
        bold_prefix="Palavras-chave: "
    )
    
    add_heading_2(doc, "Sumário Estruturado do Relatório")
    sumario_itens = [
        ("Seção 1", "Introdução e Motivação de Negócio — Contexto, objetivos e conceito de ensemble"),
        ("Seção 2", "Arquitetura do Data Warehouse — Camadas OLTP, DW, Datamarts e integração"),
        ("Seção 3", "Etapa 1: Clusterização de Clientes (K-Means) — Features, seleção de k e perfis"),
        ("Seção 4", "Evidências Visuais no Metabase — Catálogo de dados, views e dashboards"),
        ("Seção 5", "Etapa 2: Regras de Associação por Segmento — FP-Growth, métricas e achados"),
        ("Seção 6", "Módulo Complementar: Ensemble de Churn — Classificação supervisionada"),
        ("Seção 7", "Limitações Metodológicas e Riscos Técnicos — Transparência científica"),
        ("Seção 8", "Correções Técnicas Realizadas no Repositório — Histórico de engenharia"),
        ("Seção 9", "Recomendações Estratégicas e Ações de CRM — Matriz de ações táticas"),
        ("Seção 10", "Guia de Reprodutibilidade e Entregáveis — Scripts e inventário de arquivos"),
    ]
    for sec_num, sec_title in sumario_itens:
        add_bullet_p(doc, f" — {sec_title}", bold_prefix=sec_num)
        
    add_heading_2(doc, "Matriz de Conformidade com os Requisitos da Disciplina")
    
    req_headers = ["Requisito do Enunciado", "Status", "Evidência Técnica no Repositório"]
    req_data = [
        ["1. DW / Datamart Construído e Povoado", "Conforme (100%)", "Esquema dimensional dw e datamarts dm_* estruturados e povoados por dw/01..08_*.sql, abrangendo fatos de pedidos, orçamentos, avaliações e agendamentos com integridade referencial."],
        ["2. Aplicação de Ensemble", "Conforme (>100%)", "Implementação dupla: (a) Ensemble Híbrido Metodológico (Clusterização → Regras por Segmento) e (b) Ensemble Preditivo Supervisionado (Bagging, Boosting e Stacking) para predição de churn."],
        ["3. Clusterização / Classificação de Clientes", "Conforme (100%)", "Segmentação não-supervisionada via K-Means sobre 9 features comportamentais (RFM, cancelamento e região), com seleção objetiva de k=2 via Silhouette Score e persistência física em dw.dim_cliente_segmento."],
        ["4. Regras de Associação por Grupo/Classe", "Conforme (100%)", "Mineração via FP-Growth particionada por cluster, demonstrando geração de 8 regras no cluster fiel (Lift até 1.39) e isolamento da esparsidade no cluster inativo."],
        ["5. Bibliotecas Python Especializadas", "Conforme (100%)", "Uso de scikit-learn, mlxtend, pandas, sqlalchemy, matplotlib e tabulate estruturados em mining/requirements.txt."],
        ["6. Entregáveis: Código e Relatório Técnico", "Conforme (100%)", "Código modular versionado, scripts orquestradores .sh e .ps1, relatórios técnicos, visualizações no Metabase, PDF oficial e documento Word editável."]
    ]
    
    tbl_req = doc.add_table(rows=len(req_data) + 1, cols=3)
    for c_i, h_text in enumerate(req_headers):
        tbl_req.rows[0].cells[c_i].paragraphs[0].text = h_text
    for r_i, row_data in enumerate(req_data, start=1):
        for c_i, cell_text in enumerate(row_data):
            tbl_req.rows[r_i].cells[c_i].paragraphs[0].text = cell_text
            
    format_table(
        tbl_req,
        col_widths=[Inches(1.8), Inches(1.1), Inches(3.6)],
        alignments=[WD_ALIGN_PARAGRAPH.LEFT, WD_ALIGN_PARAGRAPH.CENTER, WD_ALIGN_PARAGRAPH.LEFT]
    )
    
    doc.add_page_break()

    # -------------------------------------------------------------
    # SEÇÃO 1: INTRODUÇÃO E MOTIVAÇÃO
    # -------------------------------------------------------------
    add_heading_1(doc, "1. Introdução e Motivação de Negócio")
    
    add_heading_2(doc, "1.1. Contexto do Problema")
    add_body_p(
        doc,
        "A plataforma Prestador Nota 10 opera como um ecossistema digital bilateral (marketplace de serviços), conectando clientes que necessitam de intervenções técnicas e domésticas a prestadores de serviços qualificados. O ciclo transacional engloba a abertura de pedidos, cotação de orçamentos concorrentes, aceitação de propostas, agendamento de atendimentos e avaliação de conformidade."
    )
    add_body_p(
        doc,
        "No gerenciamento de relacionamento com clientes (CRM), um dos objetivos primordiais é estimular o cross-selling (venda cruzada) e o aumento do valor do tempo de vida do cliente (Customer Lifetime Value — LTV). Tradicionalmente, técnicas de Mineração de Regras de Associação (Market Basket Analysis) são empregadas para responder à pergunta: 'Se um cliente contrata o serviço A, qual a probabilidade de ele também necessitar do serviço B?'"
    )
    
    add_heading_2(doc, "1.2. O Desafio da Mineração Global Indiscriminada")
    add_body_p(
        doc,
        "A aplicação direta e simplista de algoritmos como Apriori ou FP-Growth sobre todo o histórico transacional consolidado incorre em severos problemas práticos identificados na literatura de Data Mining:"
    )
    add_bullet_p(
        doc,
        "Clientes fiéis com múltiplos pedidos representam uma fração menor da base, enquanto clientes esporádicos (que contrataram apenas uma vez e nunca mais retornaram) compõem a maioria volumétrica. Quando agregados sem distinção, os clientes de contratação única aumentam o denominador da base sem contribuir com cestas correlacionadas, reduzindo artificialmente o suporte de padrões reais existentes entre os clientes mais engajados.",
        bold_prefix="Diluição Estatística: "
    )
    add_bullet_p(
        doc,
        "Serviços de altíssima frequência marginal (como reparos residenciais básicos) tendem a se associar a qualquer outro serviço simplesmente pelo acaso, gerando métricas de confiança elevadas, mas com Lift próximo a 1,0 (independência estatística entre antecedentes e consequentes).",
        bold_prefix="Regras Espúrias e Não-Acionáveis: "
    )
    
    add_heading_2(doc, "1.3. O Conceito de Ensemble Adotado")
    make_callout(
        doc,
        title="Definição do Pipeline de Ensemble Híbrido:",
        text="Em vez de aplicar um modelo isolado, combinam-se duas famílias de técnicas de aprendizado de máquina em cascata:\n\n1º Estágio (Não-Supervisionado): Clusterização com K-Means para particionar a população de clientes em segmentos homogêneos segundo seu perfil transacional e RFM (Recência, Frequência, Monetário).\n\n2º Estágio (Mineração Simbólica Condicionada): Aplicação de FP-Growth isoladamente dentro de cada segmento, descobrindo regras de associação especializadas e altamente acionáveis para cada perfil de público.",
        border_color="38A169",
        bg_color="F0FFF4"
    )
    
    add_heading_2(doc, "1.4. Diagrama Geral do Pipeline Implementado")
    add_figure(
        doc,
        image_path="mining/diagramas/figura1_pipeline.png",
        caption="Figura 1 — Fluxo de ponta a ponta do ensemble híbrido (Data Warehouse → Feature Engineering → K-Means → Tabela Intermediária → FP-Growth por Segmento).",
        width=Inches(6.4)
    )

    # -------------------------------------------------------------
    # SEÇÃO 2: ARQUITETURA DO DW
    # -------------------------------------------------------------
    add_heading_1(doc, "2. Arquitetura do Data Warehouse e Engenharia de Dados")
    
    add_heading_2(doc, "2.1. Modelagem Dimensional e Camadas")
    add_body_p(
        doc,
        "A estrutura de armazenamento analítico foi desenvolvida no PostgreSQL local (porta 5433 / banco prestadornota10local), distribuída em três camadas desacopladas:"
    )
    add_bullet_p(
        doc,
        "Espelho relacional normalizado da API (tabelas pedido, orcamento_pedido, avaliacao_pedido, agendamento, pessoa, empresa, usuario, categoria_servico), criada por 01_oltp_ddl.sql e populada com 800 pedidos sintéticos por 02_oltp_carga.sql.",
        bold_prefix="Camada Transacional (OLTP — Schema pn10): "
    )
    add_bullet_p(
        doc,
        "Esquema estrela unificado contendo as dimensões conformadas e as tabelas fato no menor grão transacional (DDL em 03_dw_ddl.sql e ETL em 04_dw_carga.sql).",
        bold_prefix="Camada Dimensional Central (DW — Schema dw): "
    )
    add_bullet_p(
        doc,
        "Seis datamarts departamentais construídos por 05_datamart_ddl.sql e carregados por 06_datamart_carga.sql contendo agregações sumarizadas (rollups) para otimização de painéis analíticos.",
        bold_prefix="Camada de Datamarts (Schemas dm_*): "
    )
    
    add_heading_2(doc, "2.2. Diagrama Conceitual do Esquema Estrela (Schema dw)")
    add_figure(
        doc,
        image_path="mining/diagramas/figura2_esquema_dw.png",
        caption="Figura 2 — Arquitetura dimensional estrela com integração da tabela de segmentação de clientes dw.dim_cliente_segmento.",
        width=Inches(6.4)
    )
    
    add_heading_2(doc, "2.3. Tabela de Integração: dw.dim_cliente_segmento")
    add_body_p(
        doc,
        "Para viabilizar a comunicação desacoplada entre a clusterização Python e a etapa de regras de associação, o script dw/09_segmentacao_clientes_ddl.sql define a tabela física dw.dim_cliente_segmento. Esta tabela armazena a atribuição de cluster e rótulo de negócio para cada cliente, viabilizando consultas analíticas no Metabase e filtragem de cestas via SQL:"
    )
    sql_code = """CREATE TABLE dw.dim_cliente_segmento (
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
);"""
    make_code_block(doc, sql_code)

    # -------------------------------------------------------------
    # SEÇÃO 3: CLUSTERIZAÇÃO K-MEANS
    # -------------------------------------------------------------
    add_heading_1(doc, "3. Etapa 1: Clusterização e Segmentação de Clientes (K-Means)")
    
    add_heading_2(doc, "3.1. Engenharia de Features e Transformações")
    add_body_p(
        doc,
        "A partir de consultas agregadas sobre dw.fato_pedido e suas dimensões conformadas, extraíram-se atributos comportamentais no nível de grão de cliente. Foram filtrados exclusivamente os clientes com pelo menos 1 pedido registrado (277 dos 300 clientes cadastrados), visto que clientes sem pedido não possuem cesta transacional:"
    )
    
    feat_headers = ["Atributo", "Tipo", "Tratamento", "Significado no Modelo de Negócio"]
    feat_data = [
        ["qtd_pedidos", "Numérica", "StandardScaler", "Frequência de engajamento do cliente na plataforma."],
        ["valor_total", "Numérica", "StandardScaler", "Dimensão Monetária (faturamento gerado pelo cliente)."],
        ["valor_medio_pedido", "Numérica", "StandardScaler", "Ticket médio por contratação de serviço."],
        ["qtd_categorias_distintas", "Numérica", "StandardScaler", "Diversidade de necessidades atendidas na plataforma."],
        ["taxa_cancelamento", "Numérica", "StandardScaler", "Percentual de pedidos abortados ou cancelados."],
        ["nota_media", "Numérica", "Imputação + Scaler", "Índice de satisfação manifestada nas avaliações."],
        ["recencia_dias", "Numérica", "Imputação + Scaler", "Dias transcorridos desde a última solicitação de serviço."],
        ["tipo_pessoa", "Categórica", "OneHotEncoder", "Segmentação entre Pessoa Física (PF) e Jurídica (PJ)."],
        ["regiao", "Categórica", "OneHotEncoder", "Localização geográfica das solicitações do cliente."]
    ]
    tbl_feat = doc.add_table(rows=len(feat_data) + 1, cols=4)
    for c_i, h_text in enumerate(feat_headers):
        tbl_feat.rows[0].cells[c_i].paragraphs[0].text = h_text
    for r_i, row_data in enumerate(feat_data, start=1):
        for c_i, cell_text in enumerate(row_data):
            tbl_feat.rows[r_i].cells[c_i].paragraphs[0].text = cell_text
            
    format_table(
        tbl_feat,
        col_widths=[Inches(1.6), Inches(0.9), Inches(1.4), Inches(2.6)],
        alignments=[WD_ALIGN_PARAGRAPH.LEFT, WD_ALIGN_PARAGRAPH.CENTER, WD_ALIGN_PARAGRAPH.CENTER, WD_ALIGN_PARAGRAPH.LEFT]
    )
    
    add_heading_2(doc, "3.2. Seleção de Hiperparâmetro (k) e Avaliação de Silhueta")
    add_body_p(
        doc,
        "O algoritmo K-Means foi treinado para diferentes valores de k (variando de 2 a 8). O gráfico comparativo abaixo apresenta a curva de inércia e o coeficiente de silhueta médio calculado para cada partição:"
    )
    add_figure(
        doc,
        image_path="mining/clusterizacao/elbow_silhouette.png",
        caption="Figura 3 — Curva de Inércia (Cotovelo) e Coeficiente de Silhueta para k ∈ [2, 8].",
        width=Inches(5.6)
    )
    
    k_headers = ["Valor de k", "Inércia (Within-Cluster Sum of Squares)", "Silhouette Score Médio", "Interpretação"]
    k_data = [
        ["2", "1625.07", "0.217 (ÓTIMO ESCOLHIDO)", "Maior separabilidade global entre engajados e inativos."],
        ["3", "1424.65", "0.170", "Decaimento acentuado da coesão interna dos clusters."],
        ["4", "1273.95", "0.176", "Partição intermediária sem ganho explicativo."],
        ["5", "1127.95", "0.181", "Subsegmentos menores e fragmentados."],
        ["6", "1026.39", "0.187", "Sobreposição acentuada de perfis transacionais."],
        ["7", "942.05", "0.184", "Instabilidade estatística nas partições."],
        ["8", "895.50", "0.171", "Hiperfragmentação da base de clientes."]
    ]
    tbl_k = doc.add_table(rows=len(k_data) + 1, cols=4)
    for c_i, h_text in enumerate(k_headers):
        tbl_k.rows[0].cells[c_i].paragraphs[0].text = h_text
    for r_i, row_data in enumerate(k_data, start=1):
        for c_i, cell_text in enumerate(row_data):
            tbl_k.rows[r_i].cells[c_i].paragraphs[0].text = cell_text
            
    format_table(
        tbl_k,
        col_widths=[Inches(1.0), Inches(2.0), Inches(1.8), Inches(1.7)],
        alignments=[WD_ALIGN_PARAGRAPH.CENTER, WD_ALIGN_PARAGRAPH.RIGHT, WD_ALIGN_PARAGRAPH.CENTER, WD_ALIGN_PARAGRAPH.LEFT]
    )
    
    add_heading_2(doc, "3.3. Perfil dos Segmentos Descobertos")
    add_body_p(
        doc,
        "A segmentação resultou em dois agrupamentos comportamentais nitidamente contrastantes:"
    )
    
    seg_headers = ["Cluster", "Clientes", "Pedidos Méd.", "Valor Total", "Ticket Médio", "Categorias", "Cancelamento", "Recência", "Rótulo Estratégico"]
    seg_data = [
        ["0", "154 (55,6%)", "1,80", "R$ 803,69", "R$ 475,32", "1,78", "19,0%", "813 dias", "Inativos / Baixo Engajamento"],
        ["1", "123 (44,4%)", "4,25", "R$ 2.186,42", "R$ 542,24", "4,17", "16,0%", "395 dias", "Clientes Fiéis / Alto Valor"]
    ]
    tbl_seg = doc.add_table(rows=len(seg_data) + 1, cols=9)
    for c_i, h_text in enumerate(seg_headers):
        tbl_seg.rows[0].cells[c_i].paragraphs[0].text = h_text
    for r_i, row_data in enumerate(seg_data, start=1):
        for c_i, cell_text in enumerate(row_data):
            tbl_seg.rows[r_i].cells[c_i].paragraphs[0].text = cell_text
            
    format_table(
        tbl_seg,
        col_widths=[Inches(0.6), Inches(0.8), Inches(0.7), Inches(0.8), Inches(0.8), Inches(0.6), Inches(0.7), Inches(0.7), Inches(1.2)],
        alignments=[WD_ALIGN_PARAGRAPH.CENTER, WD_ALIGN_PARAGRAPH.CENTER, WD_ALIGN_PARAGRAPH.RIGHT, WD_ALIGN_PARAGRAPH.RIGHT, WD_ALIGN_PARAGRAPH.RIGHT, WD_ALIGN_PARAGRAPH.CENTER, WD_ALIGN_PARAGRAPH.CENTER, WD_ALIGN_PARAGRAPH.CENTER, WD_ALIGN_PARAGRAPH.LEFT]
    )

    # -------------------------------------------------------------
    # SEÇÃO 4: VISUALIZAÇÃO NO METABASE
    # -------------------------------------------------------------
    add_heading_1(doc, "4. Evidências Visuais e Dashboards no Metabase")
    add_body_p(
        doc,
        "Para comprovar a operacionalização da segmentação em ferramentas de Business Intelligence, a tabela dw.dim_cliente_segmento foi exposta no Metabase através de duas views SQL criadas pelo script metabase/views/vw_segmentacao_clientes.sql: dw.vw_segmentacao_clientes (detalhe por cliente) e dw.vw_resumo_segmento_cliente (perfil médio por cluster)."
    )
    
    add_figure(
        doc,
        image_path="mining/clusterizacao/screenshots/01_schema_dw_tabelas.png",
        caption="Figura 4 — Catálogo de Dados do Metabase exibindo as tabelas físicas do schema dw e as views analíticas de segmentação.",
        width=Inches(6.2)
    )
    
    add_figure(
        doc,
        image_path="mining/clusterizacao/screenshots/02_vw_segmentacao_clientes.png",
        caption="Figura 5 — View dw.vw_segmentacao_clientes: consulta com granularidade de cliente exibindo métricas RFM e rótulos de segmento atribuídos.",
        width=Inches(6.2)
    )
    
    add_figure(
        doc,
        image_path="mining/clusterizacao/screenshots/03_vw_resumo_segmento_cliente_tabela.png",
        caption="Figura 6 — Card analítico de resumo médio por cluster (pedidos médios, ticket médio, recência e faturamento acumulado).",
        width=Inches(5.5)
    )
    
    add_figure(
        doc,
        image_path="mining/clusterizacao/screenshots/04_grafico_clientes_por_segmento.png",
        caption="Figura 7 — Gráfico de contagem de clientes por segmento gerado no Metabase (154 Inativos vs 123 Clientes Fiéis).",
        width=Inches(5.5)
    )

    # -------------------------------------------------------------
    # SEÇÃO 5: REGRAS DE ASSOCIAÇÃO
    # -------------------------------------------------------------
    add_heading_1(doc, "5. Etapa 2: Regras de Associação por Segmento (FP-Growth)")
    
    add_heading_2(doc, "5.1. Modelagem da Cesta de Compras e Rollup de Categorias")
    add_body_p(
        doc,
        "Em um marketplace de serviços, as contratações ocorrem ao longo do tempo. Dessa forma, a cesta de compras de cada cliente foi modelada como o conjunto consolidado de categorias distintas que o cliente já contratou no histórico da plataforma."
    )
    add_body_p(
        doc,
        "Para evitar que a dispersão em ~130 subcategorias finas gerasse suporte nulo para pares de itens, aplicou-se um rollup dimensional para a Macro Categoria de Serviço (campo dim_categoria_servico.descricao_categoria_pai, contendo ~25 macro categorias). Essa agregação é fundamental para que as métricas estatísticas de frequência atinjam significância na base de clientes."
    )
    
    add_heading_2(doc, "5.2. Resultados no Segmento 'Clientes Fiéis / Alto Valor' (123 clientes)")
    add_body_p(
        doc,
        "Executando o algoritmo FP-Growth com suporte mínimo de 8% e limiar de corte por Lift > 1,10, identificaram-se 8 regras de associação estatisticamente consistentes:"
    )
    
    regras_headers = ["Se Contratou (SE)", "Também Contrata (ENTÃO)", "Suporte", "Confiança", "Lift", "Alavancagem", "Convicção"]
    regras_data = [
        ["Chaveiros e ferragens", "Hidráulica", "10,57%", "52,00%", "1,390", "0,030", "1,304"],
        ["Hidráulica", "Chaveiros e ferragens", "10,57%", "28,26%", "1,390", "0,030", "1,111"],
        ["Chaveiros e ferragens", "Residencial", "9,76%", "48,00%", "1,181", "0,015", "1,141"],
        ["Residencial", "Chaveiros e ferragens", "9,76%", "24,00%", "1,181", "0,015", "1,048"],
        ["Automotivo", "Computadores e Tecnologia", "8,13%", "22,73%", "1,165", "0,012", "1,042"],
        ["Computadores e Tecnologia", "Automotivo", "8,13%", "41,67%", "1,165", "0,012", "1,101"],
        ["Hidráulica", "Residencial", "17,07%", "45,65%", "1,123", "0,019", "1,092"],
        ["Residencial", "Hidráulica", "17,07%", "42,00%", "1,123", "0,019", "1,079"]
    ]
    tbl_regras = doc.add_table(rows=len(regras_data) + 1, cols=7)
    for c_i, h_text in enumerate(regras_headers):
        tbl_regras.rows[0].cells[c_i].paragraphs[0].text = h_text
    for r_i, row_data in enumerate(regras_data, start=1):
        for c_i, cell_text in enumerate(row_data):
            tbl_regras.rows[r_i].cells[c_i].paragraphs[0].text = cell_text
            
    format_table(
        tbl_regras,
        col_widths=[Inches(1.8), Inches(1.8), Inches(0.7), Inches(0.7), Inches(0.5), Inches(0.5), Inches(0.5)],
        alignments=[WD_ALIGN_PARAGRAPH.LEFT, WD_ALIGN_PARAGRAPH.LEFT, WD_ALIGN_PARAGRAPH.RIGHT, WD_ALIGN_PARAGRAPH.RIGHT, WD_ALIGN_PARAGRAPH.RIGHT, WD_ALIGN_PARAGRAPH.RIGHT, WD_ALIGN_PARAGRAPH.RIGHT]
    )
    
    add_heading_2(doc, "5.3. Resultados no Segmento 'Inativos / Baixo Engajamento' (154 clientes)")
    make_callout(
        doc,
        title="Diagnóstico Empírico da Segmentação:",
        text="No segmento de clientes inativos, a aplicação do algoritmo FP-Growth com suporte decrescente (8% → 6% → 4,5% → 3% → 2%) não produziu nenhum itemset frequente com 2 ou mais itens.\n\nValidação Experimental: Como este grupo possui média de apenas 1,80 pedidos por cliente e recência média de 813 dias, os clientes não possuem cestas multicategoria. A ausência de regras confirma a hipótese metodológica: misturar esses clientes à base total apenas diluiria as regras do grupo fiel e geraria falsos positivos de independência estatística.",
        border_color="DD6B20",
        bg_color="FFFAF0"
    )
    
    add_heading_2(doc, "5.4. Valor da Abordagem Ensemble vs. Mineração Global Indiscriminada")
    add_body_p(
        doc,
        "Ao comparar os resultados obtidos com e sem segmentação, constata-se a eficácia do ensemble metodológico: na mineração global sem clusterização, a regra 'Chaveiros e ferragens → Hidráulica' tem seu suporte diluído abaixo do limiar de corte estatístico devido ao grande volume de clientes inativos com apenas 1 pedido. O agrupamento prévio atua como um filtro inteligente que preserva a densidade transacional dos clientes valiosos."
    )

    # -------------------------------------------------------------
    # SEÇÃO 6: ENSEMBLE SUPERVISIONADO
    # -------------------------------------------------------------
    add_heading_1(doc, "6. Módulo Complementar: Ensemble de Classificadores para Churn")
    
    add_heading_2(doc, "6.1. Definição do Experimento Supervisionado")
    add_body_p(
        doc,
        "Para consolidar a visão de ensemble sob todas as suas manifestações, o módulo mining/ensemble/treinar_ensemble.py foi mantido e corrigido para treinar classificadores supervisionados para predição da variável binária indicador_cancelado em dw.fato_pedido."
    )
    add_body_p(
        doc,
        "Foram avaliadas as três principais famílias de ensemble: Bagging (Random Forest), Boosting (Gradient Boosting e AdaBoost) e Meta-Ensembles (Voting e Stacking Classifier com meta-modelo em Regressão Logística)."
    )
    
    add_heading_2(doc, "6.2. Comparativo de Desempenho sobre Dados Reais do DW")
    
    ens_headers = ["Modelo Avaliado", "Família", "CV ROC-AUC", "Acurácia (Teste)", "Precisão", "Recall", "F1-Score", "ROC-AUC Teste"]
    ens_data = [
        ["Gradient Boosting", "Boosting", "0,508 (±0,051)", "79,50%", "23,08%", "8,82%", "12,77%", "0,583 (Melhor)"],
        ["Stacking Classifier", "Stacking", "0,485 (±0,053)", "83,00%", "0,00%", "0,00%", "0,00%", "0,577"],
        ["Voting Classifier", "Soft Voting", "0,491 (±0,050)", "80,00%", "0,00%", "0,00%", "0,00%", "0,572"],
        ["Random Forest", "Bagging", "0,489 (±0,054)", "83,00%", "0,00%", "0,00%", "0,00%", "0,533"],
        ["AdaBoost", "Boosting", "0,482 (±0,053)", "83,00%", "0,00%", "0,00%", "0,00%", "0,531"]
    ]
    tbl_ens = doc.add_table(rows=len(ens_data) + 1, cols=8)
    for c_i, h_text in enumerate(ens_headers):
        tbl_ens.rows[0].cells[c_i].paragraphs[0].text = h_text
    for r_i, row_data in enumerate(ens_data, start=1):
        for c_i, cell_text in enumerate(row_data):
            tbl_ens.rows[r_i].cells[c_i].paragraphs[0].text = cell_text
            
    format_table(
        tbl_ens,
        col_widths=[Inches(1.4), Inches(0.9), Inches(1.0), Inches(0.8), Inches(0.6), Inches(0.5), Inches(0.5), Inches(0.8)],
        alignments=[WD_ALIGN_PARAGRAPH.LEFT, WD_ALIGN_PARAGRAPH.CENTER, WD_ALIGN_PARAGRAPH.CENTER, WD_ALIGN_PARAGRAPH.RIGHT, WD_ALIGN_PARAGRAPH.RIGHT, WD_ALIGN_PARAGRAPH.RIGHT, WD_ALIGN_PARAGRAPH.RIGHT, WD_ALIGN_PARAGRAPH.RIGHT]
    )
    
    add_heading_2(doc, "6.3. Importância dos Atributos (Feature Importances - Gradient Boosting)")
    
    imp_headers = ["Variável Explicativa", "Importância Relativa (%)", "Impacto Operacional"]
    imp_data = [
        ["valor_orcamento", "22,24%", "Sensibilidade ao preço cobrado pelo prestador."],
        ["avaliacao_prestador", "12,30%", "Reputação e nível de confiança no profissional."],
        ["dias_para_primeiro_orcamento", "7,37%", "Agilidade na resposta inicial ao pedido."],
        ["qtd_orcamentos_recebidos", "4,39%", "Poder de escolha e concorrência na solicitação."],
        ["qtd_categorias_servico", "4,34%", "Complexidade e diversidade do escopo do serviço."],
        ["mensalidade_plano_prestador", "3,16%", "Nível de engajamento do prestador na plataforma."]
    ]
    tbl_imp = doc.add_table(rows=len(imp_data) + 1, cols=3)
    for c_i, h_text in enumerate(imp_headers):
        tbl_imp.rows[0].cells[c_i].paragraphs[0].text = h_text
    for r_i, row_data in enumerate(imp_data, start=1):
        for c_i, cell_text in enumerate(row_data):
            tbl_imp.rows[r_i].cells[c_i].paragraphs[0].text = cell_text
            
    format_table(
        tbl_imp,
        col_widths=[Inches(2.4), Inches(1.5), Inches(2.6)],
        alignments=[WD_ALIGN_PARAGRAPH.LEFT, WD_ALIGN_PARAGRAPH.RIGHT, WD_ALIGN_PARAGRAPH.LEFT]
    )

    # -------------------------------------------------------------
    # SEÇÃO 7: LIMITAÇÕES METODOLÓGICAS E RISCOS TÉCNICOS
    # -------------------------------------------------------------
    add_heading_1(doc, "7. Limitações Metodológicas e Riscos Técnicos (Transparência Científica)")
    add_body_p(
        doc,
        "Em conformidade com as boas práticas de experimentação e rigor científico, documentam-se as restrições e riscos associados ao experimento:"
    )
    add_bullet_p(
        doc,
        "A base possui 800 pedidos distribuídos entre 277 clientes ativos (~2,9 pedidos por cliente). Para Market Basket Analysis clássico, trata-se de uma base com esparsidade moderada. Os valores de Lift encontrados (máximo 1,390) devem ser interpretados como prova de conceito do pipeline metodológico e não como verdades definitivas de negócio.",
        bold_prefix="Esparsidade da Base Transacional: "
    )
    add_bullet_p(
        doc,
        "O score máximo de silhueta obtido (0,217 para k=2) é baixo em termos absolutos (valores > 0,5 indicam forte densidade e separação). Isso decorre diretamente do fato de os dados do DW serem sintéticos, sem uma regra deliberada de segmentação embutida na geração inicial.",
        bold_prefix="Silhouette Score Moderado (0,217): "
    )
    add_bullet_p(
        doc,
        "Como os dados foram gerados programaticamente sem relações causais determinísticas de cancelamento, os modelos preditivos supervisionados operaram próximos ao baseline aleatório (ROC-AUC 0,583), comprovando que o pipeline lê os dados reais do DW sem artificialismos.",
        bold_prefix="Origem Sintética dos Dados: "
    )
    add_bullet_p(
        doc,
        "Embora necessário para gerar suporte estatístico, o agrupamento em macro categorias perde detalhes específicos (ex.: não distingue instalação de manutenção dentro de Climatização).",
        bold_prefix="Rollup Dimensional de Categorias: "
    )

    # -------------------------------------------------------------
    # SEÇÃO 8: CORREÇÕES TÉCNICAS
    # -------------------------------------------------------------
    add_heading_1(doc, "8. Correções Técnicas Realizadas no Repositório")
    add_body_p(
        doc,
        "Durante a evolução do projeto e consolidação desta branch, foram realizadas correções críticas de engenharia de software:"
    )
    add_bullet_p(
        doc,
        "A connection string postgresql:// (sem driver explícito) fazia o SQLAlchemy 2.1 tentar o dialeto psycopg (v3) em vez de psycopg2 (instalado), caindo silenciosamente no gerador sintético embutido sem tocar no banco de dados real. Corrigido especificando postgresql+psycopg2://.",
        bold_prefix="Correção do Dialeto SQLAlchemy: "
    )
    add_bullet_p(
        doc,
        "Padronização das dependências no arquivo mining/requirements.txt e criação do ambiente virtual mining/.venv devidamente documentado no .gitignore.",
        bold_prefix="Ambiente Python e Dependências: "
    )
    add_bullet_p(
        doc,
        "Ajuste da orquestração para execução a partir da raiz do repositório, evitando a criação de diretórios aninhados como mining/mining/.",
        bold_prefix="Resolução de Caminhos Relativos: "
    )

    # -------------------------------------------------------------
    # SEÇÃO 9: RECOMENDAÇÕES E CRM
    # -------------------------------------------------------------
    add_heading_1(doc, "9. Recomendações Estratégicas de Negócio e Ações de CRM")
    
    add_heading_2(doc, "9.1. Matriz de Ações por Segmento de Cliente")
    
    crm_headers = ["Segmento de Clientes", "Padrão Transacional Descoberto", "Plano de Ação Tático de CRM"]
    crm_data = [
        [
            "Clientes Fiéis / Alto Valor (123 clientes)",
            "Alta afinidade transacional entre Chaveiros, Hidráulica e Residencial (Lift até 1,390 e confiança de 52,00%).",
            "1. Cross-Sell Inteligente: Sugerir agendamento hidráulico durante o checkout de chaveiro.\n2. Pacotes Combinados: Criar combos 'Manutenção Residencial Total' com desconto.\n3. Fidelização: Canal prioritário de suporte e benefícios de pontuação."
        ],
        [
            "Inativos / Baixo Engajamento (154 clientes)",
            "Contratações pontuais e isoladas; ausência de regras frequentes; recência média elevada (813 dias).",
            "1. Evitar ofertas agressivas de cross-sell precoce (alto risco de rejeição).\n2. Campanhas de Reativação: Cupom de desconto com validade de 15 dias para segunda contratação.\n3. Pesquisas de Churn: Questionários rápidos para mapear atritos de preço e atendimento."
        ]
    ]
    tbl_crm = doc.add_table(rows=len(crm_data) + 1, cols=3)
    for c_i, h_text in enumerate(crm_headers):
        tbl_crm.rows[0].cells[c_i].paragraphs[0].text = h_text
    for r_i, row_data in enumerate(crm_data, start=1):
        for c_i, cell_text in enumerate(row_data):
            tbl_crm.rows[r_i].cells[c_i].paragraphs[0].text = cell_text
            
    format_table(
        tbl_crm,
        col_widths=[Inches(1.8), Inches(2.2), Inches(2.5)],
        alignments=[WD_ALIGN_PARAGRAPH.LEFT, WD_ALIGN_PARAGRAPH.LEFT, WD_ALIGN_PARAGRAPH.LEFT]
    )
    
    add_heading_2(doc, "9.2. Próximos Passos Técnicos")
    add_bullet_p(doc, "Aumentar a densidade de pedidos por cliente nos scripts de carga sintética para reduzir a esparsidade transacional.")
    add_bullet_p(doc, "Reavaliar o valor de k à medida que novos dados reais forem integrados ao Data Warehouse.")
    add_bullet_p(doc, "Revisar as features explicativas de cancelamento para identificar métricas de maior poder preditivo.")

    # -------------------------------------------------------------
    # SEÇÃO 10: GUIA DE REPRODUTIBILIDADE
    # -------------------------------------------------------------
    add_heading_1(doc, "10. Guia de Reprodutibilidade e Entregáveis")
    
    add_heading_2(doc, "10.1. Comandos de Execução do Pipeline")
    cmd_code = """# Execução completa ponta a ponta (Linux / macOS):
chmod +x executar_pipeline.sh && ./executar_pipeline.sh

# Execução no Windows (PowerShell):
.\\executar_pipeline.ps1

# Execução individual das etapas de mineração (a partir da raiz):
python3 mining/clusterizacao/segmentar_clientes.py
python3 mining/associacao/regras_associacao.py
python3 mining/ensemble/treinar_ensemble.py"""
    make_code_block(doc, cmd_code)
    
    add_heading_2(doc, "10.2. Inventário de Arquivos do Projeto")
    add_bullet_p(doc, "RELATORIO_TECNICO_FINAL.docx (no root e em mining/) — Relatório oficial em Word totalmente editável.", bold_prefix="Documento Word (.docx): ")
    add_bullet_p(doc, "RELATORIO_TECNICO_FINAL.pdf (no root e em mining/) — Versão final impressa com diagramação ABNT.", bold_prefix="Documento PDF (.pdf): ")
    add_bullet_p(doc, "RELATORIO_TECNICO_FINAL.html e RELATORIO_TECNICO.md — Fontes originais em Markdown e HTML.", bold_prefix="Documentos Fonte: ")
    add_bullet_p(doc, "dw/01_oltp_ddl.sql até dw/09_segmentacao_clientes_ddl.sql — DDL e cargas do Data Warehouse.", bold_prefix="Scripts de Banco (SQL): ")
    add_bullet_p(doc, "mining/clusterizacao/, mining/associacao/ e mining/ensemble/ — Códigos de mineração e aprendizado.", bold_prefix="Scripts de Mineração: ")
    add_bullet_p(doc, "metabase/views/vw_segmentacao_clientes.sql — Views analíticas para dashboards no Metabase.", bold_prefix="Views de BI: ")
    
    # Assinatura
    p_sign = doc.add_paragraph()
    p_sign.paragraph_format.space_before = Pt(30)
    p_sign.paragraph_format.space_after = Pt(2)
    p_sign.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r_s1 = p_sign.add_run("_____________________________________________________\n")
    r_s1.font.name = "Calibri"
    r_s1.font.size = Pt(9.5)
    r_s1.font.color.rgb = RGBColor(0x71, 0x80, 0x96)
    
    r_s2 = p_sign.add_run("Ivânio / Equipe Prestador Nota 10\n")
    r_s2.bold = True
    r_s2.font.name = "Calibri"
    r_s2.font.size = Pt(10)
    r_s2.font.color.rgb = RGBColor(0x1A, 0x20, 0x2C)
    
    r_s3 = p_sign.add_run("Instituto Federal de Educação, Ciência e Tecnologia de Goiás (IFG)\nCâmpus Goiânia")
    r_s3.font.name = "Calibri"
    r_s3.font.size = Pt(8.5)
    r_s3.font.color.rgb = RGBColor(0x4A, 0x55, 0x68)
    
    # Salvando os arquivos
    out_root = "RELATORIO_TECNICO_FINAL.docx"
    out_mining = "mining/RELATORIO_TECNICO_FINAL.docx"
    
    doc.save(out_root)
    shutil.copyfile(out_root, out_mining)
    
    print(f"Sucesso! Relatório Word gerado em:")
    print(f"  - {out_root} ({os.path.getsize(out_root)} bytes)")
    print(f"  - {out_mining} ({os.path.getsize(out_mining)} bytes)")

if __name__ == "__main__":
    construir_relatorio_word()
