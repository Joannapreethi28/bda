# Project completion checklist

Reviewed: **2026-11-03**. Scope: all 75 supplied files, including 34 SQL scripts and their 34 saved outputs, the Python scripts, schema, runner, plan, README, and write-up.

**All five original deliverables are complete, and all three optional upgrades have been implemented and have saved results.** This does not mean every original success criterion was met or every reproducibility issue is resolved. Checked boxes below mean evidence is present and was reviewed; unchecked boxes identify unmet targets, corrections, or verification still outstanding.

This was a local file review with offline checks. The saved outputs describe the earlier BigQuery run; no cloud queries, model training, or fresh openFDA downloads were performed during this review. SQL and saved results were left unchanged.

## Original deliverables: 5/5 complete

- [x] **SQL pipeline:** flattening, train/test preparation, baseline, both models, evaluation, predictions, and interpretation are implemented in [sql/](sql/), with a matching nonempty output for every script in [results/](results/).
- [x] **Results comparison:** baseline, logistic regression, and boosted tree appear in [WRITEUP.md](WRITEUP.md), section 4, supported by [04_baseline.txt](results/04_baseline.txt) and [07_evaluate.txt](results/07_evaluate.txt).
- [x] **Confusion matrices and feature importance:** write-up sections 5-6 match [08_confusion.txt](results/08_confusion.txt), [09_weights_logreg.txt](results/09_weights_logreg.txt), and [10_importance_boosted.txt](results/10_importance_boosted.txt).
- [x] **Ten example predictions:** section 7 and [11_examples.txt](results/11_examples.txt) contain five actual serious and five actual non-serious reports, probabilities, predictions, and outcomes.
- [x] **Write-up answering Q1-Q3:** section 8 discusses the baseline comparison, influential features, and mistakes. Limitations and all three “Think first” answers are also included.

## Supporting project work completed

- [x] **Data-source check and documented replacement:** [00a_tables.txt](results/00a_tables.txt) records the public tables found; README and write-up explain the switch to uploaded openFDA data.
- [x] **Download, preparation, and load workflow:** [download_sample.py](scripts/download_sample.py), [prepare_data.py](scripts/prepare_data.py), [drug_event_schema.json](scripts/drug_event_schema.json), and the README load command are present. Saved raw-table checks support the earlier upload.
- [x] **Raw-data and missing-value profiling:** [00_step0_checks.txt](results/00_step0_checks.txt) and [02_profile.txt](results/02_profile.txt) record counts, label inputs, age units, missing data, and date range.
- [x] **Core report preparation:** [01_flatten.sql](sql/01_flatten.sql) constructs the hospitalization-or-death label, converts age units 800-805, counts drugs/reactions, and selects one row per report ID. Saved counts show 296,816 raw rows and 296,796 distinct IDs.
- [x] **Core features and holdout split:** [03_split.sql](sql/03_split.sql) selects the top 30 drugs from training rows, handles out-of-range ages and missing sex, and uses disjoint hash buckets for train and test. IDs and outcome fields are excluded from model feature lists.
- [x] **Training-majority baseline:** [04_baseline.sql](sql/04_baseline.sql) chooses the class on training rows and scores it on test rows; saved test accuracy is 0.7231.
- [x] **Both basic models trained and evaluated:** evaluation outputs exist for logistic regression and the depth-4 boosted tree. Training logs contain missing-age warnings; downstream evaluations provide evidence that the models were available.
- [x] **Error analysis:** [12_error_analysis.txt](results/12_error_analysis.txt) reports error and false-negative rates by age band, sex, and reaction count.
- [x] **Interpretation and limitations:** the write-up explains the preference for serious-class recall, the accuracy tradeoff, voluntary reporting, association versus causation, missing ages, drug-name variants, follow-ups, and cluster sampling.
- [x] **Reproduction instructions and saved evidence:** README documents prerequisites, commands, execution order, environment, and deviations; all query outputs are preserved as text. Exact reproduction has gaps listed below.

## Optional upgrades: 3/3 implemented

- [x] **Hyperparameter tuning:** scripts 13-18 compare four configurations on a validation slice, retrain the selected configuration, and save test metrics, a confusion matrix, and importance. Tuned test ROC AUC: **0.705**.
- [x] **Reaction flags:** scripts 19-24 add 20 flags, train both models, evaluate them, and report logistic effects. The hard-coded flags match the saved training vocabulary. Best saved ROC AUC: **0.727**; boosted-model recall: **0.741**. See the deduplication and vocabulary caveats below.
- [x] **Time split:** scripts 25-29 use cutoff **2021-12-29**, rebuild drug groups from older reports, train both models, and evaluate against a time-test baseline. Counts total 296,796; model ROC AUC is **0.689-0.694**. This experiment has the validation limitation noted below.

## Checks passed during this review

- [x] All 34 SQL files have corresponding nonempty saved results; all were inspected.
- [x] Both Python scripts parse, the BigQuery schema is valid JSON, and `run.sh` passes `bash -n`.
- [x] A synthetic ZIP passed through the real data-preparation CLI, including multiprocessing, and produced the expected gzipped NDJSON. Extra outcome fields were removed and missing patient data was handled.
- [x] With a mocked file index and mocked downloads, the downloader selected the expected 25 partitions for seed 42 and wrote the expected URL manifest. This verifies local behavior, not the live service.
- [x] All three saved confusion matrices reproduce the corresponding accuracy, precision, recall, and F1 values.
- [x] **55 displayed performance-table values** in the write-up match their saved evaluation outputs to the displayed precision.
- [x] Baseline accuracy, profile proportions, subgroup row totals, time-split totals, and the ten examples agree with the saved evidence. Eight of the ten examples are correctly predicted.

## Unmet target

- [ ] **Beat the majority baseline on accuracy.** The original plan explicitly requires this in Step 3. No saved model achieves it: the best random-split model accuracy is **0.673**, below **0.723**, and the best time-split accuracy is **0.676**, below **0.804**. Q1 already explains that recall and ROC AUC improve. The analysis is complete, but this particular target must not be marked achieved.

## Remaining corrections and reproducibility gaps

- [ ] **Correct the stated date range.** README step 1 and write-up section 2 say 2005-2025. The saved raw check gives **1999-12-03 through 2025-06-30**, consistent with the time-split output.
- [ ] **Clarify model execution dependencies.** README says scripts 05/06 and 07-12 are independent. Training scripts 05 and 06 can run together after the split, but model-dependent evaluation, weights, importance, and predictions must wait for their required models.
- [ ] **Clarify two write-up descriptions.** Section 3's statement that reaction terms are not features applies only to the basic models; section 8c does use reaction flags. The **84%** miss rate in Q3 is for missing sex (`UNK`), while explicit unknown sex (`0`) has a **58.4%** miss rate in [12_error_analysis.txt](results/12_error_analysis.txt); section 6 should likewise distinguish their weights.
- [ ] **Preserve the original sample manifest for exact reproduction.** The downloader writes `data/zips/files.txt`, but that manifest, the original index snapshot, and sampled data are absent from this folder. Seed 42 alone cannot identify the original sample after the live index changes. Historical outputs are preserved; exact input reconstruction is not verified.
- [ ] **Make reaction-vocabulary reuse explicit.** [20_reaction_features.sql](sql/20_reaction_features.sql) hard-codes the 20 terms rather than reading `faers.top_reactions`. They match the saved sample, but rerunning step 19 on a different download will not update those columns automatically. Generate/update them from the selected vocabulary or document that the experiment uses the frozen vocabulary.
- [ ] **Use the same report version for reaction features and the core row.** [01_flatten.sql](sql/01_flatten.sql) selects one raw row per ID, while steps 19-20 read all raw versions and combine their reaction terms. For repeated IDs, flags can therefore include reactions from a version different from the row supplying the label and counts. Apply a shared deduplication rule; if features change, rerun the affected experiments and update their results. The supplied files do not establish the size of any metric impact.
- [ ] **Make query failures visible to callers.** [run.sh](run.sh) pipes `BQ query` into `tee` without `pipefail`, so a failed query can still return a successful shell status when `tee` succeeds. Add failure propagation before relying on the runner for unattended reproduction.
- [ ] **Make row selection deterministic.** [01_flatten.sql](sql/01_flatten.sql) uses `LIMIT 1` without ordering to choose a suspect drug and resolves report duplicates by `receivedate` alone. Multiple suspects or tied dates can leave the selected row unspecified. Preserve array order for the stated “first suspect” rule and define a stable duplicate tie-breaker; do not claim that the maximum receipt date proves the latest follow-up version.

## Method qualifications to document

These do not erase the completed deliverables, but they limit how strongly the optional experiments can be interpreted.

- [ ] **Qualify validation independence.** The top-30 drug vocabulary is selected before the inner tuning split, so validation rows influence that preprocessing. The time-split tree also reuses settings chosen using a random split across dates, rather than an older-only validation period. For strict validation, fit preprocessing inside each fitting subset and select time-model settings using only pre-cutoff data. Otherwise state these limitations and treat the upgrades as exploratory comparisons.
- [ ] **Qualify test reuse and the drift explanation.** The same random holdout is evaluated across successive upgrades; it is not a fresh final holdout for choosing among all experiments. Section 8d's claim that lower prevalence is the main reason recall drops is not established by the saved aggregate metrics. Describe the observed changes without treating that causal explanation as measured.

## Verification not performed here

- [ ] **Fresh end-to-end BigQuery run and current resource availability.** This audit did not recheck live dataset location, billing, table/model expiry, or job history, or rerun SQL against the original sample. Existing files provide historical results rather than current cloud-state confirmation.

No screenshots, presentation, or separate faculty rubric were supplied. The original five deliverables do not require a presentation or screenshots, so their absence is not counted as a missing core deliverable.
