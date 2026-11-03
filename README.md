# FAERS Adverse Event Severity Prediction (BigQuery ML)

Student project: given an FDA drug adverse event report, predict whether the patient was **hospitalized or died** (label 1) or not (label 0), using only age, sex, the main suspect drug, and the number of drugs and reactions in the report. Everything is plain SQL in BigQuery ML. The original plan is in `plan_faers.md`, and the write-up is in `WRITEUP.md`.

Completion review: [CHECKLIST.md](CHECKLIST.md) records the completed deliverables, verification results, and remaining corrections as of 2026-11-03.

## Prerequisites

- A Google account and a BigQuery **Sandbox** project. We used `faers-sandbox-10151307` (student account, billing disabled; `billingEnabled=false` verified).
- A BigQuery dataset named `faers` in the **US** location.
- Google Cloud SDK (`gcloud`/`bq`), installed on Windows with `winget install Google.CloudSDK`, then `gcloud auth login`.
- Git Bash (to run `run.sh`).
- Python 3 with `ijson` (`pip install ijson`) for `scripts/prepare_data.py`.
- About 1.2 GB of free disk space for the sampled zip files.

## Reproduce step by step

1. **Get the data (openFDA bulk download).** The public table `bigquery-public-data.fda_drug.drug_event` that the plan assumed does not exist (see Deviations below), so we download the openFDA bulk files instead.
   - The file index is at https://api.fda.gov/download.json (see https://open.fda.gov/data/downloads/). Under `results.drug.event.partitions` it lists 1,767 zip files (20.7M reports, about 110 GB zipped, export dated 2026-10-12).
   - `python scripts/download_sample.py data/zips` picks 25 partitions with `random.seed(42)` / `random.sample(partitions, 25)` and downloads them in parallel. Our sample came to about 1.16 GB zipped and 296,816 reports from 2005 to 2025. (If openFDA republishes its index, the same seed may pick different files.)
2. **Slim the data down to NDJSON.**
   ```bash
   python scripts/prepare_data.py data/zips data/drug_event_sample.ndjson.gz
   ```
   This keeps only the fields the project needs, in the original nested layout (`patient.drug[]`, `patient.reaction[]`). Fields that would leak the label are left out on purpose.
3. **Load the data into BigQuery** (loading is free):
   ```bash
   bq load --location=US --source_format=NEWLINE_DELIMITED_JSON \
     faers.drug_event_raw data/drug_event_sample.ndjson.gz scripts/drug_event_schema.json
   ```
4. **Run the SQL files in order.** `./run.sh sql/<file>.sql` runs one file through `bq`, using the Python bundled with the SDK, and saves the output to `results/<file>.txt`. Add `dry` as a second argument (`./run.sh sql/01_flatten.sql dry`) to only print the bytes estimate.

   | File | What it does |
   |---|---|
   | `00a_tables.sql` | Step 0: lists the public `fda_drug` tables (`drug_event` is missing) |
   | `00_step0_checks.sql` | Step 0 on the uploaded table: row and ID counts, label inputs, missing age and sex, age-unit codes |
   | `01_flatten.sql` | One row per report, giving `faers.reports_flat` (label, age in years, sex, counts, suspect drug) |
   | `02_profile.sql` | Label balance, missing ages, age sanity checks |
   | `03_split.sql` | Top-30 suspect drugs (picked from the training rows only), then the 80/20 hash split into `faers.train` and `faers.test` |
   | `04_baseline.sql` | Majority-class baseline accuracy |
   | `05_train_logreg.sql` | `LOGISTIC_REG` model `faers.m_logreg` |
   | `06_train_boosted.sql` | `BOOSTED_TREE_CLASSIFIER` model `faers.m_boosted` (trained fine in the Sandbox) |
   | `07_evaluate.sql` | `ML.EVALUATE` for both models on the test set |
   | `08_confusion.sql` | `ML.CONFUSION_MATRIX` for both models |
   | `09_weights_logreg.sql` | `ML.WEIGHTS` (standardized), including the per-drug and per-sex weights |
   | `10_importance_boosted.sql` | `ML.FEATURE_IMPORTANCE` for the boosted tree |
   | `11_examples.sql` | 10 example test predictions (5 serious, 5 not) |
   | `12_error_analysis.sql` | Error and miss rates by age band, sex, and number of reactions (Q3) |

   | `13_tune_1..4.sql`, `14_tune_compare.sql` | Upgrade: 4 boosted-tree configs, compared on a validation slice of train |
   | `15_train_boosted_tuned.sql`, `16_evaluate_tuned.sql`, `17_confusion_tuned.sql`, `18_importance_tuned.sql` | Best config retrained on all train rows and evaluated on test once (ROC AUC 0.705) |

   | `19`–`24` | Upgrade: 20 reaction-term flags (leaky terms excluded) → `m_logreg_rx`, `m_boosted_rx`; ROC AUC 0.727 |
   | `25`–`29` | Upgrade: time-based split (train before 2021-12-29, test after) → `m_logreg_time`, `m_boosted_time` |

   Models train in about 2–5 minutes. Scripts 05/06 and 07–12 are independent, so they can run in parallel.

## Folder layout

```
plan_faers.md                    original plan
README.md                        this file
WRITEUP.md                       report (results, answers to Q1-Q3, limitations)
CHECKLIST.md                     completion review, evidence, and outstanding items
run.sh                           runs one SQL file via bq and saves its output to results/
sql/                             the pipeline, numbered in run order
scripts/download_sample.py       downloads the 25 random openFDA files (seed 42)
scripts/prepare_data.py          openFDA zip files -> slim NDJSON (gzipped), one process per CPU core
scripts/drug_event_schema.json   BigQuery schema for faers.drug_event_raw
results/                         saved query outputs (one .txt per SQL file)
```

## Cost notes

- Everything runs in the **BigQuery Sandbox** with billing disabled, so nothing can be charged.
- The monthly free tier covers 1 TB of query processing, 10 GB of storage, and 10 GB of BQML model creation for built-in models (such as logistic regression). This project uses a small fraction of each.
- Sandbox tables and models **expire after 60 days**, so keep `results/` and screenshots.
- Loading data with `bq load` is free. Before a big query, use `./run.sh <file> dry` to check the bytes estimate.
- We worried the Sandbox might refuse boosted trees, but `06_train_boosted.sql` trained without billing.

## Deviations from the plan

1. **No public `drug_event` table.** `bigquery-public-data.fda_drug` only contains `drug_label` and `drug_enforcement` (`results/00a_tables.txt`). We downloaded openFDA bulk JSON instead and uploaded it as `faers.drug_event_raw`. This also covers the plan's optional "upload step".
2. **Different sampling.** Our sample is 25 randomly chosen bulk files (296,816 reports). The plan's 5% `FARM_FINGERPRINT` sample is therefore **not** applied in the flatten step. The 80/20 hash split on `safetyreportid` is kept. Sampling whole files is a cluster sample, because the files are grouped by quarter. See the limitations in `WRITEUP.md`.
3. **Age unit 805 (hours)** turned up in Step 0 and was added to the age conversion.
4. **Duplicate report IDs** (20 of them) are removed in `01_flatten.sql`, keeping the latest `receivedate`.
