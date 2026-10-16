-- Objectif :
-- Identifier les catégories qui contribuent le plus à l'anomalie MalAttribue
-- observée en Nouvelle-Aquitaine.

-- Logique :
-- Sur les années complètes 2023–2025 et parmi les signalements avec réponse :
--   1. calculer, pour chaque année × catégorie, le taux de MalAttribue hors Nouvelle-Aquitaine ;
--   2. appliquer ce taux de référence aux volumes observés en Nouvelle-Aquitaine ;
--   3. agréger les résultats par catégorie ;
--   4. comparer MalAttribue observés et attendus après contrôle du mix temporel ;
--   5. mesurer la contribution de chaque catégorie à l'excès positif régional.
--
-- Les calculs sont effectués en pleine précision.
-- Les pourcentages et arrondis sont appliqués uniquement dans le SELECT final.

-- Résultat attendu :
-- 1 ligne par catégorie présente en Nouvelle-Aquitaine.
--   - category : catégorie métier du signalement.
--   - na_nb_reponses : nombre de réponses observées en Nouvelle-Aquitaine.
--   - na_nb_mal_attribue : nombre de MalAttribue observés en Nouvelle-Aquitaine.
--   - na_malattribue_rate_pct : taux brut de MalAttribue observé en Nouvelle-Aquitaine.
--   - expected_rate_adjusted_pct : taux attendu après application des taux hors Nouvelle-Aquitaine par année × catégorie.
--   - adjusted_gap_pp : écart entre taux observé et taux attendu ajusté, en points de pourcentage.
--   - relative_risk_adjusted : ratio entre taux observé et taux attendu ajusté ; 2 = taux deux fois supérieur.
--   - expected_mal_attribue_adjusted : nombre attendu de MalAttribue après contrôle année × catégorie.
--   - excess_mal_attribue_adjusted : différence entre MalAttribue observés et attendus ; mesure descriptive.
--   - share_of_na_mal_attribue_pct : part de tous les MalAttribue de Nouvelle-Aquitaine provenant de cette catégorie.
--   - share_of_positive_excess_pct : part de l'excès positif régional attribuable à cette catégorie.
--   - volume_status : indicateur de fiabilité selon le volume de réponses en Nouvelle-Aquitaine.

-- Lecture :
-- A. Anomalie locale :
--   - adjusted_gap_pp ;
--   - relative_risk_adjusted.
--
-- B. Contribution à l'anomalie régionale :
--   - excess_mal_attribue_adjusted ;
--   - share_of_positive_excess_pct.
--
-- C. Poids brut en Nouvelle-Aquitaine :
--   - na_nb_mal_attribue ;
--   - share_of_na_mal_attribue_pct.
--
-- Chercher surtout les catégories qui combinent un écart ajusté substantiel
-- avec un excès absolu important.

-- Vigilance / Hypothèses :
-- La comparaison contrôle l'année et la catégorie, mais pas les différences
-- de questionnaire_path ou d'autres caractéristiques internes aux catégories.
-- L'excès est descriptif et ne représente pas un nombre de cas évitables.
-- Une catégorie peut contribuer fortement à l'excès par son volume même si
-- son écart de taux est modéré.

WITH eligible AS (
  SELECT
    EXTRACT(YEAR FROM report_month) AS year,
    category,
    region_code,
    status
  FROM `signalconso.signalconso_v1.stg_signalements`
  WHERE
    is_standard_population
    AND has_response
    AND region_code IS NOT NULL
    AND EXTRACT(YEAR FROM report_month) BETWEEN 2023 AND 2025
),

strata AS (
  SELECT
    year,
    category,

    COUNTIF(region_code = '75') AS na_nb_reponses,

    COUNTIF(
      region_code = '75'
      AND status = 'MalAttribue'
    ) AS na_nb_mal_attribue,

    COUNTIF(region_code != '75') AS reference_nb_reponses,

    COUNTIF(
      region_code != '75'
      AND status = 'MalAttribue'
    ) AS reference_nb_mal_attribue

  FROM eligible

  GROUP BY
    year,
    category
),

strata_metrics AS (
  SELECT
    year,
    category,
    na_nb_reponses,
    na_nb_mal_attribue,

    SAFE_DIVIDE(
      reference_nb_mal_attribue,
      reference_nb_reponses
    ) AS reference_rate,

    na_nb_reponses * SAFE_DIVIDE(
      reference_nb_mal_attribue,
      reference_nb_reponses
    ) AS expected_mal_attribue

  FROM strata

  WHERE
    na_nb_reponses > 0
    AND reference_nb_reponses >= 100
),

category_summary AS (
  SELECT
    category,

    SUM(na_nb_reponses) AS na_nb_reponses,
    SUM(na_nb_mal_attribue) AS na_nb_mal_attribue,
    SUM(expected_mal_attribue) AS expected_mal_attribue_adjusted

  FROM strata_metrics

  GROUP BY category
),

category_metrics AS (
  SELECT
    category,
    na_nb_reponses,
    na_nb_mal_attribue,
    expected_mal_attribue_adjusted,

    SAFE_DIVIDE(
      na_nb_mal_attribue,
      na_nb_reponses
    ) AS na_malattribue_rate,

    SAFE_DIVIDE(
      expected_mal_attribue_adjusted,
      na_nb_reponses
    ) AS expected_rate_adjusted,

    na_nb_mal_attribue
      - expected_mal_attribue_adjusted
      AS excess_mal_attribue_adjusted

  FROM category_summary
),

totals AS (
  SELECT
    SUM(na_nb_mal_attribue) AS total_na_mal_attribue,

    SUM(
      GREATEST(
        excess_mal_attribue_adjusted,
        0
      )
    ) AS total_positive_excess

  FROM category_metrics
)

SELECT
  m.category,

  m.na_nb_reponses,
  m.na_nb_mal_attribue,

  ROUND(
    100 * m.na_malattribue_rate,
    2
  ) AS na_malattribue_rate_pct,

  ROUND(
    100 * m.expected_rate_adjusted,
    2
  ) AS expected_rate_adjusted_pct,

  ROUND(
    100 * (
      m.na_malattribue_rate
      - m.expected_rate_adjusted
    ),
    2
  ) AS adjusted_gap_pp,

  ROUND(
    SAFE_DIVIDE(
      m.na_malattribue_rate,
      m.expected_rate_adjusted
    ),
    2
  ) AS relative_risk_adjusted,

  ROUND(
    m.expected_mal_attribue_adjusted,
    1
  ) AS expected_mal_attribue_adjusted,

  ROUND(
    m.excess_mal_attribue_adjusted,
    1
  ) AS excess_mal_attribue_adjusted,

  ROUND(
    100 * SAFE_DIVIDE(
      m.na_nb_mal_attribue,
      t.total_na_mal_attribue
    ),
    2
  ) AS share_of_na_mal_attribue_pct,

  ROUND(
    100 * SAFE_DIVIDE(
      GREATEST(
        m.excess_mal_attribue_adjusted,
        0
      ),
      t.total_positive_excess
    ),
    2
  ) AS share_of_positive_excess_pct,

  CASE
    WHEN m.na_nb_reponses < 30 THEN 'insufficient'
    WHEN m.na_nb_reponses < 100 THEN 'low_volume'
    ELSE 'standard'
  END AS volume_status

FROM category_metrics AS m
CROSS JOIN totals AS t

ORDER BY
  excess_mal_attribue_adjusted DESC;