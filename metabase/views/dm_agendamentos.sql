-- =====================================================================
-- Prestador Nota 10 - Metabase
-- dm_agendamentos.sql
--
-- Views usadas pelo Metabase para visualizar o datamart dm_agendamentos.
-- =====================================================================

CREATE OR REPLACE VIEW dm_agendamentos.vw_resumo_agendamento_mes AS
SELECT *
FROM dm_agendamentos.resumo_agendamento_mes
ORDER BY ano, mes;
COMMENT ON VIEW dm_agendamentos.vw_resumo_agendamento_mes IS 'Agendamentos por mês: volume, duração média e taxa de reagendamento';

CREATE OR REPLACE VIEW dm_agendamentos.vw_resumo_agendamento_prestador AS
SELECT *
FROM dm_agendamentos.resumo_agendamento_prestador
ORDER BY qtd_agendamentos DESC;
COMMENT ON VIEW dm_agendamentos.vw_resumo_agendamento_prestador IS 'Agendamentos por prestador: volume, duração média e taxa de reagendamento';
