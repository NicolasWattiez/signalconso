-- Objectif :
-- Identifier, dans les catégories prioritaires, les questionnaire_path qui
-- concentrent ou surreprésentent le plus MalAttribue.

-- Logique :
-- Sur les années complètes 2023–2025 et parmi les signalements avec réponse :
--   1. calculer le taux de MalAttribue propre à chaque catégorie ;
--   2. agréger les réponses et MalAttribue par catégorie × questionnaire_path ;
--   3. comparer chaque path à la baseline de sa propre catégorie ;
--   4. mesurer séparément surreprésentation, concentration excédentaire et poids brut.
--
-- Les calculs sont effectués en pleine précision.
-- Les pourcentages et arrondis sont appliqués uniquement dans le SELECT final.
--
-- Seuls les paths avec au moins 100 réponses sont conservés afin d'éviter
-- d'interpréter des taux extrêmes issus de très faibles volumes.

-- Résultat attendu :
-- 1 ligne par catégorie × questionnaire_path avec au moins 100 réponses.
--   - category : catégorie métier du signalement.
--   - questionnaire_path : parcours de questionnaire observé dans la catégorie.
--   - nb_reponses : nombre de réponses associées à ce path.
--   - nb_mal_attribue : nombre de MalAttribue associés à ce path.
--   - malattribue_rate_pct : pourcentage des réponses du path terminées en MalAttribue.
--   - category_rate_pct : taux global de MalAttribue de la catégorie, utilisé comme baseline locale.
--   - gap_vs_category_pp : écart entre le taux du path et celui de sa catégorie, en points de pourcentage.
--   - relative_risk_vs_category : ratio entre le taux du path et celui de sa catégorie ; 2 = taux deux fois supérieur.
--   - share_of_category_responses_pct : part des réponses de la catégorie représentée par ce path.
--   - share_of_category_mal_attribue_pct : part des MalAttribue de la catégorie provenant de ce path.
--   - expected_mal_attribue_at_category_rate : nombre attendu de MalAttribue si le path avait le taux moyen de sa catégorie.
--   - excess_mal_attribue_vs_category : différence entre nombre observé et attendu ; mesure descriptive, pas cas évitables.
--   - excess_rank_in_category : rang du path dans sa catégorie selon son excès descriptif de MalAttribue.

-- Lecture :
-- A. Surreprésentation locale :
--   - gap_vs_category_pp ;
--   - relative_risk_vs_category.
--
-- B. Concentration excédentaire locale :
--   - excess_mal_attribue_vs_category ;
--   - excess_rank_in_category.
--
-- C. Poids brut dans la catégorie :
--   - nb_mal_attribue ;
--   - share_of_category_mal_attribue_pct.
--
-- Chercher surtout les paths qui combinent un écart substantiel avec un
-- volume suffisant. Un path peut être important par son taux, son volume,
-- ou les deux.

-- Vigilance / Hypothèses :
-- questionnaire_path participe probablement au mécanisme de qualification /
-- routage SignalConso : association != effet causal indépendant.
-- La taxonomie a évolué dans le temps et contient certaines variantes de libellé.
-- Les paths sont comparés à leur propre catégorie afin de mesurer l'information
-- supplémentaire apportée au-delà de category.

WITH eligible AS (
  SELECT
    category,
    questionnaire_path,
    status
  FROM `signalconso.signalconso_v1.stg_signalements`
  WHERE
    is_standard_population
    AND has_response
    AND questionnaire_path IS NOT NULL
    AND EXTRACT(YEAR FROM report_month) BETWEEN 2023 AND 2025
    AND category IN (
      'DemarchageAbusif',
      'AchatInternet',
      'Internet',
      'VoyageLoisirs',
      'TravauxRenovations'
    )
),

category_baseline AS (
  SELECT
    category,
    COUNT(*) AS category_nb_reponses,
    COUNTIF(status = 'MalAttribue') AS category_nb_mal_attribue,
    SAFE_DIVIDE(
      COUNTIF(status = 'MalAttribue'),
      COUNT(*)
    ) AS category_rate
  FROM eligible
  GROUP BY category
),

path_summary AS (
  SELECT
    category,
    questionnaire_path,
    COUNT(*) AS nb_reponses,
    COUNTIF(status = 'MalAttribue') AS nb_mal_attribue
  FROM eligible
  GROUP BY
    category,
    questionnaire_path
  HAVING COUNT(*) >= 100
),

path_metrics AS (
  SELECT
    p.category,
    p.questionnaire_path,
    p.nb_reponses,
    p.nb_mal_attribue,

    SAFE_DIVIDE(
      p.nb_mal_attribue,
      p.nb_reponses
    ) AS malattribue_rate,

    c.category_rate,

    SAFE_DIVIDE(
      SAFE_DIVIDE(
        p.nb_mal_attribue,
        p.nb_reponses
      ),
      c.category_rate
    ) AS relative_risk_vs_category,

    SAFE_DIVIDE(
      p.nb_reponses,
      c.category_nb_reponses
    ) AS share_of_category_responses,

    SAFE_DIVIDE(
      p.nb_mal_attribue,
      c.category_nb_mal_attribue
    ) AS share_of_category_mal_attribue,

    p.nb_reponses * c.category_rate
      AS expected_mal_attribue_at_category_rate

  FROM path_summary AS p
  JOIN category_baseline AS c
    USING (category)
),

ranked AS (
  SELECT
    *,
    nb_mal_attribue - expected_mal_attribue_at_category_rate
      AS excess_mal_attribue_vs_category,

    RANK() OVER (
      PARTITION BY category
      ORDER BY
        nb_mal_attribue - expected_mal_attribue_at_category_rate DESC
    ) AS excess_rank_in_category

  FROM path_metrics
)

SELECT
  category,
  questionnaire_path,
  nb_reponses,
  nb_mal_attribue,

  ROUND(
    100 * malattribue_rate,
    2
  ) AS malattribue_rate_pct,

  ROUND(
    100 * category_rate,
    2
  ) AS category_rate_pct,

  ROUND(
    100 * (malattribue_rate - category_rate),
    2
  ) AS gap_vs_category_pp,

  ROUND(
    relative_risk_vs_category,
    2
  ) AS relative_risk_vs_category,

  ROUND(
    100 * share_of_category_responses,
    2
  ) AS share_of_category_responses_pct,

  ROUND(
    100 * share_of_category_mal_attribue,
    2
  ) AS share_of_category_mal_attribue_pct,

  ROUND(
    expected_mal_attribue_at_category_rate,
    1
  ) AS expected_mal_attribue_at_category_rate,

  ROUND(
    excess_mal_attribue_vs_category,
    1
  ) AS excess_mal_attribue_vs_category,

  excess_rank_in_category

FROM ranked

ORDER BY
  category,
  excess_mal_attribue_vs_category DESC;