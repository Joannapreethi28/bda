-- Step 3: majority-class baseline (majority picked on train, scored on test)
WITH maj AS (SELECT IF(AVG(label) >= 0.5, 1, 0) AS m FROM faers.train)
SELECT
  (SELECT m FROM maj)                                   AS majority_class,
  COUNT(*)                                              AS n_test,
  ROUND(AVG(IF(label = (SELECT m FROM maj), 1, 0)), 4)  AS baseline_accuracy
FROM faers.test;
