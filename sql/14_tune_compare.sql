-- Compare tuning configs on the VALIDATION rows only (hash%10 = 7)
WITH v AS (SELECT label, age_years, sex, n_drugs, n_reactions, drug_group FROM faers.train
           WHERE MOD(ABS(FARM_FINGERPRINT(CAST(safetyreportid AS STRING))), 10) = 7)
SELECT 'd4_lr0.3_ss1.0' AS config, * FROM ML.EVALUATE(MODEL faers.m_tune_1, (SELECT * FROM v)) UNION ALL
SELECT 'd6_lr0.1_ss1.0', * FROM ML.EVALUATE(MODEL faers.m_tune_2, (SELECT * FROM v)) UNION ALL
SELECT 'd8_lr0.1_ss0.8', * FROM ML.EVALUATE(MODEL faers.m_tune_3, (SELECT * FROM v)) UNION ALL
SELECT 'd6_lr0.3_ss0.8', * FROM ML.EVALUATE(MODEL faers.m_tune_4, (SELECT * FROM v))
ORDER BY roc_auc DESC;
