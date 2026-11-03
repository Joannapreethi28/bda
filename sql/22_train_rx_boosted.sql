-- same tuned settings as 15_train_boosted_tuned.sql
CREATE OR REPLACE MODEL faers.m_boosted_rx
OPTIONS (model_type = 'BOOSTED_TREE_CLASSIFIER', input_label_cols = ['label'],
         data_split_method = 'NO_SPLIT', auto_class_weights = TRUE,
         max_tree_depth = 8, learn_rate = 0.1, subsample = 0.8, max_iterations = 50) AS
SELECT label, age_years, sex, n_drugs, n_reactions, drug_group, rx_drug_ineffective, rx_nausea, rx_fatigue, rx_off_label_use, rx_diarrhoea, rx_pain, rx_headache, rx_dyspnoea, rx_dizziness, rx_vomiting, rx_rash, rx_malaise, rx_arthralgia, rx_asthenia, rx_pruritus, rx_incorrect_dose_administered, rx_pyrexia, rx_fall, rx_injection_site_pain, rx_insomnia FROM faers.train_rx;
