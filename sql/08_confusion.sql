SELECT 'logistic_reg' AS model, * FROM ML.CONFUSION_MATRIX(MODEL faers.m_logreg,
  (SELECT label, age_years, sex, n_drugs, n_reactions, drug_group FROM faers.test))
UNION ALL
SELECT 'boosted_tree' AS model, * FROM ML.CONFUSION_MATRIX(MODEL faers.m_boosted,
  (SELECT label, age_years, sex, n_drugs, n_reactions, drug_group FROM faers.test));
