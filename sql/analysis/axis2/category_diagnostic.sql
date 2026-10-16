-- Objectif :
-- Produire le diagnostic final de MalAttribue par catégorie en distinguant
-- clairement surreprésentation et poids opérationnel.

-- Logique :
-- Sur les années complètes 2023–2025 et parmi les signalements avec réponse :
--   1. calculer la baseline globale de MalAttribue ;
--   2. agréger les volumes par catégorie ;
--   3. mesurer le taux de MalAttribue et son écart à la baseline ;
--   4. mesurer la contribution de chaque catégorie au volume total ;
--   5. estimer le nombre de MalAttribue "en excès" relativement à la baseline.
--
-- Les calculs sont effectués en pleine précision.
-- Les conversions en pourcentage et arrondis sont appliqués uniquement
-- dans la projection finale destinée à la lecture humaine.
--
-- Aucun score composite n'est créé : surreprésentation et volume restent
-- interprétables séparément.

-- Résultat attendu :
-- 1 ligne par catégorie.
--   - category : catégorie métier du signalement.
--   - nb_reponses : nombre de signalements de la catégorie ayant reçu une réponse.
--   - nb_mal_attribue : nombre de réponses terminées avec le statut MalAttribue.
--   - malattribue_rate_pct : pourcentage des réponses de la catégorie qui sont MalAttribue.
--   - baseline_rate_pct : taux global de MalAttribue sur l'ensemble des réponses 2023–2025, en %.
--   - gap_vs_baseline_pp : écart entre le taux de la catégorie et la baseline, en points de pourcentage.
--   - relative_risk_vs_baseline : ratio entre le taux de la catégorie et la baseline ; 2 = taux deux fois supérieur.
--   - share_of_responses_pct : pourcentage de toutes les réponses 2023–2025 appartenant à cette catégorie.
--   - share_of_mal_attribue_pct : pourcentage de tous les MalAttribue 2023–2025 appartenant à cette catégorie.
--   - expected_mal_attribue_at_baseline : nombre attendu de MalAttribue si la catégorie avait exactement le taux global.
--   - excess_mal_attribue_vs_baseline : différence entre nombre observé et attendu ; mesure descriptive, pas cas évitables.
--   - volume_status : indicateur de fiabilité selon le volume (<30 insuffisant, 30–99 faible, >=100 standard).

-- Lecture :
-- Lire selon deux axes :
--
-- A. Surreprésentation :
--   - malattribue_rate_pct ;
--   - gap_vs_baseline_pp ;
--   - relative_risk_vs_baseline.
--
-- B. Poids opérationnel :
--   - nb_mal_attribue ;
--   - share_of_mal_attribue_pct ;
--   - excess_mal_attribue_vs_baseline.
--
-- Une catégorie peut être importante parce qu'elle présente un très fort taux,
-- ou simplement parce qu'elle représente un très gros volume.

-- Vigilance / Hypothèses :
-- `excess_mal_attribue_vs_baseline` est descriptif, pas causal ni directement
-- interprétable comme un nombre de cas évitables.
-- La baseline globale contient les catégories comparées.
-- Les catégories à faible volume doivent rester interprétées avec prudence.

WITH eligible AS (
  SELECT
    category,
    status
  FROM `signalconso.signalconso_v1.stg_signalements`
  WHERE
    is_standard_population
    AND has_response
    AND EXTRACT(YEAR FROM report_month) BETWEEN 2023 AND 2025
),

global_baseline AS (
  SELECT
    COUNT(*) AS total_reponses,
    COUNTIF(status = 'MalAttribue') AS total_mal_attribue,
    SAFE_DIVIDE(
      COUNTIF(status = 'MalAttribue'),
      COUNT(*)
    ) AS baseline_rate
  FROM eligible
),

category_summary AS (
  SELECT
    category,
    COUNT(*) AS nb_reponses,
    COUNTIF(status = 'MalAttribue') AS nb_mal_attribue
  FROM eligible
  GROUP BY category
),

category_metrics AS (
  SELECT
    c.category,
    c.nb_reponses,
    c.nb_mal_attribue,

    SAFE_DIVIDE(
      c.nb_mal_attribue,
      c.nb_reponses
    ) AS malattribue_rate,

    b.baseline_rate,

    SAFE_DIVIDE(
      SAFE_DIVIDE(
        c.nb_mal_attribue,
        c.nb_reponses
      ),
      b.baseline_rate
    ) AS relative_risk_vs_baseline,

    SAFE_DIVIDE(
      c.nb_reponses,
      b.total_reponses
    ) AS share_of_responses,

    SAFE_DIVIDE(
      c.nb_mal_attribue,
      b.total_mal_attribue
    ) AS share_of_mal_attribue,

    c.nb_reponses * b.baseline_rate
      AS expected_mal_attribue_at_baseline

  FROM category_summary AS c
  CROSS JOIN global_baseline AS b
)

SELECT
  category,

  nb_reponses,
  nb_mal_attribue,

  ROUND(
    100 * malattribue_rate,
    2
  ) AS malattribue_rate_pct,

  ROUND(
    100 * baseline_rate,
    2
  ) AS baseline_rate_pct,

  ROUND(
    100 * (malattribue_rate - baseline_rate),
    2
  ) AS gap_vs_baseline_pp,

  ROUND(
    relative_risk_vs_baseline,
    2
  ) AS relative_risk_vs_baseline,

  ROUND(
    100 * share_of_responses,
    2
  ) AS share_of_responses_pct,

  ROUND(
    100 * share_of_mal_attribue,
    2
  ) AS share_of_mal_attribue_pct,

  ROUND(
    expected_mal_attribue_at_baseline,
    1
  ) AS expected_mal_attribue_at_baseline,

  ROUND(
    nb_mal_attribue - expected_mal_attribue_at_baseline,
    1
  ) AS excess_mal_attribue_vs_baseline,

  CASE
    WHEN nb_reponses < 30 THEN 'insufficient'
    WHEN nb_reponses < 100 THEN 'low_volume'
    ELSE 'standard'
  END AS volume_status

FROM category_metrics

ORDER BY
  excess_mal_attribue_vs_baseline DESC;