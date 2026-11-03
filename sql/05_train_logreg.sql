CREATE OR REPLACE MODEL faers.m_logreg
OPTIONS (model_type = 'LOGISTIC_REG', input_label_cols = ['label'],
         data_split_method = 'NO_SPLIT', auto_class_weights = TRUE) AS
SELECT label, age_years, sex, n_drugs, n_reactions, drug_group
FROM faers.train;
