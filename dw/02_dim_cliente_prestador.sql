-- =====================================================================
-- Prestador Nota 10 - Data Warehouse
-- 02_dim_cliente_prestador.sql
--
-- Dimensões de Cliente e Prestador (conformadas, usadas por vários
-- datamarts). Como as tabelas transacionais do OLTP (pessoa, empresa,
-- usuario) estão vazias no ambiente local, estas dimensões são
-- POPULADAS COM DADOS SINTÉTICOS, mantendo a semântica de negócio:
--   * tipo_usuario CLIENTE  -> dw.dim_cliente
--   * tipo_usuario PRESTADOR -> dw.dim_prestador (associado a um plano)
-- =====================================================================

CREATE TABLE dw.dim_cliente (
    sk_cliente      serial PRIMARY KEY,
    codigo_cliente  integer NOT NULL UNIQUE,
    nome            varchar(150) NOT NULL,
    tipo_pessoa     varchar(2) NOT NULL CHECK (tipo_pessoa IN ('PF', 'PJ')),
    documento       varchar(20) NOT NULL,
    sk_cidade       integer NOT NULL REFERENCES dw.dim_cidade(sk_cidade),
    data_cadastro   date NOT NULL,
    ativo           boolean NOT NULL DEFAULT true
);
COMMENT ON TABLE dw.dim_cliente IS 'Dimensão de clientes (usuários que solicitam serviços) - dados sintéticos';

CREATE TABLE dw.dim_prestador (
    sk_prestador    serial PRIMARY KEY,
    codigo_prestador integer NOT NULL UNIQUE,
    nome            varchar(150) NOT NULL,
    tipo_pessoa     varchar(2) NOT NULL CHECK (tipo_pessoa IN ('PF', 'PJ')),
    documento       varchar(20) NOT NULL,
    sk_cidade       integer NOT NULL REFERENCES dw.dim_cidade(sk_cidade),
    sk_plano        integer NOT NULL REFERENCES dw.dim_plano(sk_plano),
    avaliacao_media numeric(3,2),
    qtd_avaliacoes  integer NOT NULL DEFAULT 0,
    data_cadastro   date NOT NULL,
    ativo           boolean NOT NULL DEFAULT true
);
COMMENT ON TABLE dw.dim_prestador IS 'Dimensão de prestadores de serviço - dados sintéticos';

-- ---------------------------------------------------------------------
-- Geração sintética
-- ---------------------------------------------------------------------
DO $$
DECLARE
    v_nomes            varchar[] := ARRAY['Ana','João','Maria','Pedro','Carla','Lucas','Fernanda','Rafael','Juliana','Bruno',
                                           'Camila','Diego','Larissa','Marcos','Patrícia','Rodrigo','Aline','Thiago','Vanessa','Gustavo',
                                           'Beatriz','Eduardo','Renata','Felipe','Priscila','André','Débora','Vinícius','Tatiane','Leonardo',
                                           'Cristina','Rogério','Simone','Márcio','Fabiana','Alex','Michele','Douglas','Sandra','Wesley'];
    v_sobrenomes        varchar[] := ARRAY['Silva','Souza','Oliveira','Santos','Pereira','Costa','Rodrigues','Almeida','Nascimento','Lima',
                                            'Araújo','Ribeiro','Carvalho','Gomes','Martins','Rocha','Barbosa','Freitas','Cardoso','Teixeira',
                                            'Moreira','Correia','Dias','Castro','Campos','Cavalcanti','Vieira','Duarte','Machado','Farias'];
    v_empresas          varchar[] := ARRAY['Serviços Express','Soluções Rápidas','Casa & Cia','Mão na Massa','Ponto Certo','Reparos Já',
                                            'Multi Serviços','Confiança Total','Obra Fácil','Bom Atendimento'];
    v_cidades_sk        integer[];
    v_planos_sk         integer[];
    i                   integer;
    v_nome              varchar;
    v_tipo_pessoa       varchar;
    v_qtd_cidades       integer;
    v_qtd_planos        integer;
BEGIN
    SELECT array_agg(sk_cidade) INTO v_cidades_sk FROM dw.dim_cidade;
    SELECT array_agg(sk_plano)  INTO v_planos_sk  FROM dw.dim_plano;
    v_qtd_cidades := array_length(v_cidades_sk, 1);
    v_qtd_planos  := array_length(v_planos_sk, 1);

    PERFORM setseed(0.42);

    -- Clientes (300) : ~90% pessoa física, 10% pessoa jurídica
    FOR i IN 1..300 LOOP
        IF random() < 0.9 THEN
            v_tipo_pessoa := 'PF';
            v_nome := v_nomes[1 + floor(random() * array_length(v_nomes, 1))::int]
                      || ' ' || v_sobrenomes[1 + floor(random() * array_length(v_sobrenomes, 1))::int];
        ELSE
            v_tipo_pessoa := 'PJ';
            v_nome := v_empresas[1 + floor(random() * array_length(v_empresas, 1))::int] || ' ' || i;
        END IF;

        INSERT INTO dw.dim_cliente (codigo_cliente, nome, tipo_pessoa, documento, sk_cidade, data_cadastro, ativo)
        VALUES (
            i,
            v_nome,
            v_tipo_pessoa,
            CASE WHEN v_tipo_pessoa = 'PF'
                 THEN lpad((random()*99999999999)::bigint::text, 11, '0')
                 ELSE lpad((random()*99999999999999)::bigint::text, 14, '0') END,
            v_cidades_sk[1 + floor(random() * v_qtd_cidades)::int],
            (date '2022-01-01' + (random() * 1400)::int),
            random() < 0.95
        );
    END LOOP;

    -- Prestadores (120) : ~75% pessoa física, 25% pessoa jurídica (MEI/empresas)
    FOR i IN 1..120 LOOP
        IF random() < 0.75 THEN
            v_tipo_pessoa := 'PF';
            v_nome := v_nomes[1 + floor(random() * array_length(v_nomes, 1))::int]
                      || ' ' || v_sobrenomes[1 + floor(random() * array_length(v_sobrenomes, 1))::int];
        ELSE
            v_tipo_pessoa := 'PJ';
            v_nome := v_empresas[1 + floor(random() * array_length(v_empresas, 1))::int] || ' ' || i;
        END IF;

        INSERT INTO dw.dim_prestador (codigo_prestador, nome, tipo_pessoa, documento, sk_cidade, sk_plano, avaliacao_media, qtd_avaliacoes, data_cadastro, ativo)
        VALUES (
            i,
            v_nome,
            v_tipo_pessoa,
            CASE WHEN v_tipo_pessoa = 'PF'
                 THEN lpad((random()*99999999999)::bigint::text, 11, '0')
                 ELSE lpad((random()*99999999999999)::bigint::text, 14, '0') END,
            v_cidades_sk[1 + floor(random() * v_qtd_cidades)::int],
            -- distribuição de planos: 50% básico, 35% profissional, 15% premium
            (CASE WHEN random() < 0.50 THEN v_planos_sk[1] WHEN random() < 0.85 THEN v_planos_sk[2] ELSE v_planos_sk[3] END),
            NULL, -- calculada posteriormente a partir de dm_avaliacoes.fato_avaliacao
            0,
            (date '2022-01-01' + (random() * 1200)::int),
            random() < 0.92
        );
    END LOOP;
END $$;
