-- Objectif :
-- Décomposer l'anomalie AchatInternet de Nouvelle-Aquitaine par questionnaire_path
-- et vérifier si elle persiste à parcours et année comparables.

-- Logique :
-- Sur AchatInternet, années complètes 2023–2025 et signalements avec réponse :
--   1. comparer Nouvelle-Aquitaine au reste du territoire pour chaque année × questionnaire_path ;
--   2. appliquer les taux hors Nouvelle-Aquitaine aux volumes observés en Nouvelle-Aquitaine ;
--   3. agréger les résultats par questionnaire_path ;
--   4. mesurer taux observé, taux attendu, excès et contribution à l'excès total.
--
-- Cette comparaison contrôle donc simultanément :
--   - l'année ;
--   - le questionnaire_path.
--
-- Les calculs sont effectués en pleine précision.
-- Les pourcentages et arrondis sont appliqués uniquement dans le SELECT final.
--
-- Seuls les paths avec au moins 30 réponses couvertes en Nouvelle-Aquitaine
-- sont affichés afin d'éviter de prioriser des micro-volumes.

-- Résultat attendu :
-- 1 ligne par questionnaire_path AchatInternet suffisamment représenté en Nouvelle-Aquitaine.
--   - questionnaire_path : parcours de questionnaire AchatInternet analysé.
--   - na_nb_reponses : nombre de réponses observées en Nouvelle-Aquitaine sur les strates comparables.
--   - na_nb_mal_attribue : nombre de MalAttribue observés en Nouvelle-Aquitaine.
--   - na_malattribue_rate_pct : taux de MalAttribue observé en Nouvelle-Aquitaine pour ce path.
--   - expected_rate_adjusted_pct : taux attendu si ce path avait les taux observés hors Nouvelle-Aquitaine aux mêmes années.
--   - adjusted_gap_pp : écart entre taux observé et taux attendu, en points de pourcentage.
--   - relative_risk_adjusted : ratio entre taux observé et taux attendu ; 2 = taux deux fois supérieur.
--   - expected_mal_attribue_adjusted : nombre attendu de MalAttribue à path × année comparables.
--   - excess_mal_attribue_adjusted : différence entre nombre observé et attendu ; mesure descriptive.
--   - share_of_na_achatinternet_responses_pct : part des réponses AchatInternet de Nouvelle-Aquitaine représentée par ce path.
--   - share_of_na_achatinternet_mal_attribue_pct : part des MalAttribue AchatInternet de Nouvelle-Aquitaine provenant de ce path.
--   - share_of_positive_excess_pct : part de l'excès positif AchatInternet régional attribuable à ce path.
--   - years_covered : nombre d'années 2023–2025 contribuant effectivement à la comparaison.
--   - volume_status : indicateur de fiabilité selon le volume couvert en Nouvelle-Aquitaine.

-- Lecture :
-- A. Anomalie locale du path :
--   - adjusted_gap_pp ;
--   - relative_risk_adjusted.
--
-- B. Contribution à l'anomalie AchatInternet :
--   - excess_mal_attribue_adjusted ;
--   - share_of_positive_excess_pct.
--
-- C. Poids brut dans AchatInternet Nouvelle-Aquitaine :
--   - na_nb_mal_attribue ;
--   - share_of_na_achatinternet_mal_attribue_pct.
--
-- Si quelques paths concentrent l'essentiel de l'excès, l'anomalie régionale
-- est localisée.
-- Si beaucoup de paths présentent simultanément un excès positif, le phénomène
-- est plus transversal à AchatInternet.

-- Vigilance / Hypothèses :
-- questionnaire_path participe au mécanisme de qualification / routage SignalConso.
-- L'analyse reste descriptive et ne démontre pas une causalité régionale.
-- Les variantes historiques de taxonomie peuvent fragmenter des parcours proches.
-- Les strates sans volume de référence suffisant sont exclues de la comparaison.

WITH eligible AS (
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
    AND questionnaire_path IS NOT NULL
    AND region_code IS NOT NULL
    AND EXTRACT(YEAR FROM report_month) BETWEEN 2023 AND 2025
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

  FROM eligible

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

path_summary AS (
  SELECT
    questionnaire_path,

    SUM(na_nb_reponses) AS na_nb_reponses,
    SUM(na_nb_mal_attribue) AS na_nb_mal_attribue,
    SUM(expected_mal_attribue) AS expected_mal_attribue_adjusted,
    COUNT(DISTINCT year) AS years_covered

  FROM comparable_strata

  GROUP BY questionnaire_path
),

path_metrics AS (
  SELECT
    questionnaire_path,
    na_nb_reponses,
    na_nb_mal_attribue,
    expected_mal_attribue_adjusted,
    years_covered,

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

  FROM path_summary

  WHERE na_nb_reponses >= 30
),

totals AS (
  SELECT
    SUM(na_nb_reponses) AS total_na_responses,
    SUM(na_nb_mal_attribue) AS total_na_mal_attribue,

    SUM(
      GREATEST(
        excess_mal_attribue_adjusted,
        0
      )
    ) AS total_positive_excess

  FROM path_metrics
)

SELECT
  p.questionnaire_path,

  p.na_nb_reponses,
  p.na_nb_mal_attribue,

  ROUND(
    100 * p.na_malattribue_rate,
    2
  ) AS na_malattribue_rate_pct,

  ROUND(
    100 * p.expected_rate_adjusted,
    2
  ) AS expected_rate_adjusted_pct,

  ROUND(
    100 * (
      p.na_malattribue_rate
      - p.expected_rate_adjusted
    ),
    2
  ) AS adjusted_gap_pp,

  ROUND(
    SAFE_DIVIDE(
      p.na_malattribue_rate,
      p.expected_rate_adjusted
    ),
    2
  ) AS relative_risk_adjusted,

  ROUND(
    p.expected_mal_attribue_adjusted,
    1
  ) AS expected_mal_attribue_adjusted,

  ROUND(
    p.excess_mal_attribue_adjusted,
    1
  ) AS excess_mal_attribue_adjusted,

  ROUND(
    100 * SAFE_DIVIDE(
      p.na_nb_reponses,
      t.total_na_responses
    ),
    2
  ) AS share_of_na_achatinternet_responses_pct,

  ROUND(
    100 * SAFE_DIVIDE(
      p.na_nb_mal_attribue,
      t.total_na_mal_attribue
    ),
    2
  ) AS share_of_na_achatinternet_mal_attribue_pct,

  ROUND(
    100 * SAFE_DIVIDE(
      GREATEST(
        p.excess_mal_attribue_adjusted,
        0
      ),
      t.total_positive_excess
    ),
    2
  ) AS share_of_positive_excess_pct,

  p.years_covered,

  CASE
    WHEN p.na_nb_reponses < 30 THEN 'insufficient'
    WHEN p.na_nb_reponses < 100 THEN 'low_volume'
    ELSE 'standard'
  END AS volume_status

FROM path_metrics AS p
CROSS JOIN totals AS t

ORDER BY
  p.excess_mal_attribue_adjusted DESC;