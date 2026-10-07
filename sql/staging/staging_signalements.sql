-- Objectif :
-- Construire une couche staging stable au grain signalement, réutilisable
-- par les marts Axis 1 et les futures analyses Axis 2.

-- Logique :
-- Conserver les variables métier utiles de la source, standardiser quelques
-- noms techniques et ajouter uniquement des champs dérivés déjà justifiés
-- pendant J3/J4 : mois du signalement, appartenance à la population standard,
-- profondeur du questionnaire et nombre de tags.
--
-- Aucune normalisation sémantique des catégories n'est appliquée à ce stade :
-- la taxonomie évolue historiquement et doit être harmonisée uniquement sur
-- la base d'un mapping explicite.

-- Résultat attendu :
-- Une vue `stg_signalements` avec exactement 1 ligne par signalement.
-- Le nombre de lignes doit donc rester identique à `raw_signalements`
-- (1 733 022 lignes).

-- Lecture :
-- Après création, vérifier uniquement que la vue est créée et que son nombre
-- de lignes correspond au raw. Les transformations métier détaillées ont déjà
-- été validées lors du profiling et ne doivent pas être reprofilées ici.

-- Vigilance / Hypothèses :
-- `NA` est une valeur métier de `status`, pas un NULL.
-- `is_standard_population` exclut uniquement SuppressionRGPD et
-- InformateurInterne, conformément au contrat KPI J4.
-- Les champs géographiques restent disponibles même s'ils sont hors scope
-- du dashboard Axis 1 V1.

CREATE OR REPLACE VIEW
  `signalconso.signalconso_v1.stg_signalements` AS

SELECT
  id,

  -- Temps
  date AS report_date,
  DATE_TRUNC(date, MONTH) AS report_month,

  -- Taxonomie / questionnaire
  category,
  subcategories AS questionnaire_path,

  CASE
    WHEN subcategories IS NULL THEN NULL
    ELSE ARRAY_LENGTH(SPLIT(subcategories, ','))
  END AS questionnaire_path_depth,

  -- Tags
  tags,

  CASE
    WHEN tags IS NULL THEN 0
    ELSE ARRAY_LENGTH(SPLIT(tags, ','))
  END AS tag_count,

  -- Métier / workflow
  contact_agreement,
  status,
  forward_to_reponse_conso,

  signalement_transmis AS is_transmitted,
  signalement_lu AS is_consulted,
  signalement_reponse AS has_response,

  status NOT IN (
    'SuppressionRGPD',
    'InformateurInterne'
  ) AS is_standard_population,

  -- Géographie conservée pour réutilisation ultérieure
  dep_name,
  dep_code,
  region_name,
  region_code

FROM `signalconso.signalconso_v1.raw_signalements`;