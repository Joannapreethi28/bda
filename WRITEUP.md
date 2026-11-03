# Predicting Serious Outcomes in FDA Adverse Event Reports with BigQuery ML

> All numbers come from the SQL in `sql/`; the raw outputs are in `results/`. Run date: 2026-10-15.

## 1. Problem

Given one FDA Adverse Event Reporting System (FAERS) safety report, predict whether the patient was **hospitalized or died** (`label = 1`) or not (`label = 0`). The model only sees simple report details: patient age, sex, the main suspect drug, the number of drugs, and the number of reactions.

Questions:
- **Q1.** Can the model beat the "always guess the most common class" baseline?
- **Q2.** Which details push a report toward a serious outcome?
- **Q3.** Where does the model get things wrong?

The reports are voluntary, so any finding means "reports with X tend to be serious". It never means "drug X causes hospitalization".

## 2. Data and sampling

**Source.** The data comes from the openFDA drug adverse event bulk export (https://open.fda.gov/data/downloads/, export dated 2026-10-12): 1,767 zip files, 20.7M reports, about 110 GB zipped.

**Deviation 1: no public table.** The plan assumed `bigquery-public-data.fda_drug.drug_event`. Our Step 0 check showed that the `fda_drug` dataset only has `drug_label` and `drug_enforcement` (`results/00a_tables.txt`). So we uploaded our own copy instead:
1. We randomly sampled **25 of the 1,767 partition files** (Python `random.seed(42)`): **296,816 reports**, about 1.16 GB zipped, received between 2005 and 2025.
2. `scripts/prepare_data.py` streams each file and keeps only the needed fields, in the original nested layout (`safetyreportid`, `receivedate`, `seriousnesshospitalization`, `seriousnessdeath`, `patient.patientsex/onsetage/onsetageunit`, `patient.drug[].medicinalproduct/drugcharacterization`, `patient.reaction[].reactionmeddrapt`). It writes the result as gzipped NDJSON.
3. We ran `bq load` (free) into `faers.drug_event_raw` with `scripts/drug_event_schema.json`. This also covers the plan's optional upload step.

**Deviation 2: sampling.** Because the file sample is already small, the plan's 5% `FARM_FINGERPRINT` filter is **not** applied when flattening. Note that sampling whole files is a **cluster sample**: each file holds reports from one quarter, so some periods are over- or under-represented compared with a true random sample of reports.

**Environment.** BigQuery Sandbox project `faers-sandbox-10151307` (student account, billing disabled), dataset `faers` in the US location. Everything stayed within the free tier.

**Profile** (`02_profile.sql`):

| Item | Value |
|---|---|
| Raw rows uploaded / distinct report IDs | 296,816 / 296,796 (20 duplicate IDs removed, keeping the latest `receivedate`) |
| Reports in `reports_flat` | 296,796 |
| Serious (label = 1) | 82,040 (27.6%) |
| Missing age | 135,368 (45.6%) |
| Age > 120 (set to NULL) | 1 |
| Missing suspect drug (becomes `OTHER`) | 220 |
| Median age (years) | 58 |
| Train / test rows | 237,832 / 58,964 |

Step 0 also found an age-unit code **805 (hours)** that the plan did not list, so we added it to the conversion.

## 3. Method

- **Row:** one safety report.
- **Label:** `1` if `seriousnesshospitalization = 1` OR `seriousnessdeath = 1`, else `0`.
- **Features:**
  - `age_years`: onset age converted to years from unit codes 800-805 (decade/year/month/week/day/hour). Values outside 0-120 are set to NULL, and missing values stay NULL.
  - `sex`: missing values become `'UNK'`.
  - `n_drugs` and `n_reactions`: lengths of the drug and reaction arrays.
  - `drug_group`: the first suspect drug (`drugcharacterization = 1`), upper-cased and trimmed. It is kept only if it is among the **top 30 suspect drugs in the training rows**, and set to `OTHER` otherwise.
- **Split:** 80% train / 20% test, using `MOD(ABS(FARM_FINGERPRINT(safetyreportid)), 10) < 8`. `safetyreportid` is not used as a feature.
- **Baseline:** predict the training majority class for every test row.
- **Models:** `LOGISTIC_REG` and `BOOSTED_TREE_CLASSIFIER` (`max_tree_depth = 4`), both with `auto_class_weights = TRUE` and `data_split_method = 'NO_SPLIT'`.
- **Leakage exclusions (plan section 5):** we did not use any other seriousness field (`serious`, `seriousnesslifethreatening`, `seriousnessdisabling`, `seriousnesscongenitalanomali`, `seriousnessother`), `patient.patientdeath`/death date, or reaction terms such as `DEATH` or `HOSPITALISATION`. Most of these were never uploaded (`prepare_data.py` drops them). The reaction terms are uploaded but not used as features.

## 4. Results (test set)

| Model | Accuracy | Precision (1) | Recall (1) | F1 | ROC AUC | Log loss |
|---|---|---|---|---|---|---|
| Majority baseline (always 0) | **0.723** | n/a | 0.000 | 0.000 | 0.500 | n/a |
| Logistic regression | 0.616 | 0.390 | **0.681** | 0.496 | **0.688** | 0.635 |
| Boosted tree (depth 4) | 0.649 | 0.412 | 0.630 | **0.498** | 0.683 | 0.638 |

Both models were trained in the Sandbox without billing. The boosted tree was **not** refused. Accuracy is lower than the baseline because `auto_class_weights = TRUE` makes the models favour catching serious reports over overall accuracy.

**Which metric matters.** Missing a serious report (a false negative) is worse than flagging a mild one, because a missed hospitalization or death is a safety signal that nobody follows up. Flagging a mild report only costs a reviewer some time. So we watch **recall on class 1** most, with precision and ROC AUC as secondary checks so the model does not get there by flagging everything.

## 5. Confusion matrices (test set, threshold 0.5)

**Logistic regression**

| | Predicted 0 | Predicted 1 |
|---|---|---|
| **Actual 0** | 25,220 | 17,415 (false alarms) |
| **Actual 1** | 5,213 (missed) | 11,116 |

**Boosted tree**

| | Predicted 0 | Predicted 1 |
|---|---|---|
| **Actual 0** | 27,966 | 14,669 |
| **Actual 1** | 6,046 | 10,283 |

The logistic model misses fewer serious reports (5,213 vs 6,046), and pays for it with about 2,700 more false alarms.

## 6. Feature importance

`ML.WEIGHTS` (logistic) / `ML.FEATURE_IMPORTANCE` (boosted tree):

| Feature | Logistic weight (standardized) | Boosted-tree gain (rank) | Direction |
|---|---|---|---|
| `age_years` | +0.241 | 588 (1st) | older → more serious |
| `n_drugs` | +0.268 | 545 (2nd) | more drugs → more serious |
| `sex` | male +0.267, female −0.171, unknown −0.445 | 410 (3rd) | male → more serious |
| `drug_group` | range −2.19 to +1.52 | 270 (4th) | depends on the drug (below) |
| `n_reactions` | +0.202 | 217 (5th) | more reactions → more serious |

**Drug groups pushing toward serious:** AVONEX (+1.52), REMICADE (+0.58), ELIQUIS (+0.50), OTHER (+0.27), REVLIMID (+0.18).
**Drug groups pushing toward non-serious:** PROACTIV acne products (−2.19, −2.17), ALLI (−1.88), REPATHA (−1.77), AIMOVIG (−1.70), RISPERDAL (−1.68), DUPIXENT (−1.67), RANITIDINE/ZANTAC (−1.65, −1.58).

The list also shows the messy-names problem: ZANTAC and "RANITIDINE." are the same drug, but they count as two separate groups. (Full output: `results/09_weights_logreg.txt`, `results/10_importance_boosted.txt`.)

## 7. Ten example predictions

| # | report id | age_years | sex | n_drugs | n_reactions | drug_group | P(label=1) | Predicted | Actual |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 18683281 | 4.0 | 1 | 17 | 1 | OTHER | 0.632 | 1 | 1 |
| 2 | 19603709 | 66.0 | 1 | 2 | 2 | OTHER | 0.625 | 1 | 1 |
| 3 | 13376244 | 56.0 | 2 | 11 | 2 | OTHER | 0.609 | 1 | 1 |
| 4 | 13394034 | 72.0 | 2 | 1 | 2 | OTHER | 0.522 | 1 | 1 |
| 5 | 17907985 | 30.0 | 2 | 1 | 5 | OTHER | 0.445 | 0 | 1 |
| 6 | 13065148 | 76.0 | 2 | 2 | 1 | OTHER | 0.533 | 1 | 0 |
| 7 | 25354365 | 59.0 | UNK | 1 | 3 | ELIQUIS | 0.487 | 0 | 0 |
| 8 | 9263764 | NULL | 0 | 1 | 2 | OTHER | 0.480 | 0 | 0 |
| 9 | 13135679 | NULL | 2 | 2 | 7 | HUMIRA | 0.478 | 0 | 0 |
| 10 | 22709503 | NULL | 2 | 1 | 3 | DUPIXENT | 0.120 | 0 | 0 |

These are 5 serious and 5 non-serious test reports, picked by hash and scored by the logistic model. 8 of 10 are right. Report 17907985 (serious, 30-year-old woman, one drug) was missed, and report 13065148 (non-serious, 76-year-old) was a false alarm. Sex codes: 1 = male, 2 = female, 0 = unknown.

## 8. Answers

**Q1. Does it beat the baseline?** **Yes on the metrics that matter, no on raw accuracy.** The majority baseline gets 72.3% accuracy but catches **0%** of serious reports, and its ROC AUC is 0.5. Logistic regression catches **68.1%** of serious reports with ROC AUC **0.688**, and the boosted tree catches 63.0% with AUC 0.683. Their accuracy (62–65%) is below the baseline because class weighting makes them flag more reports. The signal is real but modest: an AUC around 0.69 means age, sex, drug and counts only partly separate serious reports from mild ones. The two models are almost tied; the simpler logistic model is slightly better on recall and AUC, so we prefer it.

**Q2. What pushes a report toward serious?** **Older age, more drugs listed, and being male** are the strongest pushes in both models (the top three by boosted-tree gain). More reactions also push toward serious. Some drug groups strongly raise the chance (AVONEX, REMICADE, ELIQUIS), while consumer and lifestyle products lower it (PROACTIV acne products, ALLI) along with several newer injectables (REPATHA, AIMOVIG, DUPIXENT). This is association only: drugs like ELIQUIS are given to older, sicker patients, so the drug may stand in for how ill the patient already was.

**Q3. Where does it go wrong?** (`results/12_error_analysis.txt`, logistic model)
- **Too many false alarms overall:** 17,415 mild reports flagged as serious, so precision is only 39%.
- **Misses serious reports for young people and people with unknown details:** the miss rate is **73% for under-18s**, **84% when sex is unknown**, and **47% when age is missing**. The model has learned "old + male = serious", so serious cases that don't fit that pattern slip through.
- **Over-flags the elderly and men:** for ages 65+ it misses only 8% of serious reports, but 47% of its predictions for that group are wrong, mostly false alarms. The pattern for men is the same (8% missed, 50% error rate).
- **Missing age (46% of reports)** is the biggest weak spot: imputation fills in the average age, so these reports lose the most useful feature.

## 8b. Upgrade: hyperparameter tuning (boosted tree)

**Method (no test leakage).** We split the training rows again by hash: rows with `hash % 10 < 7` were used for fitting and rows with `hash % 10 = 7` for validation. Four configurations were trained in parallel (`sql/13_tune_1..4.sql`) and compared on the validation rows only (`sql/14_tune_compare.sql`). The best by ROC AUC was retrained on all the training rows (`sql/15_train_boosted_tuned.sql`) and scored on the test set **once** (`sql/16_evaluate_tuned.sql`).

| Config (depth / learn_rate / subsample) | Validation ROC AUC | Validation recall | Validation F1 |
|---|---|---|---|
| **8 / 0.1 / 0.8 (chosen)** | **0.703** | 0.661 | 0.507 |
| 6 / 0.3 / 0.8 | 0.702 | 0.678 | 0.507 |
| 6 / 0.1 / 1.0 | 0.688 | 0.663 | 0.502 |
| 4 / 0.3 / 1.0 (the plan's depth) | 0.687 | 0.648 | 0.499 |

**Test results, final:**

| Model | Accuracy | Precision | Recall | F1 | ROC AUC |
|---|---|---|---|---|---|
| Majority baseline | 0.723 | n/a | 0.000 | 0.000 | 0.500 |
| Logistic regression | 0.616 | 0.390 | **0.681** | 0.496 | 0.688 |
| Boosted tree, depth 4 | 0.649 | 0.412 | 0.630 | 0.498 | 0.683 |
| **Boosted tree, tuned** | 0.647 | **0.414** | 0.656 | **0.507** | **0.705** |

Tuned confusion matrix: actual 0 → 27,456 / 15,179 (predicted 0 / 1); actual 1 → 5,622 / 10,707.

**Takeaway.** Deeper trees with row subsampling give the best ranking ability (AUC 0.705) and the best F1. The gain is small, about +0.02 AUC, which suggests the five basic features, not the model settings, are what limit performance. Logistic regression still catches slightly more serious reports (recall 0.681 vs 0.656). If recall is the top priority, it remains a fair choice, or the tuned tree's threshold could be lowered. Notably, in the deeper tree **`drug_group` becomes the most important feature** (gain 80, against 43 for age; `results/18_importance_tuned.txt`), because deeper trees can combine drug with age and sex.

## 8c. Upgrade: reaction-term flags

We added 20 yes/no columns, one for each of the 20 most common reaction terms in the **training rows** (`sql/19_top_reactions.sql`, `sql/20_reaction_features.sql`). Any term that gives the label away was excluded first, using the regex `DEATH|DIED|FATAL|HOSPITAL|SUICIDE|LIFE THREATENING`. Both models were retrained with the same settings and scored on the **same test rows** as before (`sql/21`, `22`, `23`).

| Model (same test set) | Accuracy | Precision | Recall | F1 | ROC AUC |
|---|---|---|---|---|---|
| Logistic regression, basic features | 0.616 | 0.390 | 0.681 | 0.496 | 0.688 |
| Boosted tree tuned, basic features | 0.647 | 0.414 | 0.656 | 0.507 | 0.705 |
| **Logistic regression + reaction flags** | **0.673** | **0.438** | 0.637 | 0.519 | **0.727** |
| **Boosted tree tuned + reaction flags** | 0.632 | 0.410 | **0.741** | **0.527** | 0.718 |

**Takeaway.** The reaction flags are the biggest single improvement in the project. ROC AUC rises to **0.727**, and the boosted tree with flags catches **74%** of serious reports, the best recall so far. This supports the earlier conclusion that the features, more than the model settings, limit performance.

**Which reactions push toward serious** (`sql/24_rx_weights.sql`, logistic weight of yes vs no):
- Toward serious: **FALL (+0.70), PYREXIA/fever (+0.68), DYSPNOEA/breathlessness (+0.33), VOMITING (+0.32), ASTHENIA/weakness (+0.27)**. These are physical events that often lead to a hospital visit.
- Toward non-serious: **INJECTION SITE PAIN (−0.67), DRUG INEFFECTIVE (−0.55), INCORRECT DOSE ADMINISTERED (−0.54), PRURITUS/itching (−0.45), INSOMNIA (−0.42)**. These are mild, local or "product use" complaints.

*Caveat:* reaction terms are written at the same time as the outcome, so they are less "clean" than age or sex. A FALL might be recorded *because* the patient was hospitalized. That is acceptable for explaining which reports tend to be serious, but it is not a pure early-warning setup.

## 8d. Upgrade: time-based split

Instead of a random hash split, we trained on the **oldest ~80%** of reports and tested on the **newest ~20%** (`sql/25_time_split.sql`). The cutoff date is `receivedate` 2021-12-29, and the top-30 drugs were picked again from the older rows only.

| | Train (older) | Test (newer) |
|---|---|---|
| Reports | 237,485 | 59,311 |
| Dates | 1999-12 to 2021-12 | 2021-12 to 2025-06 |
| Serious rate | **29.6%** | **19.6%** |

| Model (time test set) | Accuracy | Precision | Recall | F1 | ROC AUC |
|---|---|---|---|---|---|
| Baseline (always 0) | **0.804** | n/a | 0.000 | 0.000 | 0.500 |
| Logistic regression | 0.674 | 0.315 | 0.563 | 0.404 | 0.689 |
| Boosted tree tuned | 0.676 | 0.321 | 0.584 | 0.414 | 0.694 |

**Takeaway.** ROC AUC holds up (0.689–0.694, close to the random-split 0.688–0.705), so the patterns the model learned **still apply to newer reports**. Recall drops from about 0.66 to about 0.57–0.58, and precision from about 0.41 to about 0.32. The main reason is that newer reports are much less often serious (19.6% vs 29.6%), so the model calibrated on older data over-flags them. This shows the random split was a little optimistic, and a real system would need retraining or threshold adjustment over time.

## 9. Limitations

- **Voluntary reports.** FAERS is spontaneous reporting: under-reported, with reporting biased toward serious and newsworthy events. The base rate does not reflect real-world risk.
- **Association, not causation.** A drug linked to serious reports may simply be given to sicker patients.
- **Duplicates and follow-ups.** The same case can appear more than once (follow-up versions, or reports from both the manufacturer and the doctor). A hash split on `safetyreportid` cannot fully stop near-copies from landing in both train and test.
- **Messy drug names.** Brand and generic names, spelling variants, and dose text in `medicinalproduct` split one drug into several groups. Top-30 grouping with `UPPER(TRIM())` only partly fixes this.
- **Cluster file sample.** We sampled 25 whole files, not individual reports, so some quarters and time periods are over- or under-represented and the label balance may differ from the full data.
- **Missing ages.** Many reports have no age (45.6%). We left these as NULL, and the model's behaviour on them may differ.
- **Few features.** On purpose (basic level). Adding reaction flags (section 8c) raised ROC AUC to 0.727; report source and country would probably help further.
- **Drift over time.** Newer reports are less often serious (section 8d), so a model trained on old data over-flags new reports.

## 10. Think first

**1. Why sample with a hash of the ID instead of `LIMIT 100000`?**
`LIMIT` just takes whatever rows BigQuery happens to return first, which is not random and can change between runs. It is often bunched by how the data is stored, for example all from one time period. Hashing the ID gives a sample that is spread across the whole table, the same every time we rerun it, and lets us split train/test the same way so a report always lands on the same side. (Also, `LIMIT` does not reduce the bytes BigQuery scans, so it does not save money either.) In our case we sampled whole files instead, so we lost some of this randomness. That is why we flag it as a cluster sample.

**2. Why is "death" a bad feature when the label is "hospitalized or died"?**
Because it is part of the answer. If the death flag is 1, the label is automatically 1, so the model would just learn to copy it and look great in testing. In real use we would not know the outcome in advance, so the model would be useless. This is called leakage, and the same goes for the other seriousness fields and reaction terms like "DEATH".

**3. If 70% of reports are serious, why is 70% accuracy not impressive?**
Because you can get 70% by always guessing "serious" without looking at the report at all. That is the majority baseline. A model only proves it learned something if it beats that, which is why we look at recall, precision, F1, and ROC AUC per class instead of just accuracy.
