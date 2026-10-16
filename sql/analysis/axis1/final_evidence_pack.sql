-- Objectif :
-- Produire une sortie compacte et vérifiable pour les principaux constats
-- candidats de l'axe 1 avant rédaction des findings finaux.

-- Logique :
-- Restreindre l'analyse aux années complètes 2023–2025 afin d'éviter
-- les effets des années partielles 2021 et 2026.
--
-- Calculer les baselines du funnel sur cette période, puis extraire
-- uniquement les couples catégorie × étape déjà identifiés comme
-- analytiquement intéressants :
--   - DemarchageAbusif / transmission
--   - Internet / consultation
--   - TravauxRenovations / consultation et réponse
--   - CafeRestaurant / consultation et réponse
--   - AchatMagasin / transmission comme benchmark positif

-- Résultat attendu :
-- 7 lignes maximum.
-- Pour chaque catégorie × étape :
--   - dénominateur ;
--   - nombre de cas perdus ;
--   - taux observé ;
--   - baseline 2023–2025 ;
--   - écart en points ;
--   - pertes en excès vs baseline lorsque la catégorie sous-performe.

-- Lecture :
-- Cette sortie ne sert plus à découvrir de nouveaux patterns.
-- Elle sert à vérifier rapidement l'ampleur des constats déjà sélectionnés
-- et à disposer d'une preuve compacte pour la synthèse J6.

-- Vigilance / Hypothèses :
-- `excess_loss_vs_baseline` est descriptif et non causal.
-- Une valeur négative signifie que la catégorie performe mieux que la
-- baseline ; elle n'est pas interprétée comme une "perte négative".
-- Le choix 2023–2025 est analytique : trois années complètes et récentes.

WITH filtered AS (
  SELECT *
  FROM `signalconso.signalconso_v1.mart_axis1_category_month`
  WHERE
    is_consolidated_month = TRUE
    AND EXTRACT(YEAR FROM month) BETWEEN 2023 AND 2025
),

baseline AS (
  SELECT
    SAFE_DIVIDE(
      SUM(nb_transmis),
      SUM(nb_population_standard)
    ) AS transmission_rate,

    SAFE_DIVIDE(
      SUM(nb_consultes),
      SUM(nb_transmis)
    ) AS consultation_rate,

    SAFE_DIVIDE(
      SUM(nb_reponses),
      SUM(nb_consultes)
    ) AS response_rate
  FROM filtered
),

category_summary AS (
  SELECT
    category,
    SUM(nb_population_standard) AS nb_population_standard,
    SUM(nb_transmis) AS nb_transmis,
    SUM(nb_consultes) AS nb_consultes,
    SUM(nb_reponses) AS nb_reponses
  FROM filtered
  GROUP BY category
),

evidence AS (
  -- DemarchageAbusif — transmission
  SELECT
    category,
    'transmission' AS funnel_step,
    nb_population_standard AS denominator,
    nb_population_standard - nb_transmis AS nb_lost,
    SAFE_DIVIDE(nb_transmis, nb_population_standard) AS rate,
    b.transmission_rate AS baseline_rate
  FROM category_summary
  CROSS JOIN baseline AS b
  WHERE category = 'DemarchageAbusif'

  UNION ALL

  -- Internet — consultation
  SELECT
    category,
    'consultation',
    nb_transmis,
    nb_transmis - nb_consultes,
    SAFE_DIVIDE(nb_consultes, nb_transmis),
    b.consultation_rate
  FROM category_summary
  CROSS JOIN baseline AS b
  WHERE category = 'Internet'

  UNION ALL

  -- TravauxRenovations — consultation
  SELECT
    category,
    'consultation',
    nb_transmis,
    nb_transmis - nb_consultes,
    SAFE_DIVIDE(nb_consultes, nb_transmis),
    b.consultation_rate
  FROM category_summary
  CROSS JOIN baseline AS b
  WHERE category = 'TravauxRenovations'

  UNION ALL

  -- TravauxRenovations — réponse
  SELECT
    category,
    'response',
    nb_consultes,
    nb_consultes - nb_reponses,
    SAFE_DIVIDE(nb_reponses, nb_consultes),
    b.response_rate
  FROM category_summary
  CROSS JOIN baseline AS b
  WHERE category = 'TravauxRenovations'

  UNION ALL

  -- CafeRestaurant — consultation
  SELECT
    category,
    'consultation',
    nb_transmis,
    nb_transmis - nb_consultes,
    SAFE_DIVIDE(nb_consultes, nb_transmis),
    b.consultation_rate
  FROM category_summary
  CROSS JOIN baseline AS b
  WHERE category = 'CafeRestaurant'

  UNION ALL

  -- CafeRestaurant — réponse
  SELECT
    category,
    'response',
    nb_consultes,
    nb_consultes - nb_reponses,
    SAFE_DIVIDE(nb_reponses, nb_consultes),
    b.response_rate
  FROM category_summary
  CROSS JOIN baseline AS b
  WHERE category = 'CafeRestaurant'

  UNION ALL

  -- AchatMagasin — benchmark positif
  SELECT
    category,
    'transmission',
    nb_population_standard,
    nb_population_standard - nb_transmis,
    SAFE_DIVIDE(nb_transmis, nb_population_standard),
    b.transmission_rate
  FROM category_summary
  CROSS JOIN baseline AS b
  WHERE category = 'AchatMagasin'
)

SELECT
  category,
  funnel_step,
  denominator,
  nb_lost,

  rate,
  baseline_rate,

  100 * (rate - baseline_rate)
    AS gap_vs_baseline_pp,

  CASE
    WHEN rate < baseline_rate
    THEN denominator * (baseline_rate - rate)
    ELSE 0
  END AS excess_loss_vs_baseline

FROM evidence

ORDER BY
  funnel_step,
  gap_vs_baseline_pp;