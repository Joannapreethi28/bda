# Drug Adverse Event Severity Prediction (FAERS) - Basic Plan

**Owner:** Joanna | **Level:** basic | **Stack:** BigQuery + BigQuery ML (SQL only)

---

## 1. Problem statement

Given a drug safety report, predict whether the patient was **hospitalized or died** (1) or not (0), using only simple details in the report: patient age, sex, the main suspect drug, and how many drugs and reactions were listed.

Questions to answer in the write-up:
- **Q1.** Can the model beat the "always guess the most common class" baseline?
- **Q2.** Which details (age, sex, drug, counts) push a report toward a serious outcome?
- **Q3.** Where does it get things wrong?

> Honest limit: these are voluntary reports, not a clinical trial. The project can say "reports with X tend to be serious". It cannot say "drug X causes hospitalization".

---

## 2. Scope (kept basic on purpose)

| Decision | Choice |
|---|---|
| Row | one safety report |
| Label | `1` if hospitalization OR death flag is set, else `0` |
| Sample | ~5% of reports (a few hundred thousand rows at most), so it's fast and cheap |
| Features | `age_years`, `sex`, `n_drugs`, `n_reactions`, `drug_group` (top 30 suspect drugs, everything else `OTHER`) |
| Models | `LOGISTIC_REG` (baseline) and `BOOSTED_TREE_CLASSIFIER` |
| Split | 80% train / 20% test, assigned by a hash of the report ID |

**Originally optional; now implemented:** reaction-term flags, time-based split, hyperparameter tuning. See [CHECKLIST.md](CHECKLIST.md) for the completion review and remaining qualifications.

---

## 3. Data

The FDA adverse event data is, I believe, already in BigQuery as a public table: `bigquery-public-data.fda_drug.drug_event`. It's nested: each report holds repeated `patient.drug` and `patient.reaction` lists.

**Step 0, verify first (I haven't checked any of this):**
1. Preview the table. Confirm the table name and that these fields exist: `safetyreportid`, `receivedate`, `seriousnesshospitalization`, `seriousnessdeath`, `patient.patientsex`, `patient.patientonsetage`, `patient.patientonsetageunit`, `patient.drug`, `patient.reaction`.
2. Check the data types (many fields may be STRING, so use `SAFE_CAST`).
3. Check the label balance. I don't know the split yet.
4. Check how many reports have a missing age.

**Setup notes:**
- Create **your** BigQuery dataset in the **US** location, otherwise you can't query the public data.
- Select only the columns you need. Never run `SELECT *` on this table. Use the "bytes processed" estimate in the console before each run.
- If your faculty requires an upload step, export the flat sample table (Step 1) as CSV and load it back as a new table. Ask first whether that is needed.

---

## 4. Pipeline

```
public drug_event --> reports_flat (1 row per report) --> train (80%) / test (20%) --> models --> evaluate + predict
```

### Step 1: Flatten the nested data into one row per report
```sql
CREATE OR REPLACE TABLE faers.reports_flat AS
SELECT
  safetyreportid,
  IF(SAFE_CAST(seriousnesshospitalization AS INT64) = 1
     OR SAFE_CAST(seriousnessdeath AS INT64) = 1, 1, 0)       AS label,
  CASE SAFE_CAST(patient.patientonsetageunit AS INT64)        -- convert everything to years
    WHEN 800 THEN SAFE_CAST(patient.patientonsetage AS FLOAT64) * 10
    WHEN 801 THEN SAFE_CAST(patient.patientonsetage AS FLOAT64)
    WHEN 802 THEN SAFE_CAST(patient.patientonsetage AS FLOAT64) / 12
    WHEN 803 THEN SAFE_CAST(patient.patientonsetage AS FLOAT64) / 52
    WHEN 804 THEN SAFE_CAST(patient.patientonsetage AS FLOAT64) / 365
  END                                                         AS age_years,
  patient.patientsex                                          AS sex,
  ARRAY_LENGTH(patient.drug)                                  AS n_drugs,
  ARRAY_LENGTH(patient.reaction)                              AS n_reactions,
  (SELECT UPPER(d.medicinalproduct)
   FROM UNNEST(patient.drug) d
   WHERE d.drugcharacterization = '1' LIMIT 1)                AS suspect_drug
FROM `bigquery-public-data.fda_drug.drug_event`
WHERE MOD(ABS(FARM_FINGERPRINT(safetyreportid)), 20) = 0;     -- ~5% sample
```
(Age unit codes 800-804 are decade/year/month/week/day. Verify in Step 0.)

### Step 2: Group rare drugs, then split
Keep the 30 most common `suspect_drug` values and set the rest to `OTHER`, saved as `drug_group`. **Pick the top 30 from the training rows only.** Then split:
```sql
-- train:  WHERE MOD(ABS(FARM_FINGERPRINT(safetyreportid)), 10) < 8
-- test:   WHERE MOD(ABS(FARM_FINGERPRINT(safetyreportid)), 10) >= 8
```
Keep `safetyreportid` out of the model features.

### Step 3: Baseline (no model)
Predict the majority class for everyone. Note its accuracy. Your model must beat this.

### Step 4: Train
```sql
CREATE OR REPLACE MODEL faers.m_logreg
OPTIONS (model_type = 'LOGISTIC_REG', input_label_cols = ['label'],
         data_split_method = 'NO_SPLIT', auto_class_weights = TRUE) AS
SELECT label, age_years, sex, n_drugs, n_reactions, drug_group
FROM faers.train;
```
Repeat with `model_type = 'BOOSTED_TREE_CLASSIFIER'` and `max_tree_depth = 4`.

### Step 5: Evaluate and predict
- `ML.EVALUATE(MODEL ..., (SELECT ... FROM faers.test))` gives precision, recall, F1, accuracy and ROC AUC.
- `ML.CONFUSION_MATRIX` shows the error types.
- `ML.PREDICT` returns `predicted_label` and the probabilities. Show 10 example reports with their predicted probability next to the real outcome.
- `ML.WEIGHTS` (logistic) or `ML.FEATURE_IMPORTANCE` (trees) shows which features matter.

---

## 5. Leakage: do NOT use these as features

- Any other seriousness field: `serious`, `seriousnesslifethreatening`, `seriousnessdisabling`, `seriousnesscongenitalanomali`, `seriousnessother`. They are part of the outcome.
- `patient.patientdeathdate` or any death field.
- Reaction terms like `DEATH` or `HOSPITALISATION`, if you add reactions later.

---

## 6. Evaluation

Don't trust accuracy alone. If one class is much bigger, a lazy model scores high. Report **precision, recall, F1 and ROC AUC**, plus the confusion matrix. Decide in one sentence which mistake is worse here (missing a serious report, or flagging a mild one), and say which metric you therefore watch most.

---

## 7. Basic-level traps

| Trap | Fix |
|---|---|
| Missing ages | leave NULL (trees handle it), or fill with the training median and report how many were missing |
| Messy drug names (brand vs generic, spelling) | top-30 grouping, `UPPER()`, and accept the limits |
| Duplicate or follow-up reports | note it in the write-up; a hash split can't fully avoid it |
| Big scans | select only needed columns, check the bytes estimate first |
| Sandbox expiry (60 days) | save screenshots and results |

---

## 8. Timeline (~4 days)

| Day | Work |
|---|---|
| 1 | Step 0 checks, create US dataset |
| 2 | Flatten (Step 1), check label balance and missing values |
| 3 | Group drugs, split, baseline, train both models |
| 4 | Evaluate, feature importance, error analysis, write-up |

## 9. Deliverables

- [x] SQL scripts (flatten, train/test, models, evaluation)
- [x] Results table: baseline vs logistic vs boosted tree
- [x] Confusion matrix and feature importance
- [x] 10 example predictions
- [x] Short write-up answering Q1-Q3

Reviewed on 2026-11-03 against the SQL, saved results, and write-up. All five deliverables are present. The original accuracy target in Step 3 was not met; the write-up explains the recall/AUC improvement instead. See [CHECKLIST.md](CHECKLIST.md) for evidence, checks performed, and outstanding corrections.

---

## 10. Think first (answer in your own words)

1. Why do we sample reports with a hash of the ID instead of `LIMIT 100000`?
2. Why is "death" a bad feature if the label is "hospitalized or died"?
3. If 70% of reports are serious, why is 70% accuracy not impressive?
