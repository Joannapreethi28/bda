WITH maj AS (SELECT IF(AVG(label) >= 0.5, 1, 0) AS m FROM faers.train_time)
SELECT (SELECT m FROM maj) AS majority_class, COUNT(*) AS n_test,
       ROUND(AVG(IF(label = (SELECT m FROM maj), 1, 0)), 4) AS baseline_accuracy
FROM faers.test_time;
