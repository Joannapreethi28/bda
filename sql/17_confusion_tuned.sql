SELECT * FROM ML.CONFUSION_MATRIX(MODEL faers.m_boosted_tuned,
  (SELECT label, age_years, sex, n_drugs, n_reactions, drug_group FROM faers.test));
