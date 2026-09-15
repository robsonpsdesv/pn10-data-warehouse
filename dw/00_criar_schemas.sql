-- =====================================================================
-- Prestador Nota 10 - Data Warehouse
-- 00_criar_schemas.sql
--
-- Cria a estrutura de schemas do DW: um schema de dimensões conformadas
-- (compartilhadas entre os datamarts) e um schema por datamart/assunto.
-- Execução idempotente: os schemas são recriados do zero (DROP CASCADE).
-- =====================================================================

DROP SCHEMA IF EXISTS dm_planos CASCADE;
DROP SCHEMA IF EXISTS dm_prestadores CASCADE;
DROP SCHEMA IF EXISTS dm_agendamentos CASCADE;
DROP SCHEMA IF EXISTS dm_avaliacoes CASCADE;
DROP SCHEMA IF EXISTS dm_orcamentos CASCADE;
DROP SCHEMA IF EXISTS dm_pedidos CASCADE;
DROP SCHEMA IF EXISTS dw CASCADE;

CREATE SCHEMA dw;
CREATE SCHEMA dm_pedidos;
CREATE SCHEMA dm_orcamentos;
CREATE SCHEMA dm_avaliacoes;
CREATE SCHEMA dm_agendamentos;
CREATE SCHEMA dm_prestadores;
CREATE SCHEMA dm_planos;

COMMENT ON SCHEMA dw             IS 'Dimensões conformadas do DW Prestador Nota 10 (compartilhadas entre datamarts)';
COMMENT ON SCHEMA dm_pedidos     IS 'Datamart: ciclo de vida operacional dos pedidos de serviço';
COMMENT ON SCHEMA dm_orcamentos  IS 'Datamart: orçamentos/propostas comerciais enviados por prestadores';
COMMENT ON SCHEMA dm_avaliacoes  IS 'Datamart: satisfação do cliente e reputação dos prestadores';
COMMENT ON SCHEMA dm_agendamentos IS 'Datamart: agenda e execução do atendimento';
COMMENT ON SCHEMA dm_prestadores IS 'Datamart: perfil, cobertura e precificação dos prestadores';
COMMENT ON SCHEMA dm_planos      IS 'Datamart: assinaturas e planos comerciais dos prestadores';
