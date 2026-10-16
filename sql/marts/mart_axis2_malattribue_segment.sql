-- Objectif :
-- Créer le mart minimal destiné à la Page 2 Data Studio pour l'analyse
-- descriptive de MalAttribue sur la population avec réponse en 2023–2025.

-- Logique :
-- Agréger les signalements au grain année × catégorie × questionnaire_path × région.
-- Conserver uniquement des mesures additives afin que les taux puissent être
-- recalculés correctement dans Data Studio après filtrage ou regroupement.
--
-- Population :
--   - population standard ;
--   - signalements ayant reçu une réponse ;
--   - années 2023 à 2025 incluses.

-- Résultat attendu :
-- 1 ligne par année × catégorie × questionnaire_path × région.
--   - year : année du signalement.
--   - category : catégorie métier du signalement.
--   - questionnaire_path : parcours détaillé du questionnaire.
--   - region_code : code de la région ; nullable si géographie indisponible.
--   - region_name : nom de la région ; nullable si géographie indisponible.
--   - is_nouvelle_aquitaine : TRUE si region_code = '75'.
--   - nb_responses : nombre de signalements avec réponse dans le segment.
--   - nb_mal_attribue : nombre de réponses avec status = 'MalAttribue'.

-- Lecture :
-- Data Studio devra calculer le taux avec :
--   SUM(nb_mal_attribue) / SUM(nb_responses)
-- et non avec une moyenne de taux pré-calculés.

-- Vigilance / Hypothèses :
-- Les valeurs NULL de questionnaire_path ou de géographie sont conservées
-- afin de préserver la réconciliation avec la population analytique complète.
-- Les résultats statistiques J10 ne sont pas recalculés dans ce mart.

CREATE OR REPLACE TABLE
  `signalconso.signalconso_v1.mart_axis2_malattribue_segment`
AS

SELECT
  EXTRACT(YEAR FROM report_month) AS year,
  category,
  questionnaire_path,
  region_code,
  region_name,
  region_code = '75' AS is_nouvelle_aquitaine,
  COUNT(*) AS nb_responses,
  COUNTIF(status = 'MalAttribue') AS nb_mal_attribue

FROM `signalconso.signalconso_v1.stg_signalements`

WHERE
  is_standard_population
  AND has_response
  AND EXTRACT(YEAR FROM report_month) BETWEEN 2023 AND 2025

GROUP BY
  year,
  category,
  questionnaire_path,
  region_code,
  region_name,
  is_nouvelle_aquitaine;