-- =============================================================================
-- 01 · Modelo estrela
-- Projeto: Carteira de crédito e inadimplência no Sistema Financeiro Nacional
-- Fonte:   scr_credito.stg_credito (carga de data/processed/credito.parquet)
--
-- Cria quatro dimensões com chaves numéricas e a tabela fato no grão
-- mês × UF × segmento × cliente/porte × modalidade × origem.
-- O calendário é criado no Power BI.
-- =============================================================================


-- Dimensão UF, com a região de cada estado
CREATE OR REPLACE TABLE scr_credito.dim_uf AS
SELECT
  DENSE_RANK() OVER (ORDER BY uf) AS id_uf,
  uf,
  CASE
    WHEN uf IN ('AC', 'AM', 'AP', 'PA', 'RO', 'RR', 'TO') THEN 'Norte'
    WHEN uf IN ('AL', 'BA', 'CE', 'MA', 'PB', 'PE', 'PI', 'RN', 'SE') THEN 'Nordeste'
    WHEN uf IN ('DF', 'GO', 'MS', 'MT') THEN 'Centro-Oeste'
    WHEN uf IN ('ES', 'MG', 'RJ', 'SP') THEN 'Sudeste'
    WHEN uf IN ('PR', 'RS', 'SC') THEN 'Sul'
  END AS regiao
FROM (SELECT DISTINCT uf FROM scr_credito.stg_credito);


-- Dimensão segmento da instituição financeira
CREATE OR REPLACE TABLE scr_credito.dim_segmento AS
SELECT
  DENSE_RANK() OVER (ORDER BY segmento) AS id_segmento,
  segmento
FROM (SELECT DISTINCT segmento FROM scr_credito.stg_credito);


-- Dimensão cliente: tipo (PF/PJ) e porte juntos, porque o porte
-- é faixa de renda para PF e porte da empresa para PJ
CREATE OR REPLACE TABLE scr_credito.dim_cliente AS
SELECT
  DENSE_RANK() OVER (ORDER BY cliente, porte) AS id_cliente,
  cliente,
  porte
FROM (SELECT DISTINCT cliente, porte FROM scr_credito.stg_credito);


-- Dimensão modalidade de crédito, com a origem dos recursos
CREATE OR REPLACE TABLE scr_credito.dim_modalidade AS
SELECT
  DENSE_RANK() OVER (ORDER BY modalidade, origem) AS id_modalidade,
  modalidade,
  origem
FROM (SELECT DISTINCT modalidade, origem FROM scr_credito.stg_credito);


-- Tabela fato: saldos mensais com as chaves das dimensões
CREATE OR REPLACE TABLE scr_credito.fato_credito AS
SELECT
  DATE(s.data_base)            AS data_base,
  u.id_uf,
  g.id_segmento,
  c.id_cliente,
  m.id_modalidade,
  s.carteira_ativa,
  s.carteira_a_vencer,
  s.vencido_de_15_ate_90_dias,
  s.vencido_acima_de_90_dias,
  s.carteira_vencida,
  s.carteira_inadimplencia,
  s.ativo_problematico
FROM scr_credito.stg_credito AS s
JOIN scr_credito.dim_uf         AS u ON s.uf = u.uf
JOIN scr_credito.dim_segmento   AS g ON s.segmento = g.segmento
JOIN scr_credito.dim_cliente    AS c ON s.cliente = c.cliente AND s.porte = c.porte
JOIN scr_credito.dim_modalidade AS m ON s.modalidade = m.modalidade AND s.origem = m.origem;


-- Conferência: a fato deve ter o mesmo número de linhas e os mesmos
-- totais da tabela de origem (nenhuma linha perdida nos JOINs)
SELECT 'stg_credito' AS tabela, COUNT(*) AS linhas, ROUND(SUM(carteira_ativa) / 1e12, 4) AS carteira_ativa_tri
FROM scr_credito.stg_credito
UNION ALL
SELECT 'fato_credito', COUNT(*), ROUND(SUM(carteira_ativa) / 1e12, 4)
FROM scr_credito.fato_credito;
