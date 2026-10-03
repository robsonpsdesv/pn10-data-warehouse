-- =====================================================================
-- Prestador Nota 10 - Data Warehouse
-- 08_data_quality_tests.sql
--
-- Script de Testes de Qualidade de Dados (Data Quality / Data Testing).
-- Executa verificações automatizadas de integridade referencial,
-- consistência temporal, limites de valores e regras de negócio.
-- Retorna uma tabela com o resultado de cada teste (PASS / FAIL).
-- =====================================================================

DO $$
DECLARE
    v_falhas integer := 0;
    r RECORD;
BEGIN
    RAISE NOTICE '=====================================================';
    RAISE NOTICE 'INICIANDO TESTES DE QUALIDADE DE DADOS DO DW (PN10)';
    RAISE NOTICE '=====================================================';

    -- Tabela temporária para consolidar resultados
    CREATE TEMP TABLE IF NOT EXISTS temp_dq_results (
        id_teste serial PRIMARY KEY,
        categoria varchar(50),
        descricao_teste text,
        status varchar(10),
        detalhe text
    ) ON COMMIT DROP;

    DELETE FROM temp_dq_results;

    -- -----------------------------------------------------------------
    -- TESTE 1: Integridade Referencial Fato Pedido -> Dimensões
    -- -----------------------------------------------------------------
    INSERT INTO temp_dq_results (categoria, descricao_teste, status, detalhe)
    SELECT 
        'Integridade Referencial',
        'Verifica se há fatos_pedido com FKs inválidas ou órfãs',
        CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
        'Registros inválidos encontrados: ' || count(*)
    FROM dw.fato_pedido fp
    LEFT JOIN dw.dim_cliente c ON fp.sk_cliente = c.sk_cliente
    LEFT JOIN dw.dim_cidade cd ON fp.sk_cidade = cd.sk_cidade
    LEFT JOIN dw.dim_categoria_servico cs ON fp.sk_categoria_servico = cs.sk_categoria_servico
    LEFT JOIN dw.dim_situacao_pedido sp ON fp.sk_situacao_pedido = sp.sk_situacao_pedido
    WHERE c.sk_cliente IS NULL 
       OR cd.sk_cidade IS NULL 
       OR cs.sk_categoria_servico IS NULL 
       OR sp.sk_situacao_pedido IS NULL;

    -- -----------------------------------------------------------------
    -- TESTE 2: Consistência Temporal (Finalização >= Abertura)
    -- -----------------------------------------------------------------
    INSERT INTO temp_dq_results (categoria, descricao_teste, status, detalhe)
    SELECT 
        'Consistência Temporal',
        'Garante que sk_tempo_finalizacao >= sk_tempo_abertura em pedidos finalizados',
        CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
        'Pedidos com data de fim anterior ao início: ' || count(*)
    FROM dw.fato_pedido
    WHERE sk_tempo_finalizacao IS NOT NULL 
      AND sk_tempo_finalizacao < sk_tempo_abertura;

    -- -----------------------------------------------------------------
    -- TESTE 3: Limites das Notas de Avaliação (1.0 <= nota <= 5.0)
    -- -----------------------------------------------------------------
    INSERT INTO temp_dq_results (categoria, descricao_teste, status, detalhe)
    SELECT 
        'Regra de Domínio',
        'Garante que todas as notas de avaliação estão estritamente entre 1.0 e 5.0',
        CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
        'Avaliações fora do intervalo permitido: ' || count(*)
    FROM dw.fato_avaliacao
    WHERE nota < 1.0 OR nota > 5.0;

    -- -----------------------------------------------------------------
    -- TESTE 4: Consistência de Pedidos Cancelados
    -- -----------------------------------------------------------------
    INSERT INTO temp_dq_results (categoria, descricao_teste, status, detalhe)
    SELECT 
        'Regra de Negócio',
        'Garante que pedidos com indicador_cancelado = true tenham situacao CANCELADO',
        CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
        'Inconsistências de flag cancelado vs situação: ' || count(*)
    FROM dw.fato_pedido fp
    JOIN dw.dim_situacao_pedido sp ON fp.sk_situacao_pedido = sp.sk_situacao_pedido
    WHERE (fp.indicador_cancelado = true AND sp.situacao <> 'CANCELADO')
       OR (fp.indicador_cancelado = false AND sp.situacao = 'CANCELADO');

    -- -----------------------------------------------------------------
    -- TESTE 5: Consistência de Orçamento Selecionado
    -- -----------------------------------------------------------------
    INSERT INTO temp_dq_results (categoria, descricao_teste, status, detalhe)
    SELECT 
        'Regra de Negócio',
        'Garante que nenhum pedido tenha mais de 1 orçamento selecionado',
        CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
        'Pedidos com múltiplos orçamentos aceitos: ' || count(*)
    FROM (
        SELECT sk_pedido, count(*) as qtd_aceitos
        FROM dw.fato_orcamento
        WHERE foi_selecionado = true
        GROUP BY sk_pedido
        HAVING count(*) > 1
    ) sub;

    -- -----------------------------------------------------------------
    -- TESTE 6: Unicidade das Dimensões Mestre
    -- -----------------------------------------------------------------
    INSERT INTO temp_dq_results (categoria, descricao_teste, status, detalhe)
    SELECT 
        'Unicidade',
        'Garante que não existem códigos de clientes duplicados na dimensão dim_cliente',
        CASE WHEN count(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
        'Clientes com código duplicado: ' || count(*)
    FROM (
        SELECT codigo_cliente, count(*)
        FROM dw.dim_cliente
        GROUP BY codigo_cliente
        HAVING count(*) > 1
    ) sub;

    -- Exibição no console do Postgres
    FOR r IN SELECT * FROM temp_dq_results ORDER BY id_teste LOOP
        IF r.status = 'PASS' THEN
            RAISE NOTICE '[✓ PASS] % | % (%)', r.categoria, r.descricao_teste, r.detalhe;
        ELSE
            RAISE WARNING '[✗ FAIL] % | % (%)', r.categoria, r.descricao_teste, r.detalhe;
            v_falhas := v_falhas + 1;
        END IF;
    END LOOP;

    RAISE NOTICE '-----------------------------------------------------';
    IF v_falhas = 0 THEN
        RAISE NOTICE 'SUCESSO: Todos os testes de qualidade foram aprovados com 100%% de conformidade!';
    ELSE
        RAISE EXCEPTION 'FALHA DE QUALIDADE: Foram encontradas % falhas nos dados do DW.', v_falhas;
    END IF;
    RAISE NOTICE '=====================================================';
END $$;
