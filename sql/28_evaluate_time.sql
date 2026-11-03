-- Upgrade B: train on older reports, test on newer ones
WITH t AS (SELECT label, age_years, sex, n_drugs, n_reactions, drug_group FROM faers.test_time)
SELECT 'logreg_time' AS model, * FROM ML.EVALUATE(MODEL faers.m_logreg_time, (SELECT * FROM t)) UNION ALL
SELECT 'boosted_time', * FROM ML.EVALUATE(MODEL faers.m_boosted_time, (SELECT * FROM t));
