# SignalConso — Axis 1 KPI Dictionary

**Version:** v0.1  
**Date:** 2026-10-06  
**Status:** Working semantic contract — validated for J4, subject to revision if later implementation or analysis reveals a better formulation or a necessary rule change.

---

## 1. Purpose

This document defines the semantic contract for the core KPIs used in **Axis 1 — SignalConso processing funnel analysis**.

Business objective:

> Analyze the SignalConso processing journey to identify its main operational frictions, then investigate one selected friction in greater depth.

Axis 1 focuses on the operational funnel:

**Transmission → Consultation → Response**

The purpose of this dictionary is to ensure that each KPI has:
- an unambiguous business meaning;
- a reproducible numerator and denominator;
- explicit population rules;
- explicit temporal rules;
- explicit low-volume interpretation rules.

This document is intended to remain short, auditable, and usable both for implementation and for later portfolio documentation.

---

## 2. Common semantic rules

### 2.1 Reference population

The **standard population** excludes reports whose `status` is:

- `SuppressionRGPD`
- `InformateurInterne`

These statuses are considered outside the standard company-processing funnel.

`NA` remains **included** in the standard population because it represents reports that do not enter the company-processing funnel and is therefore part of the first funnel loss that Axis 1 is intended to measure.

### 2.2 Funnel invariants

The following logical relationships have been verified on the full dataset:

- `signalement_lu = TRUE` implies `signalement_transmis = TRUE`
- `signalement_reponse = TRUE` implies `signalement_lu = TRUE`
- `signalement_reponse = TRUE` implies `signalement_transmis = TRUE`

No violations were found.

Therefore:

**Response ⊆ Consultation ⊆ Transmission**

### 2.3 Time grain

Primary time grain:

**calendar month of report creation**, based on the `date` field.

A monthly point therefore represents a cohort of reports **created during that month**, observed at the current state available in the dataset.

### 2.4 Consolidation rule

The most recent cohorts are affected by a maturity effect, especially for consultation and response.

For consolidated monthly comparisons:

- current month: excluded;
- previous complete month: excluded;
- latest consolidated month: **M-2**.

Example with a dataset ending on 2026-05-09:

- May 2026 → excluded: incomplete month;
- April 2026 → excluded: maturity buffer;
- March 2026 → latest consolidated month.

This is a conservative BI convention, not a measured processing-delay threshold, because the dataset does not provide consultation or response timestamps.

### 2.5 Minimum-volume rule

The minimum-volume rule applies to the **actual denominator of each KPI**.

Interpretation bands:

- **n < 30** → rate hidden / not interpreted;
- **30 ≤ n < 100** → rate may be displayed with a low-volume warning;
- **n ≥ 100** → standard interpretation/display.

`n = 100` is not a statistical guarantee of reliability. It is a pragmatic BI threshold intended to balance interpretability and coverage.

The denominator should remain accessible where practical so that users can distinguish, for example, a rate based on 105 observations from one based on 10,000.

### 2.6 Primary V1 dimensions

Primary analytical dimensions for Axis 1 V1:

- `month`
- `category`

Primary analytical grain:

**category × month**

### 2.7 Deferred / out-of-scope for Axis 1 V1

Not part of the Axis 1 V1 dashboard logic:

- geography (`region`, `department`);
- questionnaire paths (`subcategories`);
- tags.

These fields remain available in the data model and may be used in Axis 2 or later analyses.

`status` is retained primarily as a diagnostic / interpretive field rather than as a main segmentation dimension for Axis 1.

---

## 3. Core KPI definitions

## 3.1 `transmission_rate`

### Business meaning

Share of the standard report population that actually enters the company-processing funnel.

### Numerator

Count of reports where:

```sql
signalement_transmis = TRUE
```

### Denominator

Count of reports in the standard population:

```sql
status NOT IN ('SuppressionRGPD', 'InformateurInterne')
```

### Formula

```text
transmission_rate = nb_transmis / nb_population_standard
```

### Interpretation

Measures the first conversion step of the funnel:

**Standard population → Transmission**

A lower value indicates that a larger share of reports does not enter the company-processing funnel.

### Important caveat

`NA` is intentionally included in the denominator.

The KPI must therefore not be described as “company transmission performance” in isolation. It measures entry into the standard processing funnel, including reports that are filtered or routed out before transmission.

### Baseline on full dataset

- Standard population: 1,619,270
- Transmitted: 998,440
- `transmission_rate`: **61.66%**

---

## 3.2 `consultation_rate`

### Business meaning

Share of transmitted reports that are subsequently consulted.

### Numerator

Count of reports where:

```sql
signalement_lu = TRUE
```

### Denominator

Count of reports where:

```sql
signalement_transmis = TRUE
```

### Formula

```text
consultation_rate = nb_consultes / nb_transmis
```

### Interpretation

Measures the second conversion step of the funnel:

**Transmission → Consultation**

A lower value indicates that a larger share of transmitted reports remains unconsulted.

### Important caveat

This KPI does not measure how quickly a report is consulted because the dataset does not provide a consultation timestamp.

### Baseline on full dataset

- Transmitted: 998,440
- Consulted: 747,485
- `consultation_rate`: **74.87%**

---

## 3.3 `response_rate`

### Business meaning

Share of consulted reports that receive a recorded response.

### Numerator

Count of reports where:

```sql
signalement_reponse = TRUE
```

### Denominator

Count of reports where:

```sql
signalement_lu = TRUE
```

### Formula

```text
response_rate = nb_reponses / nb_consultes
```

### Interpretation

Measures the third conversion step of the funnel:

**Consultation → Response**

A lower value indicates that a larger share of consulted reports remains without a recorded response.

### Important caveat

A recorded response is not equivalent to a positive resolution or satisfactory outcome.

Statuses such as:

- `PromesseAction`
- `Infonde`
- `MalAttribue`

all count as responses when `signalement_reponse = TRUE`.

Therefore, `response_rate` measures **process completion at the response stage**, not response quality or consumer satisfaction.

### Baseline on full dataset

- Consulted: 747,485
- Responses: 666,552
- `response_rate`: **89.17%**

---

## 4. Complementary cumulative metrics

These metrics describe progression from the initial standard population rather than conversion between two successive funnel stages.

They are useful for reading the total loss accumulated across the funnel.

## 4.1 `consultation_overall_rate`

### Formula

```text
consultation_overall_rate = nb_consultes / nb_population_standard
```

### Meaning

Share of the standard population that ultimately reaches the consultation stage.

### Baseline

**46.16%**

---

## 4.2 `response_overall_rate`

### Formula

```text
response_overall_rate = nb_reponses / nb_population_standard
```

### Meaning

Share of the standard population that ultimately reaches the response stage.

### Baseline

**41.16%**

### Important caveat

Like `response_rate`, this metric does not measure whether the response was positive, useful, or satisfactory.

---

## 5. KPI interpretation model

The three core KPIs should be interpreted as **conditional conversion rates**:

```text
Standard population
        ↓ transmission_rate
Transmitted reports
        ↓ consultation_rate
Consulted reports
        ↓ response_rate
Reports with response
```

The complementary metrics answer a different question:

```text
What share of the original standard population reached this stage?
```

Therefore:

- core KPIs → identify friction between successive steps;
- cumulative metrics → assess total funnel progression from the initial population.

These two families should not be conflated.

---

## 6. Implementation expectations

For any segmented KPI result:

- the KPI numerator must be calculated within the same segment;
- the KPI denominator must be calculated within the same segment;
- the minimum-volume rule must use the KPI-specific denominator;
- the monthly consolidation rule must be applied before comparative interpretation.

Example:

For a category-month with:

- 120 standard reports;
- 80 transmitted;
- 47 consulted;
- 42 responses;

volume status is evaluated separately:

- `transmission_rate`: denominator = 120 → standard interpretation;
- `consultation_rate`: denominator = 80 → low-volume warning;
- `response_rate`: denominator = 47 → low-volume warning.

The initial category volume must not be reused as a proxy for downstream KPI reliability.

---

## 7. V1 scope boundaries

Axis 1 V1 prioritizes depth and consistency over breadth.

Included:

- global funnel view;
- monthly evolution;
- category comparison;
- category × month analysis;
- core KPI conversion rates;
- complementary cumulative rates;
- low-volume handling;
- cohort consolidation rule.

Deferred:

- geographic segmentation;
- questionnaire-path segmentation;
- tag-based segmentation;
- detailed causal/statistical inference;
- response-quality analysis;
- event-based social / regulatory interpretation;
- formal uncertainty intervals in the dashboard.

These may be investigated later, especially in Axis 2 or post-V1 analysis.

---

## 8. Revision policy

This document is a semantic contract for the current project state, not an immutable specification.

A revision is appropriate if:

- staging reveals an implementation issue;
- later analysis shows that a definition is misleading;
- dashboard usability requires a clearer label;
- a better business term is identified;
- additional evidence changes the population or maturity rules.

When revising:
- preserve the previous dated version;
- document the reason for the change;
- distinguish wording changes from semantic changes.

Semantic changes should trigger a review of affected SQL, marts, and dashboard calculations.

---

## 9. Current decision status

As of 2026-10-06:

- core KPI formulas: **frozen for V1 implementation**;
- standard population definition: **frozen for V1 implementation**;
- monthly cohort rule: **frozen for V1 implementation**;
- M-2 consolidation rule: **frozen for V1 implementation**;
- low-volume thresholds: **frozen for V1 implementation**;
- exact dashboard labels / wording: **revisable**;
- exact dashboard visual treatment of volume warnings: **deferred to dashboard design**;
- additional dimensions beyond month/category: **deferred**.
