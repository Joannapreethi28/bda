-- Which reaction flags push toward serious? Boolean flags are categorical in BQML,
-- so take the weight of category 'true' minus 'false' (standardized logistic weights)
SELECT processed_input,
       ROUND(SUM(IF(LOWER(cw.category) = 'true', cw.weight, -cw.weight)), 3) AS effect_true_vs_false
FROM ML.WEIGHTS(MODEL faers.m_logreg_rx, STRUCT(true AS standardize)), UNNEST(category_weights) cw
WHERE processed_input LIKE 'rx_%'
GROUP BY processed_input
ORDER BY effect_true_vs_false DESC;
