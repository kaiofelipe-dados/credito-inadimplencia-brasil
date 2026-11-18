-- =============================================================================
-- 02 · Consultas de análise
-- Projeto: Carteira de crédito e inadimplência no Sistema Financeiro Nacional
--
-- Inadimplência = carteira_inadimplencia / carteira_ativa (definição do BCB:
-- saldo das operações com parcela em atraso acima de 90 dias sobre a carteira).
-- Os percentuais são sempre razões entre somas, nunca médias de percentuais.
-- =============================================================================


-- 1. Evolução mensal do Brasil: carteira e inadimplência
SELECT
  data_base,
  ROUND(SUM(carteira_ativa) / 1e12, 2)                                AS carteira_ativa_tri,
  ROUND(SAFE_DIVIDE(SUM(carteira_inadimplencia), SUM(carteira_ativa)) * 100, 2) AS inadimplencia_pct
FROM scr_credito.fato_credito
GROUP BY data_base
ORDER BY data_base;


-- 2. Ranking das UFs no último mês, com a variação em 12 meses
WITH datas AS (
  SELECT MAX(data_base) AS atual,
         LAST_DAY(DATE_SUB(MAX(data_base), INTERVAL 12 MONTH)) AS ano_anterior
  FROM scr_credito.fato_credito
),
por_uf AS (
  SELECT
    u.uf,
    u.regiao,
    SUM(IF(f.data_base = d.atual, f.carteira_ativa, 0))               AS carteira_atual,
    SUM(IF(f.data_base = d.atual, f.carteira_inadimplencia, 0))       AS inad_atual,
    SUM(IF(f.data_base = d.ano_anterior, f.carteira_ativa, 0))        AS carteira_anterior,
    SUM(IF(f.data_base = d.ano_anterior, f.carteira_inadimplencia, 0)) AS inad_anterior
  FROM scr_credito.fato_credito AS f
  CROSS JOIN datas AS d
  JOIN scr_credito.dim_uf AS u USING (id_uf)
  WHERE f.data_base IN (d.atual, d.ano_anterior)
  GROUP BY u.uf, u.regiao
)
SELECT
  RANK() OVER (ORDER BY SAFE_DIVIDE(inad_atual, carteira_atual) DESC) AS posicao,
  uf,
  regiao,
  ROUND(carteira_atual / 1e9, 1) AS carteira_bi,
  ROUND(SAFE_DIVIDE(inad_atual, carteira_atual) * 100, 2) AS inadimplencia_pct,
  ROUND((SAFE_DIVIDE(inad_atual, carteira_atual) - SAFE_DIVIDE(inad_anterior, carteira_anterior)) * 100, 2) AS variacao_12m_pp
FROM por_uf
ORDER BY posicao;


-- 3. Norte, Pará e Brasil mês a mês
SELECT
  f.data_base,
  ROUND(SAFE_DIVIDE(SUM(f.carteira_inadimplencia), SUM(f.carteira_ativa)) * 100, 2) AS brasil_pct,
  ROUND(SAFE_DIVIDE(SUM(IF(u.regiao = 'Norte', f.carteira_inadimplencia, 0)),
                    SUM(IF(u.regiao = 'Norte', f.carteira_ativa, 0))) * 100, 2)      AS norte_pct,
  ROUND(SAFE_DIVIDE(SUM(IF(u.uf = 'PA', f.carteira_inadimplencia, 0)),
                    SUM(IF(u.uf = 'PA', f.carteira_ativa, 0))) * 100, 2)             AS para_pct
FROM scr_credito.fato_credito AS f
JOIN scr_credito.dim_uf AS u USING (id_uf)
GROUP BY f.data_base
ORDER BY f.data_base;


-- 4. Modalidades no último mês: peso na carteira e inadimplência
SELECT
  m.modalidade,
  ROUND(SUM(f.carteira_ativa) / 1e9, 1) AS carteira_bi,
  ROUND(SUM(f.carteira_ativa) / SUM(SUM(f.carteira_ativa)) OVER () * 100, 1) AS participacao_pct,
  ROUND(SAFE_DIVIDE(SUM(f.carteira_inadimplencia), SUM(f.carteira_ativa)) * 100, 2) AS inadimplencia_pct
FROM scr_credito.fato_credito AS f
JOIN scr_credito.dim_modalidade AS m USING (id_modalidade)
WHERE f.data_base = (SELECT MAX(data_base) FROM scr_credito.fato_credito)
GROUP BY m.modalidade
ORDER BY carteira_bi DESC;


-- 5. Pessoa física x pessoa jurídica, mês a mês
SELECT
  f.data_base,
  c.cliente,
  ROUND(SUM(f.carteira_ativa) / 1e12, 2) AS carteira_tri,
  ROUND(SAFE_DIVIDE(SUM(f.carteira_inadimplencia), SUM(f.carteira_ativa)) * 100, 2) AS inadimplencia_pct
FROM scr_credito.fato_credito AS f
JOIN scr_credito.dim_cliente AS c USING (id_cliente)
GROUP BY f.data_base, c.cliente
ORDER BY f.data_base, c.cliente;


-- 6. Segmentos de instituição no último mês (cooperativas, bancos, fintechs...)
SELECT
  g.segmento,
  ROUND(SUM(f.carteira_ativa) / 1e9, 1) AS carteira_bi,
  ROUND(SUM(f.carteira_ativa) / SUM(SUM(f.carteira_ativa)) OVER () * 100, 1) AS participacao_pct,
  ROUND(SAFE_DIVIDE(SUM(f.carteira_inadimplencia), SUM(f.carteira_ativa)) * 100, 2) AS inadimplencia_pct
FROM scr_credito.fato_credito AS f
JOIN scr_credito.dim_segmento AS g USING (id_segmento)
WHERE f.data_base = (SELECT MAX(data_base) FROM scr_credito.fato_credito)
GROUP BY g.segmento
ORDER BY carteira_bi DESC;


-- 7. Onde a inadimplência mais subiu: modalidade × cliente em 12 meses
WITH datas AS (
  SELECT MAX(data_base) AS atual,
         LAST_DAY(DATE_SUB(MAX(data_base), INTERVAL 12 MONTH)) AS ano_anterior
  FROM scr_credito.fato_credito
),
base AS (
  SELECT
    m.modalidade,
    c.cliente,
    SUM(IF(f.data_base = d.atual, f.carteira_ativa, 0))               AS carteira_atual,
    SUM(IF(f.data_base = d.atual, f.carteira_inadimplencia, 0))       AS inad_atual,
    SUM(IF(f.data_base = d.ano_anterior, f.carteira_ativa, 0))        AS carteira_anterior,
    SUM(IF(f.data_base = d.ano_anterior, f.carteira_inadimplencia, 0)) AS inad_anterior
  FROM scr_credito.fato_credito AS f
  CROSS JOIN datas AS d
  JOIN scr_credito.dim_modalidade AS m USING (id_modalidade)
  JOIN scr_credito.dim_cliente AS c USING (id_cliente)
  WHERE f.data_base IN (d.atual, d.ano_anterior)
  GROUP BY m.modalidade, c.cliente
)
SELECT
  modalidade,
  cliente,
  ROUND(carteira_atual / 1e9, 1) AS carteira_bi,
  ROUND(SAFE_DIVIDE(inad_atual, carteira_atual) * 100, 2) AS inadimplencia_pct,
  ROUND((SAFE_DIVIDE(inad_atual, carteira_atual) - SAFE_DIVIDE(inad_anterior, carteira_anterior)) * 100, 2) AS variacao_12m_pp,
  ROUND((inad_atual - inad_anterior) / 1e9, 1) AS aumento_inadimplente_bi
FROM base
WHERE carteira_atual > 0
ORDER BY aumento_inadimplente_bi DESC
LIMIT 15;
