-- Objectif :
-- Mesurer l'anomalie globale AchatInternet en Nouvelle-Aquitaine après contrôle
-- simultané de l'année et du questionnaire_path.

-- Logique :
-- Sur AchatInternet, années complètes 2023–2025 et signalements avec réponse :
--   1. construire des strates année × questionnaire_path ;
--   2. calculer pour chaque strate le taux de MalAttribue hors Nouvelle-Aquitaine ;
--   3. appliquer ce taux aux volumes observés en Nouvelle-Aquitaine ;
--   4. sommer les MalAttribue observés et attendus sur toutes les strates comparables.
--
-- Contrairement à la requête 57, aucun seuil de 30 réponses n'est appliqué
-- aux paths côté Nouvelle-Aquitaine : ici l'objectif est d'estimer l'écart
-- global ajusté, pas de sélectionner des paths individuellement.
--
-- Les calculs sont effectués en pleine précision.
-- Les pourcentages et arrondis sont appliqués uniquement dans le SELECT final.

-- Résultat attendu :
-- 1 ligne de synthèse pour AchatInternet en Nouvelle-Aquitaine.
--   - total_na_reponses : nombre total de réponses AchatInternet en Nouvelle-Aquitaine sur 2023–2025.
--   - comparable_na_reponses : nombre de réponses couvertes par des strates année × path comparables.
--   - comparable_na_mal_attribue : nombre de MalAttribue observés dans ces strates comparables.
--   - coverage_of_na_responses_pct : part des réponses AchatInternet régionales couvertes par la comparaison ajustée.
--   - observed_rate_pct : taux de MalAttribue observé sur la population comparable.
--   - expected_adjusted_rate_pct : taux attendu selon les mêmes année × path hors Nouvelle-Aquitaine.
--   - adjusted_gap_pp : écart entre taux observé et taux attendu ajusté, en points de pourcentage.
--   - relative_risk_adjusted : ratio entre taux observé et attendu ; 2 = taux deux fois supérieur.
--   - expected_mal_attribue_adjusted : nombre de MalAttribue attendu après contrôle année × path.
--   - excess_mal_attribue_adjusted : différence entre MalAttribue observés et attendus ; mesure descriptive.
--   - questionnaire_paths_covered : nombre de questionnaire_path contribuant à la comparaison.
--   - comparable_strata : nombre de strates année × questionnaire_path effectivement utilisées.

-- Lecture :
-- Si l'écart reste important après contrôle année × questionnaire_path,
-- le niveau élevé de MalAttribue en Nouvelle-Aquitaine ne peut pas être expliqué
-- simplement par un mix différent de parcours ou de périodes.
--
-- Vérifier également coverage_of_na_responses_pct :
-- une forte couverture rend cette conclusion plus représentative de l'ensemble
-- de la catégorie AchatInternet en Nouvelle-Aquitaine.

-- Vigilance / Hypothèses :
-- Ce contrôle neutralise uniquement l'année et questionnaire_path.
-- Il ne démontre pas un effet causal propre à la région.
-- Les strates ayant moins de 100 réponses hors Nouvelle-Aquitaine sont exclues.

WITH base AS (
  SELECT
    EXTRACT(YEAR FROM report_month) AS year,
    questionnaire_path,
    region_code,
    status
  FROM `signalconso.signalconso_v1.stg_signalements`
  WHERE
    is_standard_population
    AND has_response
    AND category = 'AchatInternet'
    AND region_code IS NOT NULL
    AND EXTRACT(YEAR FROM report_month) BETWEEN 2023 AND 2025
),

na_total AS (
  SELECT
    COUNT(*) AS total_na_reponses
  FROM base
  WHERE region_code = '75'
),

strata AS (
  SELECT
    year,
    questionnaire_path,

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

  FROM base

  WHERE questionnaire_path IS NOT NULL

  GROUP BY
    year,
    questionnaire_path
),

comparable_strata AS (
  SELECT
    year,
    questionnaire_path,
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

summary AS (
  SELECT
    SUM(na_nb_reponses) AS comparable_na_reponses,
    SUM(na_nb_mal_attribue) AS comparable_na_mal_attribue,
    SUM(expected_mal_attribue) AS expected_mal_attribue_adjusted,
    COUNT(DISTINCT questionnaire_path) AS questionnaire_paths_covered,
    COUNT(*) AS comparable_strata
  FROM comparable_strata
)

SELECT
  t.total_na_reponses,

  s.comparable_na_reponses,
  s.comparable_na_mal_attribue,

  ROUND(
    100 * SAFE_DIVIDE(
      s.comparable_na_reponses,
      t.total_na_reponses
    ),
    2
  ) AS coverage_of_na_responses_pct,

  ROUND(
    100 * SAFE_DIVIDE(
      s.comparable_na_mal_attribue,
      s.comparable_na_reponses
    ),
    2
  ) AS observed_rate_pct,

  ROUND(
    100 * SAFE_DIVIDE(
      s.expected_mal_attribue_adjusted,
      s.comparable_na_reponses
    ),
    2
  ) AS expected_adjusted_rate_pct,

  ROUND(
    100 * (
      SAFE_DIVIDE(
        s.comparable_na_mal_attribue,
        s.comparable_na_reponses
      )
      -
      SAFE_DIVIDE(
        s.expected_mal_attribue_adjusted,
        s.comparable_na_reponses
      )
    ),
    2
  ) AS adjusted_gap_pp,

  ROUND(
    SAFE_DIVIDE(
      SAFE_DIVIDE(
        s.comparable_na_mal_attribue,
        s.comparable_na_reponses
      ),
      SAFE_DIVIDE(
        s.expected_mal_attribue_adjusted,
        s.comparable_na_reponses
      )
    ),
    2
  ) AS relative_risk_adjusted,

  ROUND(
    s.expected_mal_attribue_adjusted,
    1
  ) AS expected_mal_attribue_adjusted,

  ROUND(
    s.comparable_na_mal_attribue
      - s.expected_mal_attribue_adjusted,
    1
  ) AS excess_mal_attribue_adjusted,

  s.questionnaire_paths_covered,
  s.comparable_strata

FROM summary AS s
CROSS JOIN na_total AS t;