-- Single final test-set evaluation of the tuned model, next to the earlier models
WITH t AS (SELECT label, age_years, sex, n_drugs, n_reactions, drug_group FROM faers.test)
SELECT 'boosted_tuned' AS model, * FROM ML.EVALUATE(MODEL faers.m_boosted_tuned, (SELECT * FROM t)) UNION ALL
SELECT 'boosted_depth4', * FROM ML.EVALUATE(MODEL faers.m_boosted, (SELECT * FROM t)) UNION ALL
SELECT 'logistic_reg', * FROM ML.EVALUATE(MODEL faers.m_logreg, (SELECT * FROM t));
