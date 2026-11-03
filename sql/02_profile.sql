-- Label balance, missing ages, age sanity
SELECT
  COUNT(*)                                   AS n_reports,
  COUNTIF(label = 1)                         AS n_serious,
  ROUND(AVG(label), 4)                       AS pct_serious,
  COUNTIF(age_years IS NULL)                 AS n_missing_age,
  ROUND(COUNTIF(age_years IS NULL)/COUNT(*),4) AS pct_missing_age,
  COUNTIF(age_years > 120)                   AS n_age_over_120,
  COUNTIF(suspect_drug IS NULL)              AS n_missing_drug,
  APPROX_QUANTILES(age_years, 2)[OFFSET(1)]  AS median_age
FROM faers.reports_flat;
