-- Numeric weights + top/bottom drug_group & sex categories
SELECT processed_input, ROUND(weight, 4) AS weight, NULL AS category
FROM ML.WEIGHTS(MODEL faers.m_logreg, STRUCT(true AS standardize))
WHERE ARRAY_LENGTH(category_weights) = 0
UNION ALL
SELECT processed_input, ROUND(cw.weight, 4), cw.category
FROM ML.WEIGHTS(MODEL faers.m_logreg, STRUCT(true AS standardize)), UNNEST(category_weights) cw
ORDER BY processed_input, weight DESC;
