-- =====================================================================
-- Prestador Nota 10 - Data Warehouse
-- 07_popular_oltp_sincronizado.sql
--
-- Popula as tabelas TRANSACIONAIS do schema operacional (public) da API
-- com os MESMOS dados sintéticos já carregados no DW (schemas dw/dm_*),
-- garantindo que OLTP e DW fiquem sincronizados (mesmos clientes,
-- prestadores, pedidos, orçamentos, avaliações, agendamentos e planos).
--
-- Pré-requisitos:
--   * DDL do OLTP já aplicado (Flyway ou dw/00_script_unificado_pn10.sql)
--   * DW já populado (scripts 00 a 06 deste diretório)
--
-- Tabelas populadas (todas estavam vazias, exceto 'usuario' que já
-- possui os usuários de sistema SISTEMA(1)/ADMIN(2), preservados):
--   plano, pessoa, empresa, contato(+pessoa/empresa), endereco(+pessoa/empresa),
--   usuario, usuario_grupo, agenda, categoria_servico_prestador, pedido,
--   pedido_categoria_servico, orcamento_pedido, historico_situacao_pedido,
--   agendamento, avaliacao_pedido
-- =====================================================================

-- Idempotência: remove qualquer carga sintética anterior antes de repopular
-- (não afeta dados mestre: cidade, estado, categoria_servico, tipo_*, banco,
-- permissao, grupo, grupo_permissao, oauth_client_details, usuario 1/2)
DELETE FROM public.avaliacao_pedido;
DELETE FROM public.agendamento;
DELETE FROM public.historico_situacao_pedido;
DELETE FROM public.orcamento_pedido;
DELETE FROM public.pedido_categoria_servico;
DELETE FROM public.pedido;
DELETE FROM public.categoria_servico_prestador;
DELETE FROM public.agenda;
DELETE FROM public.usuario_grupo WHERE codigo_usuario > 2;
DELETE FROM public.contato_pessoa;
DELETE FROM public.contato_empresa;
DELETE FROM public.endereco_pessoa;
DELETE FROM public.endereco_empresa;
DELETE FROM public.contato;
DELETE FROM public.endereco;
DELETE FROM public.usuario WHERE codigo > 2;
DELETE FROM public.pessoa;
DELETE FROM public.empresa;
DELETE FROM public.plano;

ALTER SEQUENCE public.plano_codigo_seq RESTART WITH 1;
ALTER SEQUENCE public.pessoa_codigo_seq RESTART WITH 1;
ALTER SEQUENCE public.empresa_codigo_seq RESTART WITH 1;
ALTER SEQUENCE public.contato_codigo_seq RESTART WITH 1;
ALTER SEQUENCE public.endereco_codigo_seq RESTART WITH 1;
ALTER SEQUENCE public.usuario_codigo_seq RESTART WITH 3;
ALTER SEQUENCE public.agenda_codigo_seq RESTART WITH 1;
ALTER SEQUENCE public.pedido_codigo_seq RESTART WITH 1;
ALTER SEQUENCE public.orcamento_pedido_codigo_seq RESTART WITH 1;
ALTER SEQUENCE public.historico_situacao_pedido_codigo_seq RESTART WITH 1;
ALTER SEQUENCE public.agendamento_codigo_seq RESTART WITH 1;
ALTER SEQUENCE public.avaliacao_pedido_codigo_seq RESTART WITH 1;

-- Tabelas temporárias de mapeamento DW (surrogate key) -> OLTP (codigo real)
CREATE TEMP TABLE tmp_map_plano (sk_plano integer PRIMARY KEY, codigo_plano integer);
CREATE TEMP TABLE tmp_map_cliente (sk_cliente integer PRIMARY KEY, codigo_usuario integer);
CREATE TEMP TABLE tmp_map_prestador (sk_prestador integer PRIMARY KEY, codigo_usuario integer, codigo_agenda integer);
CREATE TEMP TABLE tmp_map_pedido (sk_pedido bigint PRIMARY KEY, codigo_pedido_dw integer, codigo_pedido_oltp integer);
CREATE TEMP TABLE tmp_map_orcamento (sk_orcamento bigint PRIMARY KEY, codigo_orcamento_oltp integer);
CREATE TEMP TABLE tmp_map_agendamento (sk_agendamento bigint PRIMARY KEY, codigo_agendamento_oltp integer);

-- ---------------------------------------------------------------------
-- 1) Planos comerciais
-- ---------------------------------------------------------------------
DO $$
DECLARE
    rec record;
    v_codigo integer;
BEGIN
    FOR rec IN SELECT * FROM dw.dim_plano ORDER BY sk_plano LOOP
        INSERT INTO public.plano (ativo, deletado, descricao, limite_clientes_mensal, data_cadastro, data_atualizacao, codigo_usuario_cadastro, codigo_usuario_atualizacao)
        VALUES (rec.ativo, false, rec.descricao, rec.limite_clientes_mensal, now(), now(), 1, 1)
        RETURNING codigo INTO v_codigo;
        INSERT INTO tmp_map_plano VALUES (rec.sk_plano, v_codigo);
    END LOOP;
END $$;

-- ---------------------------------------------------------------------
-- 2) Clientes: pessoa/empresa + contato + endereco + usuario
-- ---------------------------------------------------------------------
DO $$
DECLARE
    rec               record;
    v_codigo_pf_pj     integer;
    v_codigo_contato   integer;
    v_codigo_endereco  integer;
    v_codigo_usuario   integer;
    v_sexo             varchar(30);
    v_email            varchar(150);
    v_celular          varchar(20);
    v_cpf_cnpj         varchar(20);
    v_seq              integer := 0;
BEGIN
    FOR rec IN
        SELECT c.*, cid.codigo_cidade, cid.nome_cidade, cid.uf
        FROM dw.dim_cliente c
        JOIN dw.dim_cidade cid ON cid.sk_cidade = c.sk_cidade
        ORDER BY c.sk_cliente
    LOOP
        v_seq := v_seq + 1;
        v_email := 'cliente.sint' || v_seq || '@pn10.dev';
        v_celular := '62' || lpad((90000000 + v_seq)::text, 8, '0');

        IF rec.tipo_pessoa = 'PF' THEN
            v_sexo := CASE WHEN v_seq % 2 = 0 THEN 'HOMEM' ELSE 'MULHER' END;
            v_cpf_cnpj := lpad((1000000000 + v_seq)::text, 11, '0');
            INSERT INTO public.pessoa (nome, cpf, sexo, data_nascimento, ativo, codigo_tipo_pessoa, data_cadastro, data_atualizacao, codigo_usuario_cadastro, codigo_usuario_atualizacao, deletado, situacao_cadastral)
            VALUES (rec.nome, v_cpf_cnpj, v_sexo, rec.data_cadastro - interval '25 years' - (v_seq || ' days')::interval, rec.ativo, 3, rec.data_cadastro, rec.data_cadastro, 1, 1, false, 'COMPLETO')
            RETURNING codigo INTO v_codigo_pf_pj;
        ELSE
            v_cpf_cnpj := lpad((20000000000000 + v_seq)::bigint::text, 14, '0');
            INSERT INTO public.empresa (nome_fantasia, razao_social, cnpj, ativo, codigo_tipo_empresa, data_cadastro, data_atualizacao, codigo_usuario_cadastro, codigo_usuario_atualizacao, deletado, tempo_mercado, situacao_cadastral)
            VALUES (rec.nome, rec.nome || ' LTDA', v_cpf_cnpj, rec.ativo, 2, rec.data_cadastro, rec.data_cadastro, 1, 1, false, 1 + (v_seq % 20), 'COMPLETO')
            RETURNING codigo INTO v_codigo_pf_pj;
        END IF;

        INSERT INTO public.contato (telefone_celular, email, contato_principal, codigo_tipo_contato, deletado, data_cadastro, data_atualizacao, codigo_usuario_cadastro, codigo_usuario_atualizacao, situacao_cadastral)
        VALUES (v_celular, v_email, true, 2, false, rec.data_cadastro, rec.data_cadastro, 1, 1, 'COMPLETO')
        RETURNING codigo INTO v_codigo_contato;

        INSERT INTO public.endereco (logradouro, numero, cep, bairro, codigo_cidade, endereco_principal, codigo_tipo_endereco, data_cadastro, data_atualizacao, codigo_usuario_cadastro, codigo_usuario_atualizacao, deletado, situacao_cadastral)
        VALUES ('Rua Sintética ' || v_seq, (v_seq % 999 + 1)::text, lpad((74000000 + v_seq)::text, 8, '0'), 'Centro', rec.codigo_cidade, true, 2, rec.data_cadastro, rec.data_cadastro, 1, 1, false, 'COMPLETO')
        RETURNING codigo INTO v_codigo_endereco;

        IF rec.tipo_pessoa = 'PF' THEN
            INSERT INTO public.contato_pessoa VALUES (v_codigo_pf_pj, v_codigo_contato);
            INSERT INTO public.endereco_pessoa VALUES (v_codigo_pf_pj, v_codigo_endereco);
        ELSE
            INSERT INTO public.contato_empresa VALUES (v_codigo_pf_pj, v_codigo_contato);
            INSERT INTO public.endereco_empresa VALUES (v_codigo_pf_pj, v_codigo_endereco);
        END IF;

        INSERT INTO public.usuario (
            nome, ativo, login, senha, data_cadastro, data_atualizacao, tipo_usuario, deletado,
            codigo_usuario_cadastro, codigo_usuario_atualizacao, codigo_pessoa, codigo_empresa,
            verificado, data_verificacao, avaliacoes, curtidas, visualizacoes, confirmar_termos, receber_promocoes
        ) VALUES (
            rec.nome, rec.ativo, v_email, '$2a$10$sintetico.hash.nao.utilizavel.para.login.0000000000000000',
            rec.data_cadastro, rec.data_cadastro, 'CLIENTE', false,
            1, 1,
            CASE WHEN rec.tipo_pessoa = 'PF' THEN v_codigo_pf_pj ELSE NULL END,
            CASE WHEN rec.tipo_pessoa = 'PJ' THEN v_codigo_pf_pj ELSE NULL END,
            true, rec.data_cadastro, 0, 0, 0, true, (v_seq % 3 = 0)
        ) RETURNING codigo INTO v_codigo_usuario;

        INSERT INTO public.usuario_grupo VALUES (v_codigo_usuario, 3); -- grupo CLIENTE

        INSERT INTO tmp_map_cliente VALUES (rec.sk_cliente, v_codigo_usuario);
    END LOOP;
END $$;

-- ---------------------------------------------------------------------
-- 3) Prestadores: pessoa/empresa + contato + endereco + usuario + agenda
-- ---------------------------------------------------------------------
DO $$
DECLARE
    rec               record;
    v_codigo_pf_pj     integer;
    v_codigo_contato   integer;
    v_codigo_endereco  integer;
    v_codigo_usuario   integer;
    v_codigo_agenda    integer;
    v_codigo_plano     integer;
    v_sexo             varchar(30);
    v_email            varchar(150);
    v_celular          varchar(20);
    v_cpf_cnpj         varchar(20);
    v_seq              integer := 0;
BEGIN
    FOR rec IN
        SELECT p.*, cid.codigo_cidade, cid.nome_cidade, cid.uf
        FROM dw.dim_prestador p
        JOIN dw.dim_cidade cid ON cid.sk_cidade = p.sk_cidade
        ORDER BY p.sk_prestador
    LOOP
        v_seq := v_seq + 1;
        v_email := 'prestador.sint' || v_seq || '@pn10.dev';
        v_celular := '62' || lpad((80000000 + v_seq)::text, 8, '0');

        IF rec.tipo_pessoa = 'PF' THEN
            v_sexo := CASE WHEN v_seq % 2 = 0 THEN 'HOMEM' ELSE 'MULHER' END;
            v_cpf_cnpj := lpad((3000000000 + v_seq)::text, 11, '0');
            INSERT INTO public.pessoa (nome, cpf, sexo, data_nascimento, ativo, codigo_tipo_pessoa, data_cadastro, data_atualizacao, codigo_usuario_cadastro, codigo_usuario_atualizacao, deletado, situacao_cadastral)
            VALUES (rec.nome, v_cpf_cnpj, v_sexo, rec.data_cadastro - interval '30 years' - (v_seq || ' days')::interval, rec.ativo, 4, rec.data_cadastro, rec.data_cadastro, 1, 1, false, 'COMPLETO')
            RETURNING codigo INTO v_codigo_pf_pj;
        ELSE
            v_cpf_cnpj := lpad((40000000000000 + v_seq)::bigint::text, 14, '0');
            INSERT INTO public.empresa (nome_fantasia, razao_social, cnpj, ativo, codigo_tipo_empresa, data_cadastro, data_atualizacao, codigo_usuario_cadastro, codigo_usuario_atualizacao, deletado, tempo_mercado, situacao_cadastral)
            VALUES (rec.nome, rec.nome || ' LTDA', v_cpf_cnpj, rec.ativo, 2, rec.data_cadastro, rec.data_cadastro, 1, 1, false, 1 + (v_seq % 15), 'COMPLETO')
            RETURNING codigo INTO v_codigo_pf_pj;
        END IF;

        INSERT INTO public.contato (telefone_celular, email, contato_principal, codigo_tipo_contato, deletado, data_cadastro, data_atualizacao, codigo_usuario_cadastro, codigo_usuario_atualizacao, situacao_cadastral)
        VALUES (v_celular, v_email, true, 3, false, rec.data_cadastro, rec.data_cadastro, 1, 1, 'COMPLETO')
        RETURNING codigo INTO v_codigo_contato;

        INSERT INTO public.endereco (logradouro, numero, cep, bairro, codigo_cidade, endereco_principal, codigo_tipo_endereco, data_cadastro, data_atualizacao, codigo_usuario_cadastro, codigo_usuario_atualizacao, deletado, situacao_cadastral)
        VALUES ('Avenida Sintética ' || v_seq, (v_seq % 999 + 1)::text, lpad((75000000 + v_seq)::text, 8, '0'), 'Setor Central', rec.codigo_cidade, true, 3, rec.data_cadastro, rec.data_cadastro, 1, 1, false, 'COMPLETO')
        RETURNING codigo INTO v_codigo_endereco;

        IF rec.tipo_pessoa = 'PF' THEN
            INSERT INTO public.contato_pessoa VALUES (v_codigo_pf_pj, v_codigo_contato);
            INSERT INTO public.endereco_pessoa VALUES (v_codigo_pf_pj, v_codigo_endereco);
        ELSE
            INSERT INTO public.contato_empresa VALUES (v_codigo_pf_pj, v_codigo_contato);
            INSERT INTO public.endereco_empresa VALUES (v_codigo_pf_pj, v_codigo_endereco);
        END IF;

        SELECT codigo_plano INTO v_codigo_plano FROM tmp_map_plano WHERE sk_plano = rec.sk_plano;

        INSERT INTO public.usuario (
            nome, ativo, login, senha, data_cadastro, data_atualizacao, tipo_usuario, deletado,
            codigo_usuario_cadastro, codigo_usuario_atualizacao, codigo_pessoa, codigo_empresa, codigo_plano,
            avaliacao_media, verificado, data_verificacao, avaliacoes, curtidas, visualizacoes, confirmar_termos, receber_promocoes
        ) VALUES (
            rec.nome, rec.ativo, v_email, '$2a$10$sintetico.hash.nao.utilizavel.para.login.0000000000000000',
            rec.data_cadastro, rec.data_cadastro, 'PRESTADOR', false,
            1, 1,
            CASE WHEN rec.tipo_pessoa = 'PF' THEN v_codigo_pf_pj ELSE NULL END,
            CASE WHEN rec.tipo_pessoa = 'PJ' THEN v_codigo_pf_pj ELSE NULL END,
            v_codigo_plano,
            rec.avaliacao_media, true, rec.data_cadastro, COALESCE(rec.qtd_avaliacoes, 0), 0, 10 + v_seq, true, (v_seq % 4 = 0)
        ) RETURNING codigo INTO v_codigo_usuario;

        INSERT INTO public.usuario_grupo VALUES (v_codigo_usuario, 2); -- grupo PRESTADOR

        INSERT INTO public.agenda (
            codigo_prestador, inicio_periodo_matituno, fim_periodo_matituno, inicio_periodo_vespertino, fim_periodo_vespertino,
            inicio_periodo_noturno, fim_periodo_noturno, atende_feriado, atende_dias_semana, max_agendamento_diario,
            tempo_minutos_entre_atendimentos, data_cadastro, data_atualizacao, codigo_usuario_cadastro, codigo_usuario_atualizacao
        ) VALUES (
            v_codigo_usuario, '08:00', '12:00', '13:00', '18:00', '19:00', '21:00', false,
            'SEGUNDA_FEIRA', 8, 30, rec.data_cadastro, rec.data_cadastro, v_codigo_usuario, v_codigo_usuario
        ) RETURNING codigo INTO v_codigo_agenda;

        INSERT INTO tmp_map_prestador VALUES (rec.sk_prestador, v_codigo_usuario, v_codigo_agenda);
    END LOOP;
END $$;

-- ---------------------------------------------------------------------
-- 4) Precificação por categoria (categoria_servico_prestador)
-- ---------------------------------------------------------------------
INSERT INTO public.categoria_servico_prestador (codigo_categoria_servico, codigo_prestador, valor_medio_cobrado)
SELECT cat.codigo_categoria, mp.codigo_usuario, fpc.valor_medio_cobrado
FROM dm_prestadores.fato_precificacao_categoria fpc
JOIN dw.dim_categoria_servico cat ON cat.sk_categoria_servico = fpc.sk_categoria_servico
JOIN tmp_map_prestador mp ON mp.sk_prestador = fpc.sk_prestador;

-- ---------------------------------------------------------------------
-- 5) Pedidos + categorias do pedido
-- ---------------------------------------------------------------------
DO $$
DECLARE
    rec record;
    v_codigo_pedido integer;
    v_codigo_cliente integer;
    v_data_atualizacao timestamptz;
BEGIN
    FOR rec IN
        SELECT fp.*, dta.data AS data_abertura, dtf.data AS data_finalizacao,
               cat.codigo_categoria, cat.descricao AS categoria_descricao,
               cid.codigo_cidade, sit.situacao
        FROM dm_pedidos.fato_pedido fp
        JOIN dw.dim_tempo dta ON dta.sk_tempo = fp.sk_tempo_abertura
        LEFT JOIN dw.dim_tempo dtf ON dtf.sk_tempo = fp.sk_tempo_finalizacao
        JOIN dw.dim_categoria_servico cat ON cat.sk_categoria_servico = fp.sk_categoria_servico
        JOIN dw.dim_cidade cid ON cid.sk_cidade = fp.sk_cidade
        JOIN dw.dim_situacao_pedido sit ON sit.sk_situacao_pedido = fp.sk_situacao_pedido
        ORDER BY fp.codigo_pedido
    LOOP
        SELECT codigo_usuario INTO v_codigo_cliente FROM tmp_map_cliente WHERE sk_cliente = rec.sk_cliente;
        v_data_atualizacao := COALESCE(rec.data_finalizacao::timestamptz, rec.data_abertura::timestamptz) + interval '1 hour';

        INSERT INTO public.pedido (
            descricao, situacao, endereco_atendimento_logradouro, endereco_atendimento_numero, endereco_atendimento_cep,
            endereco_atendimento_bairro, endereco_atendimento_codigo_cidade, codigo_cliente, data_finalizacao_atendimento,
            data_cadastro, data_atualizacao, codigo_usuario_cadastro, codigo_usuario_atualizacao
        ) VALUES (
            'Preciso de um serviço de ' || rec.categoria_descricao || ' (pedido sintético #' || rec.codigo_pedido || ')',
            rec.situacao,
            'Rua do Atendimento ' || rec.codigo_pedido, (rec.codigo_pedido % 999 + 1)::text, lpad((76000000 + rec.codigo_pedido)::text, 8, '0'),
            'Centro', rec.codigo_cidade, v_codigo_cliente, rec.data_finalizacao,
            rec.data_abertura, v_data_atualizacao, v_codigo_cliente, v_codigo_cliente
        ) RETURNING codigo INTO v_codigo_pedido;

        INSERT INTO public.pedido_categoria_servico VALUES (v_codigo_pedido, rec.codigo_categoria);

        INSERT INTO tmp_map_pedido VALUES (rec.sk_pedido, rec.codigo_pedido, v_codigo_pedido);
    END LOOP;
END $$;

-- ---------------------------------------------------------------------
-- 6) Orçamentos
-- ---------------------------------------------------------------------
DO $$
DECLARE
    rec record;
    v_codigo_orcamento integer;
    v_codigo_prestador integer;
    v_codigo_pedido integer;
BEGIN
    FOR rec IN
        SELECT fo.*, dtc.data AS data_criacao, dtv.data AS data_validade, sit.situacao
        FROM dm_orcamentos.fato_orcamento fo
        JOIN dw.dim_tempo dtc ON dtc.sk_tempo = fo.sk_tempo_criacao
        LEFT JOIN dw.dim_tempo dtv ON dtv.sk_tempo = fo.sk_tempo_validade
        JOIN dw.dim_situacao_orcamento sit ON sit.sk_situacao_orcamento = fo.sk_situacao_orcamento
        ORDER BY fo.codigo_orcamento
    LOOP
        SELECT codigo_usuario INTO v_codigo_prestador FROM tmp_map_prestador WHERE sk_prestador = rec.sk_prestador;
        SELECT codigo_pedido_oltp INTO v_codigo_pedido FROM tmp_map_pedido WHERE sk_pedido = rec.sk_pedido;

        INSERT INTO public.orcamento_pedido (
            codigo_prestador, codigo_pedido, solicitado_pelo_cliente, descricao, data_validade,
            data_cadastro, data_atualizacao, codigo_usuario_cadastro, codigo_usuario_atualizacao,
            valor, situacao, motivo_cancelamento
        ) VALUES (
            v_codigo_prestador, v_codigo_pedido, rec.solicitado_pelo_cliente,
            'Orçamento sintético #' || rec.codigo_orcamento, rec.data_validade,
            rec.data_criacao, rec.data_criacao, v_codigo_prestador, v_codigo_prestador,
            rec.valor, rec.situacao,
            CASE WHEN rec.situacao = 'CANCELADO' THEN 'Orçamento recusado/cancelado (dado sintético)' ELSE NULL END
        ) RETURNING codigo INTO v_codigo_orcamento;

        INSERT INTO tmp_map_orcamento VALUES (rec.sk_orcamento, v_codigo_orcamento);
    END LOOP;
END $$;

-- vincula o orçamento selecionado a cada pedido
UPDATE public.pedido p
SET codigo_orcamento_selecionado = mo.codigo_orcamento_oltp
FROM dm_orcamentos.fato_orcamento fo
JOIN tmp_map_orcamento mo ON mo.sk_orcamento = fo.sk_orcamento
JOIN tmp_map_pedido mp ON mp.sk_pedido = fo.sk_pedido
WHERE fo.foi_selecionado = true
  AND p.codigo = mp.codigo_pedido_oltp;

-- ---------------------------------------------------------------------
-- 7) Histórico de situação do pedido
-- ---------------------------------------------------------------------
INSERT INTO public.historico_situacao_pedido (codigo_pedido, situacao, data_atualizacao)
SELECT mp.codigo_pedido_oltp, sit.situacao, dt.data
FROM dm_pedidos.fato_historico_situacao_pedido h
JOIN tmp_map_pedido mp ON mp.sk_pedido = h.sk_pedido
JOIN dw.dim_situacao_pedido sit ON sit.sk_situacao_pedido = h.sk_situacao_pedido
JOIN dw.dim_tempo dt ON dt.sk_tempo = h.sk_tempo
ORDER BY mp.codigo_pedido_oltp, h.ordem_transicao;

-- ---------------------------------------------------------------------
-- 8) Agendamentos
-- ---------------------------------------------------------------------
DO $$
DECLARE
    rec record;
    v_codigo_agendamento integer;
    v_codigo_agenda integer;
    v_codigo_pedido integer;
BEGIN
    FOR rec IN
        SELECT fg.*, dti.data AS data_inicio, dtf.data AS data_fim
        FROM dm_agendamentos.fato_agendamento fg
        JOIN dw.dim_tempo dti ON dti.sk_tempo = fg.sk_tempo_inicio
        JOIN dw.dim_tempo dtf ON dtf.sk_tempo = fg.sk_tempo_fim
        ORDER BY fg.codigo_agendamento
    LOOP
        SELECT codigo_agenda INTO v_codigo_agenda FROM tmp_map_prestador WHERE sk_prestador = rec.sk_prestador;
        SELECT codigo_pedido_oltp INTO v_codigo_pedido FROM tmp_map_pedido WHERE sk_pedido = rec.sk_pedido;

        INSERT INTO public.agendamento (
            codigo_agenda, data_cadastro, data_atualizacao, codigo_usuario_atualizacao, codigo_usuario_cadastro,
            data_inicio_agenda, data_fim_agenda, codigo_pedido
        ) VALUES (
            v_codigo_agenda, rec.data_inicio, rec.data_inicio,
            1, 1,
            rec.data_inicio + interval '9 hours',
            rec.data_inicio + interval '9 hours' + (rec.duracao_minutos || ' minutes')::interval,
            v_codigo_pedido
        ) RETURNING codigo INTO v_codigo_agendamento;

        INSERT INTO tmp_map_agendamento VALUES (rec.sk_agendamento, v_codigo_agendamento);
    END LOOP;
END $$;

-- vincula o agendamento ao pedido
UPDATE public.pedido p
SET codigo_agendamento = ma.codigo_agendamento_oltp
FROM dm_agendamentos.fato_agendamento fg
JOIN tmp_map_agendamento ma ON ma.sk_agendamento = fg.sk_agendamento
JOIN tmp_map_pedido mp ON mp.sk_pedido = fg.sk_pedido
WHERE p.codigo = mp.codigo_pedido_oltp;

-- ---------------------------------------------------------------------
-- 9) Avaliações
-- ---------------------------------------------------------------------
INSERT INTO public.avaliacao_pedido (avaliacao, codigo_pedido, descricao, data_avaliacao)
SELECT round(fa.nota)::integer, mp.codigo_pedido_oltp,
       'Avaliação sintética: nota ' || fa.nota || '/5 para o pedido #' || mp.codigo_pedido_dw,
       dt.data
FROM dm_avaliacoes.fato_avaliacao fa
JOIN tmp_map_pedido mp ON mp.sk_pedido = fa.sk_pedido
JOIN dw.dim_tempo dt ON dt.sk_tempo = fa.sk_tempo;
