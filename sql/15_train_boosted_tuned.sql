-- Winner on validation (ROC AUC 0.703): depth 8, learn_rate 0.1, subsample 0.8. Retrained on ALL train rows.
CREATE OR REPLACE MODEL faers.m_boosted_tuned
OPTIONS (model_type = 'BOOSTED_TREE_CLASSIFIER', input_label_cols = ['label'],
         data_split_method = 'NO_SPLIT', auto_class_weights = TRUE,
         max_tree_depth = 8, learn_rate = 0.1, subsample = 0.8, max_iterations = 50) AS
SELECT label, age_years, sex, n_drugs, n_reactions, drug_group
FROM faers.train;
