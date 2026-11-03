-- Q3: where does the logistic model go wrong? error rates by slice
WITH p AS (
  SELECT label, predicted_label, sex, drug_group,
         CASE WHEN age_years IS NULL THEN 'missing' WHEN age_years < 18 THEN '<18'
              WHEN age_years < 65 THEN '18-64' ELSE '65+' END AS age_band,
         IF(n_reactions >= 3, '3+', CAST(n_reactions AS STRING)) AS reactions
  FROM ML.PREDICT(MODEL faers.m_logreg, (SELECT * FROM faers.test)))
SELECT 'age_band' AS slice, age_band AS value, COUNT(*) n,
       ROUND(AVG(label),3) serious_rate, ROUND(AVG(IF(label!=predicted_label,1,0)),3) error_rate,
       ROUND(SAFE_DIVIDE(COUNTIF(label=1 AND predicted_label=0), COUNTIF(label=1)),3) miss_rate_fn
FROM p GROUP BY 1,2
UNION ALL
SELECT 'sex', sex, COUNT(*), ROUND(AVG(label),3), ROUND(AVG(IF(label!=predicted_label,1,0)),3),
       ROUND(SAFE_DIVIDE(COUNTIF(label=1 AND predicted_label=0), COUNTIF(label=1)),3) FROM p GROUP BY 1,2
UNION ALL
SELECT 'reactions', reactions, COUNT(*), ROUND(AVG(label),3), ROUND(AVG(IF(label!=predicted_label,1,0)),3),
       ROUND(SAFE_DIVIDE(COUNTIF(label=1 AND predicted_label=0), COUNTIF(label=1)),3) FROM p GROUP BY 1,2
ORDER BY slice, value;
