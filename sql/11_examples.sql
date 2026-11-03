-- 10 example test reports: 5 serious, 5 not, chosen deterministically by hash
SELECT safetyreportid, label AS actual, predicted_label,
       ROUND((SELECT p.prob FROM UNNEST(predicted_label_probs) p WHERE p.label = 1), 3) AS p_serious,
       ROUND(age_years,1) AS age_years, sex, n_drugs, n_reactions, drug_group
FROM ML.PREDICT(MODEL faers.m_logreg, (
  SELECT * FROM faers.test
  QUALIFY ROW_NUMBER() OVER (PARTITION BY label ORDER BY FARM_FINGERPRINT(CAST(safetyreportid AS STRING))) <= 5))
ORDER BY actual DESC, p_serious DESC;
