# SignalConso — Analyse du parcours de traitement des signalements

Projet de portfolio **Data Analyst / BI**, mené dans un workflow analytique augmenté par l’IA, à partir des données publiques de **SignalConso**, le service français de signalement des problèmes rencontrés par les consommateurs.

L’objectif est d’analyser le parcours de traitement des signalements afin d’identifier les principales frictions observables, puis d’approfondir un cas particulier — `MalAttribue`, un état indiquant qu’un signalement ayant reçu une réponse a été considéré comme mal attribué — pour mieux comprendre les facteurs qui lui sont associés.

L’IA a servi de couche d’assistance à l’analyse et à l’organisation du projet, sous supervision humaine.

**Dashboard Data Studio :** [à ajouter](DASHBOARD_URL)  
**Source des données :** [SignalConso — source officielle](SOURCE_URL)

---

## Résultats clés

- La **transmission** constitue la plus forte réduction observable du parcours global, avec des profils de friction différents selon les catégories.
- Les difficultés ne se situent pas toutes au même endroit : certaines catégories se distinguent lors de la transmission, d’autres lors de la consultation ou de la réponse.
- `MalAttribue` présente une forte hétérogénéité selon les catégories et les parcours de questionnaire.
- Dans `AchatInternet`, une anomalie marquée en **Nouvelle-Aquitaine** persiste après prise en compte de l’année et du `questionnaire_path`, puis après validation statistique ciblée.

L’analyse reste **descriptive et diagnostique** : elle localise des anomalies et des associations, sans prétendre établir leurs causes.

---

## Objectif analytique

Le projet suit deux axes complémentaires.

### Axe 1 — Analyse globale du processus

Étudier le parcours :

`Transmission → Consultation → Réponse`

afin d’identifier où se situent les principales réductions observables et quels types de signalements sont les plus concernés.

### Axe 2 — Diagnostic ciblé de `MalAttribue`

Étudier les signalements ayant reçu une réponse mais considérés comme mal attribués, afin d’identifier les catégories, parcours de questionnaire et caractéristiques géographiques qui leur sont associés.

### Démarche analytique

La démarche suit cette progression :

```text
vue globale
→ identification des frictions
→ segmentation
→ diagnostic ciblé
→ validation statistique
```

---

## Données et stack

Le snapshot complet de SignalConso utilisé pour cette V1 contient :

- **1 733 022 signalements**
- des enregistrements depuis **2018**
- des données brutes non versionnées dans GitHub

Un premier export d’environ 90 000 lignes a été utilisé uniquement comme échantillon technique lors de la phase initiale. Il n’a pas servi aux conclusions finales.

Le fichier source utilisé pour la V1 est identifié localement par :

```text
SHA-256:
6eb330ec50396a41d6d2395fa28519babb100483034c67d8541a9d041c13af1d
```

### Stack principale

- **BigQuery / SQL** — profilage des données, modélisation et analyses principales
- **Python** — préparation de la source et validation statistique ciblée
- **pandas / statsmodels** — analyse statistique locale
- **Data Studio** — dashboard BI
- **Git / GitHub** — gestion de versions et publication du portfolio

SQL constitue la couche analytique principale. Python est utilisé lorsqu’il apporte une information supplémentaire par rapport à l’analyse SQL et au dashboard.

---

## Architecture des données

```text
Source SignalConso
        ↓
       raw
        ↓
     staging
1 ligne = 1 signalement
        ↓
        ├── mart Axe 1
        │      ↓
        │   analyse globale
        │      ↓
        │   Data Studio — Page 1
        │
        └── mart Axe 2
               ↓
          diagnostic MalAttribue
               ↓
          Data Studio — Page 2

staging / extract contrôlé
        ↓
validation statistique locale en Python
```

La couche staging centralise les règles métier réutilisables et les champs dérivés. Les deux marts restent volontairement ciblés sur leurs usages analytiques respectifs.

Data Studio utilise pour cette V1 des snapshots exportés des marts plutôt qu’une connexion BigQuery directe.

Principaux modèles SQL :

- [`staging_signalements.sql`](sql/staging/staging_signalements.sql)
- [`mart_axis1_category_month.sql`](sql/marts/mart_axis1_category_month.sql)
- [`mart_axis2_malattribue_segment.sql`](sql/marts/mart_axis2_malattribue_segment.sql)

Les définitions des KPI sont documentées dans [`docs/kpi_definitions.md`](docs/kpi_definitions.md).

---

## Axe 1 — Analyse globale du parcours

Sur les données consolidées en excluant les deux mois les plus récents (**règle M-2**), les trois KPI principaux sont :

| Étape | Taux |
|---|---:|
| Transmission | **61,19 %** |
| Consultation parmi les signalements transmis | **75,45 %** |
| Réponse parmi les signalements consultés | **89,59 %** |

La plus forte réduction observable se situe donc au niveau de la **transmission**.

Ce résultat doit toutefois être interprété avec prudence : tous les signalements non transmis ne correspondent pas nécessairement à un échec opérationnel. Certains suivent des parcours qui sortent du processus classique de transmission à une entreprise.

### Principaux constats

- `DemarchageAbusif` présente une forte réduction au stade de la transmission.
- `Internet` se distingue particulièrement au stade de la consultation.
- `TravauxRenovations` et `CafeRestaurant` présentent davantage de friction en aval.
- `AchatMagasin` fournit un point de comparaison relativement favorable.

La requête synthétique utilisée pour consolider ces résultats est disponible ici :

[`final_evidence_pack.sql`](sql/analysis/axis1/final_evidence_pack.sql)

---

## Axe 2 — Diagnostic `MalAttribue`

L’Axe 2 se concentre sur la **population standard des signalements ayant reçu une réponse entre 2023 et 2025**.

Le taux de référence global de `MalAttribue` sur cette population est d’environ :

**9,05 %**

Le phénomène est cependant très hétérogène selon les catégories.

| Catégorie | Taux `MalAttribue` |
|---|---:|
| `DemarchageAbusif` | **41,40 %** |
| `Internet` | **25,01 %** |
| `AchatInternet` | **10,14 %** |
| Taux de référence global | **9,05 %** |

### Trois angles complémentaires

L’analyse distingue :

- **surreprésentation** — où le taux est particulièrement élevé ;
- **excès descriptif** — où le taux et le volume se combinent pour produire un écart important par rapport au taux de référence ;
- **volume absolu** — où se concentre le plus grand nombre de cas.

Ainsi, une catégorie peut présenter un taux très élevé sans représenter beaucoup de cas, ou au contraire afficher un taux plus modéré tout en pesant fortement dans le volume total.

`AchatInternet` illustre ce second cas : son taux n’est que légèrement supérieur au taux de référence global, mais son volume lui donne une importance opérationnelle beaucoup plus forte.

Analyses publiques :

- [`category_diagnostic.sql`](sql/analysis/axis2/category_diagnostic.sql)
- [`questionnaire_path_diagnostic.sql`](sql/analysis/axis2/questionnaire_path_diagnostic.sql)

---

## Segmentation par parcours de questionnaire

Les catégories larges masquent une forte variation interne.

Certains `questionnaire_path` présentent :

- des taux très élevés mais de faibles volumes ;
- des taux plus modérés associés à des volumes importants ;
- ou une combinaison des deux.

Le parcours de questionnaire apporte donc un niveau de segmentation supplémentaire par rapport à la seule catégorie.

Pour limiter les interprétations instables, les `questionnaire_path` avec moins de **100 réponses** sont exclus localement du classement présenté dans Data Studio.

---

## Anomalie Nouvelle-Aquitaine

L’un des résultats les plus marqués apparaît dans `AchatInternet` en Nouvelle-Aquitaine.

### Résultat brut

- **9 111 réponses**
- **3 396 `MalAttribue`**
- **37,27 %**

Cette anomalie n’apparaît pas comme une hausse généralisée à toutes les catégories de la région. Elle est principalement concentrée dans `AchatInternet`.

Pour la comparaison ajustée, seules les strates disposant d’observations en Nouvelle-Aquitaine et d’au moins **100 réponses dans le reste de la France** sont retenues.

Après comparaison sur des strates comparables `année × questionnaire_path` :

- **98 strates**
- **8 815 réponses en Nouvelle-Aquitaine**
- **3 295 `MalAttribue`**
- **37,38 %**

L’anomalie reste donc très importante après prise en compte de la composition par année et par `questionnaire_path`.

SQL correspondant :

[`nouvelle_aquitaine_adjusted.sql`](sql/analysis/axis2/nouvelle_aquitaine_adjusted.sql)

---

## Validation statistique ciblée

Une analyse Python a ensuite été utilisée pour répondre à une question précise :

> L’association observée dans `AchatInternet` en Nouvelle-Aquitaine reste-t-elle forte après prise en compte de l’année et du `questionnaire_path` ?

Une analyse stratifiée de Cochran–Mantel–Haenszel sur les **98 strates comparables** donne :

- **odds ratio ajusté : 6,391**
- **IC 95 % : [6,091 ; 6,705]**

L’association reste forte après stratification.

Un contrôle d’homogénéité montre cependant que son intensité varie sensiblement selon les strates. L’odds ratio agrégé doit donc être interprété comme un résumé global et non comme un effet uniforme.

L’anomalie est également observée séparément en **2023, 2024 et 2025**.

> **Conclusion : association ajustée forte et anomalie observée robuste — pas un effet régional causal démontré.**

---

## Dashboard Data Studio

Le dashboard contient deux pages.

### Page 1 — Parcours global

- KPI Transmission / Consultation / Réponse
- évolution mensuelle
- comparaison par catégorie

### Page 2 — `MalAttribue`

- taux global
- taux et volumes par catégorie
- segmentation par `questionnaire_path`
- comparaison Nouvelle-Aquitaine / reste de la France pour `AchatInternet`
- filtre annuel 2023–2025

Les métriques du dashboard ont été réconciliées avec les marts analytiques avant interprétation.

Quelques règles de présentation permettent également d’éviter les lectures instables :

- les `questionnaire_path` avec moins de **100 réponses** sont exclus localement du classement ;
- `Accessibilite` est exclue localement de la comparaison des taux par catégorie car son résultat repose sur seulement **7 réponses** ;
- les signalements sans géographie exploitable restent conservés dans le mart pour la réconciliation, mais sont exclus des comparaisons géographiques.

---

## Limites d’interprétation

Principaux garde-fous :

- **association ≠ causalité** ;
- `MalAttribue` n’est pas une mesure générale de performance des entreprises ;
- les métriques d’« excès » sont descriptives et ne représentent pas directement des cas évitables ;
- `questionnaire_path` est probablement partiellement lié au processus de qualification et de routage de SignalConso ;
- la taxonomie des catégories et parcours a évolué dans le temps ;
- les comparaisons géographiques sont limitées aux signalements disposant d’une géographie exploitable ;
- la documentation publique ne décrit pas complètement tous les états et mécanismes du processus ;
- les données publiques ne permettent pas de mesurer directement la satisfaction finale du consommateur ou la résolution effective du problème.

Une rupture historique avant mai 2021 est compatible avec les règles de conservation et de suppression liées au RGPD, mais la documentation publique disponible ne permet pas d’en confirmer formellement le mécanisme exact.

---

## Structure du dépôt

```text
.
├── README.md
├── requirements.txt
├── requirements-dev.txt
├── docs/
│   └── kpi_definitions.md
├── python/
│   └── prepare_source.py
└── sql/
    ├── staging/
    │   └── staging_signalements.sql
    ├── marts/
    │   ├── mart_axis1_category_month.sql
    │   └── mart_axis2_malattribue_segment.sql
    └── analysis/
        ├── axis1/
        │   └── final_evidence_pack.sql
        └── axis2/
            ├── category_diagnostic.sql
            ├── questionnaire_path_diagnostic.sql
            └── nouvelle_aquitaine_adjusted.sql
```

Les données brutes, worklogs, requêtes exploratoires et fichiers intermédiaires restent volontairement hors du dépôt public.

---

## Étapes de reproduction

1. récupérer la source publique SignalConso ;
2. préparer la source localement avec `python/prepare_source.py` ;
3. charger les données dans BigQuery ;
4. construire la couche staging ;
5. construire les deux marts analytiques ;
6. exécuter les analyses SQL publiées ;
7. exporter les snapshots utilisés dans Data Studio.

Les identifiants de projet et de dataset BigQuery doivent être adaptés à l’environnement d’exécution.

Les données sources et les fichiers analytiques générés ne sont pas versionnés dans ce dépôt.
