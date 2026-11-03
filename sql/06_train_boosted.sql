CREATE OR REPLACE MODEL faers.m_boosted
OPTIONS (model_type = 'BOOSTED_TREE_CLASSIFIER', input_label_cols = ['label'],
         data_split_method = 'NO_SPLIT', auto_class_weights = TRUE,
         max_tree_depth = 4) AS
SELECT label, age_years, sex, n_drugs, n_reactions, drug_group
FROM faers.train;
