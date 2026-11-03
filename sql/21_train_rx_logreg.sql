CREATE OR REPLACE MODEL faers.m_logreg_rx
OPTIONS (model_type = 'LOGISTIC_REG', input_label_cols = ['label'],
         data_split_method = 'NO_SPLIT', auto_class_weights = TRUE) AS
SELECT label, age_years, sex, n_drugs, n_reactions, drug_group, rx_drug_ineffective, rx_nausea, rx_fatigue, rx_off_label_use, rx_diarrhoea, rx_pain, rx_headache, rx_dyspnoea, rx_dizziness, rx_vomiting, rx_rash, rx_malaise, rx_arthralgia, rx_asthenia, rx_pruritus, rx_incorrect_dose_administered, rx_pyrexia, rx_fall, rx_injection_site_pain, rx_insomnia FROM faers.train_rx;
