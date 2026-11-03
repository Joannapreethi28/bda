-- Tuning config 1: max_tree_depth=4, learn_rate=0.3, subsample=1.0
-- trained on train rows with hash%10 < 7 (validation = hash%10 = 7; test untouched)
CREATE OR REPLACE MODEL faers.m_tune_1
OPTIONS (model_type = 'BOOSTED_TREE_CLASSIFIER', input_label_cols = ['label'],
         data_split_method = 'NO_SPLIT', auto_class_weights = TRUE,
         max_tree_depth = 4, learn_rate = 0.3, subsample = 1.0, max_iterations = 50) AS
SELECT label, age_years, sex, n_drugs, n_reactions, drug_group
FROM faers.train
WHERE MOD(ABS(FARM_FINGERPRINT(CAST(safetyreportid AS STRING))), 10) < 7;
