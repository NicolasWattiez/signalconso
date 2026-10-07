-- Objectif :
-- Construire le mart analytique principal de l'axe 1 au grain
-- catégorie × mois, directement exploitable pour l'analyse J6
-- et le dashboard Looker Studio.

-- Logique :
-- Agréger le staging par mois de création et catégorie.
-- Calculer :
--   - les volumes de chaque étape du funnel ;
--   - les 3 KPI cœur ;
--   - les 2 métriques cumulées ;
--   - le statut de volume propre à chaque KPI ;
--   - un indicateur permettant d'identifier les mois consolidés.
--
-- Les taux sont stockés comme ratios entre 0 et 1, sans arrondi.
-- Le format en pourcentage sera géré dans l'analyse / le dashboard.

-- Résultat attendu :
-- 1 ligne par catégorie × mois.
-- Chaque ligne contient les volumes, taux et indicateurs nécessaires
-- à l'analyse de l'axe 1 sans réécrire la logique métier J4.

-- Lecture :
-- Le mart devra permettre :
--   - une vue globale par agrégation ;
--   - une évolution mensuelle ;
--   - une comparaison entre catégories ;
--   - une analyse catégorie × mois.
-- Les colonnes *_volume_status indiquent comment interpréter chaque KPI.

-- Vigilance / Hypothèses :
-- - La catégorie reste celle de la source : aucun mapping historique
--   n'est appliqué à ce stade.
-- - `is_consolidated_month` applique la règle M-2 définie en J4.
-- - Les seuils de volume utilisent le dénominateur propre à chaque KPI.
-- - `n >= 100` signifie "interprétation standard" pour la V1,
--   pas garantie statistique de précision.

CREATE OR REPLACE TABLE
  `signalconso.signalconso_v1.mart_axis1_category_month` AS

WITH params AS (
  SELECT
    MAX(report_date) AS max_date
  FROM `signalconso.signalconso_v1.stg_signalements`
),

aggregated AS (
  SELECT
    report_month AS month,
    category,

    COUNT(*) AS nb_signalements_total,

    COUNTIF(is_standard_population) AS nb_population_standard,

    COUNTIF(
      is_standard_population
      AND is_transmitted
    ) AS nb_transmis,

    COUNTIF(
      is_standard_population
      AND is_consulted
    ) AS nb_consultes,

    COUNTIF(
      is_standard_population
      AND has_response
    ) AS nb_reponses

  FROM `signalconso.signalconso_v1.stg_signalements`

  GROUP BY
    month,
    category
)

SELECT
  month,
  category,

  -- Volumes
  nb_signalements_total,
  nb_population_standard,
  nb_transmis,
  nb_consultes,
  nb_reponses,

  -- KPI cœur
  SAFE_DIVIDE(
    nb_transmis,
    nb_population_standard
  ) AS transmission_rate,

  SAFE_DIVIDE(
    nb_consultes,
    nb_transmis
  ) AS consultation_rate,

  SAFE_DIVIDE(
    nb_reponses,
    nb_consultes
  ) AS response_rate,

  -- Métriques cumulées
  SAFE_DIVIDE(
    nb_consultes,
    nb_population_standard
  ) AS consultation_overall_rate,

  SAFE_DIVIDE(
    nb_reponses,
    nb_population_standard
  ) AS response_overall_rate,

  -- Maturité temporelle
  month < DATE_SUB(
    DATE_TRUNC(max_date, MONTH),
    INTERVAL 1 MONTH
  ) AS is_consolidated_month,

  -- Qualité d'interprétation : transmission
  CASE
    WHEN nb_population_standard < 30 THEN 'insufficient'
    WHEN nb_population_standard < 100 THEN 'low_volume'
    ELSE 'standard'
  END AS transmission_volume_status,

  -- Qualité d'interprétation : consultation
  CASE
    WHEN nb_transmis < 30 THEN 'insufficient'
    WHEN nb_transmis < 100 THEN 'low_volume'
    ELSE 'standard'
  END AS consultation_volume_status,

  -- Qualité d'interprétation : réponse
  CASE
    WHEN nb_consultes < 30 THEN 'insufficient'
    WHEN nb_consultes < 100 THEN 'low_volume'
    ELSE 'standard'
  END AS response_volume_status

FROM aggregated
CROSS JOIN params;